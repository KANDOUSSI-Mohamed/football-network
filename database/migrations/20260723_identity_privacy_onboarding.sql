-- Football Network: complete onboarding, privacy controls and identity verification.
-- Private identity data and verification documents are never exposed publicly.

begin;

create table if not exists member_private_profiles (
  profile_id uuid primary key references profiles(id) on delete cascade,
  legal_first_name text not null,
  legal_last_name text not null,
  date_of_birth date not null,
  country_code text not null,
  guardian_email text,
  guardian_consent_status text not null default 'not_required'
    check (guardian_consent_status in ('not_required', 'required', 'pending', 'verified')),
  terms_version text not null,
  terms_accepted_at timestamptz not null,
  privacy_version text not null,
  privacy_accepted_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(trim(legal_first_name)) between 1 and 100),
  check (char_length(trim(legal_last_name)) between 1 and 100),
  check (country_code ~ '^[A-Z]{2}$'),
  check (date_of_birth <= current_date),
  check (date_of_birth >= current_date - interval '110 years')
);

create table if not exists profile_privacy_settings (
  profile_id uuid primary key references profiles(id) on delete cascade,
  directory_visibility text not null default 'public'
    check (directory_visibility in ('public', 'connections', 'private')),
  allow_search_engines boolean not null default true,
  show_city boolean not null default true,
  show_current_organization boolean not null default true,
  show_availability boolean not null default true,
  show_age_band boolean not null default false,
  message_permission text not null default 'connections'
    check (message_permission in ('everyone', 'connections', 'nobody')),
  updated_at timestamptz not null default now()
);

create table if not exists identity_verification_requests (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references profiles(id) on delete cascade,
  verification_type text not null
    check (verification_type in ('identity', 'professional', 'agent', 'club_representative')),
  legal_first_name text not null,
  legal_last_name text not null,
  country_code text not null,
  document_type text not null
    check (document_type in ('passport', 'identity_card', 'residence_permit', 'professional_card', 'licence', 'club_mandate')),
  document_path text not null,
  license_number text,
  member_message text,
  status text not null default 'submitted'
    check (status in ('submitted', 'in_review', 'needs_information', 'verified', 'rejected', 'cancelled')),
  reviewer_notes text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  updated_at timestamptz not null default now(),
  check (country_code ~ '^[A-Z]{2}$'),
  check (char_length(trim(legal_first_name)) between 1 and 100),
  check (char_length(trim(legal_last_name)) between 1 and 100),
  check (char_length(document_path) between 10 and 500)
);

create index if not exists idx_identity_verification_profile
  on identity_verification_requests(profile_id, submitted_at desc);

create index if not exists idx_identity_verification_review_queue
  on identity_verification_requests(status, submitted_at)
  where status in ('submitted', 'in_review', 'needs_information');

create unique index if not exists idx_identity_verification_active_type
  on identity_verification_requests(profile_id, verification_type)
  where status in ('submitted', 'in_review', 'needs_information');

alter table member_private_profiles enable row level security;
alter table profile_privacy_settings enable row level security;
alter table identity_verification_requests enable row level security;

drop policy if exists "Members read their private identity" on member_private_profiles;
create policy "Members read their private identity"
  on member_private_profiles for select
  using (exists (
    select 1 from profiles p
    where p.id = member_private_profiles.profile_id
      and p.user_id = auth.uid()
  ));

drop policy if exists "Members manage their private identity" on member_private_profiles;
create policy "Members manage their private identity"
  on member_private_profiles for all
  using (exists (
    select 1 from profiles p
    where p.id = member_private_profiles.profile_id
      and p.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from profiles p
    where p.id = member_private_profiles.profile_id
      and p.user_id = auth.uid()
  ));

drop policy if exists "Profile privacy is readable when profile is visible" on profile_privacy_settings;
create policy "Profile privacy is readable when profile is visible"
  on profile_privacy_settings for select
  using (exists (
    select 1 from profiles p
    where p.id = profile_privacy_settings.profile_id
      and (p.visibility = 'public' or p.user_id = auth.uid())
  ));

drop policy if exists "Members manage their profile privacy" on profile_privacy_settings;
create policy "Members manage their profile privacy"
  on profile_privacy_settings for all
  using (exists (
    select 1 from profiles p
    where p.id = profile_privacy_settings.profile_id
      and p.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from profiles p
    where p.id = profile_privacy_settings.profile_id
      and p.user_id = auth.uid()
  ));

drop policy if exists "Members read their verification requests" on identity_verification_requests;
create policy "Members read their verification requests"
  on identity_verification_requests for select
  using (exists (
    select 1 from profiles p
    where p.id = identity_verification_requests.profile_id
      and p.user_id = auth.uid()
  ));

create or replace function can_view_member_profile(
  target_profile uuid,
  target_visibility text,
  owner_user uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    target_visibility = 'public'
    or owner_user = auth.uid()
    or (
      target_visibility = 'connections'
      and exists (
        select 1
        from connections c
        where c.status = 'accepted'
          and target_profile in (c.requester_profile_id, c.receiver_profile_id)
          and current_member_profile_id() in (c.requester_profile_id, c.receiver_profile_id)
      )
    );
$$;

drop policy if exists "Public profiles are readable" on profiles;
create policy "Public profiles are readable"
  on profiles for select
  using (can_view_member_profile(id, visibility, user_id));

create or replace function complete_member_onboarding(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  target profiles%rowtype;
  creation jsonb;
  safe_visibility text := lower(trim(coalesce(payload->>'directory_visibility', 'public')));
  safe_message_permission text := lower(trim(coalesce(payload->>'message_permission', 'connections')));
  safe_country text := upper(trim(coalesce(payload->>'country_code', '')));
  safe_birth_date date;
  safe_locale text := lower(trim(coalesce(payload->>'preferred_locale', 'fr')));
  is_young_member boolean := false;
begin
  if requester is null then
    raise exception 'authentication_required';
  end if;

  if coalesce((payload->>'accept_terms')::boolean, false) is not true
    or coalesce((payload->>'accept_privacy')::boolean, false) is not true then
    raise exception 'consent_required';
  end if;

  if safe_country !~ '^[A-Z]{2}$' then
    raise exception 'invalid_country_code';
  end if;

  begin
    safe_birth_date := (payload->>'date_of_birth')::date;
  exception when others then
    raise exception 'invalid_date_of_birth';
  end;

  if safe_birth_date > current_date
    or safe_birth_date < current_date - interval '110 years' then
    raise exception 'invalid_date_of_birth';
  end if;

  if char_length(trim(coalesce(payload->>'legal_first_name', ''))) < 1
    or char_length(trim(coalesce(payload->>'legal_last_name', ''))) < 1 then
    raise exception 'legal_name_required';
  end if;

  if safe_visibility not in ('public', 'connections', 'private') then
    raise exception 'invalid_visibility';
  end if;

  if safe_message_permission not in ('everyone', 'connections', 'nobody') then
    raise exception 'invalid_message_permission';
  end if;

  is_young_member := safe_birth_date > current_date - interval '15 years';
  if is_young_member then
    safe_visibility := 'private';
    safe_message_permission := 'nobody';
  end if;

  select * into target
  from profiles p
  where p.user_id = requester
    and p.profile_type = 'person'
  order by p.created_at
  limit 1;

  if target.id is null then
    creation := create_member_profile(
      payload->>'display_name',
      payload->>'slug',
      payload->>'role_code',
      payload->>'bio',
      payload->>'city',
      payload->>'country_name',
      safe_locale
    );

    select * into target
    from profiles p
    where p.id = (creation->>'id')::uuid;
  else
    update profiles
    set
      display_name = trim(coalesce(payload->>'display_name', display_name)),
      bio = nullif(trim(coalesce(payload->>'bio', bio, '')), ''),
      city = nullif(trim(coalesce(payload->>'city', city, '')), ''),
      location_text = nullif(trim(coalesce(payload->>'country_name', location_text, '')), ''),
      preferred_locale = safe_locale,
      source_locale = coalesce(source_locale, safe_locale),
      onboarding_completed_at = now(),
      updated_at = now()
    where id = target.id
    returning * into target;
  end if;

  update profiles
  set
    visibility = safe_visibility,
    onboarding_completed_at = now(),
    updated_at = now()
  where id = target.id
  returning * into target;

  insert into member_private_profiles (
    profile_id,
    legal_first_name,
    legal_last_name,
    date_of_birth,
    country_code,
    guardian_email,
    guardian_consent_status,
    terms_version,
    terms_accepted_at,
    privacy_version,
    privacy_accepted_at,
    updated_at
  ) values (
    target.id,
    trim(payload->>'legal_first_name'),
    trim(payload->>'legal_last_name'),
    safe_birth_date,
    safe_country,
    nullif(lower(trim(coalesce(payload->>'guardian_email', ''))), ''),
    case
      when is_young_member and nullif(trim(coalesce(payload->>'guardian_email', '')), '') is null then 'required'
      when is_young_member then 'pending'
      else 'not_required'
    end,
    '2026-07-23',
    now(),
    '2026-07-23',
    now(),
    now()
  )
  on conflict (profile_id) do update set
    legal_first_name = excluded.legal_first_name,
    legal_last_name = excluded.legal_last_name,
    date_of_birth = excluded.date_of_birth,
    country_code = excluded.country_code,
    guardian_email = excluded.guardian_email,
    guardian_consent_status = excluded.guardian_consent_status,
    terms_version = excluded.terms_version,
    terms_accepted_at = excluded.terms_accepted_at,
    privacy_version = excluded.privacy_version,
    privacy_accepted_at = excluded.privacy_accepted_at,
    updated_at = now();

  insert into profile_privacy_settings (
    profile_id,
    directory_visibility,
    allow_search_engines,
    show_city,
    show_current_organization,
    show_availability,
    show_age_band,
    message_permission,
    updated_at
  ) values (
    target.id,
    safe_visibility,
    case when is_young_member then false else coalesce((payload->>'allow_search_engines')::boolean, true) end,
    coalesce((payload->>'show_city')::boolean, true),
    coalesce((payload->>'show_current_organization')::boolean, true),
    coalesce((payload->>'show_availability')::boolean, true),
    coalesce((payload->>'show_age_band')::boolean, false),
    safe_message_permission,
    now()
  )
  on conflict (profile_id) do update set
    directory_visibility = excluded.directory_visibility,
    allow_search_engines = excluded.allow_search_engines,
    show_city = excluded.show_city,
    show_current_organization = excluded.show_current_organization,
    show_availability = excluded.show_availability,
    show_age_band = excluded.show_age_band,
    message_permission = excluded.message_permission,
    updated_at = now();

  insert into profile_contact_settings (
    profile_id,
    allow_premium_viewers,
    require_accepted_connection,
    show_contact_request_button
  ) values (
    target.id,
    false,
    true,
    not is_young_member
  )
  on conflict (profile_id) do nothing;

  return jsonb_build_object(
    'created', coalesce((creation->>'created')::boolean, false),
    'id', target.id,
    'slug', target.slug,
    'visibility', safe_visibility,
    'guardian_consent_status', case
      when is_young_member and nullif(trim(coalesce(payload->>'guardian_email', '')), '') is null then 'required'
      when is_young_member then 'pending'
      else 'not_required'
    end
  );
end;
$$;

create or replace function save_profile_privacy(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_profile uuid := current_member_profile_id();
  safe_visibility text := lower(trim(coalesce(payload->>'directory_visibility', 'public')));
  safe_message_permission text := lower(trim(coalesce(payload->>'message_permission', 'connections')));
  birth_date date;
  is_young_member boolean := false;
begin
  if requester_profile is null then
    raise exception 'profile_required';
  end if;

  if safe_visibility not in ('public', 'connections', 'private') then
    raise exception 'invalid_visibility';
  end if;

  if safe_message_permission not in ('everyone', 'connections', 'nobody') then
    raise exception 'invalid_message_permission';
  end if;

  select mpp.date_of_birth into birth_date
  from member_private_profiles mpp
  where mpp.profile_id = requester_profile;

  is_young_member := birth_date is not null
    and birth_date > current_date - interval '15 years';

  if is_young_member then
    safe_visibility := 'private';
    safe_message_permission := 'nobody';
  end if;

  update profiles
  set visibility = safe_visibility, updated_at = now()
  where id = requester_profile;

  insert into profile_privacy_settings (
    profile_id,
    directory_visibility,
    allow_search_engines,
    show_city,
    show_current_organization,
    show_availability,
    show_age_band,
    message_permission,
    updated_at
  ) values (
    requester_profile,
    safe_visibility,
    case when is_young_member then false else coalesce((payload->>'allow_search_engines')::boolean, true) end,
    coalesce((payload->>'show_city')::boolean, true),
    coalesce((payload->>'show_current_organization')::boolean, true),
    coalesce((payload->>'show_availability')::boolean, true),
    coalesce((payload->>'show_age_band')::boolean, false),
    safe_message_permission,
    now()
  )
  on conflict (profile_id) do update set
    directory_visibility = excluded.directory_visibility,
    allow_search_engines = excluded.allow_search_engines,
    show_city = excluded.show_city,
    show_current_organization = excluded.show_current_organization,
    show_availability = excluded.show_availability,
    show_age_band = excluded.show_age_band,
    message_permission = excluded.message_permission,
    updated_at = now();

  insert into profile_contact_settings (
    profile_id,
    allow_premium_viewers,
    require_accepted_connection,
    show_contact_request_button
  ) values (
    requester_profile,
    case when is_young_member then false else coalesce((payload->>'allow_premium_viewers')::boolean, false) end,
    coalesce((payload->>'require_accepted_connection')::boolean, true),
    case when is_young_member then false else coalesce((payload->>'show_contact_request_button')::boolean, true) end
  )
  on conflict (profile_id) do update set
    allow_premium_viewers = excluded.allow_premium_viewers,
    require_accepted_connection = excluded.require_accepted_connection,
    show_contact_request_button = excluded.show_contact_request_button;

  return jsonb_build_object(
    'saved', true,
    'visibility', safe_visibility,
    'message_permission', safe_message_permission,
    'minor_protection', is_young_member
  );
end;
$$;

create or replace function save_private_identity(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_profile uuid := current_member_profile_id();
  previous member_private_profiles%rowtype;
  safe_country text := upper(trim(coalesce(payload->>'country_code', '')));
  safe_birth_date date;
  identity_changed boolean := false;
  is_young_member boolean := false;
begin
  if requester_profile is null then
    raise exception 'profile_required';
  end if;

  if safe_country !~ '^[A-Z]{2}$' then
    raise exception 'invalid_country_code';
  end if;

  begin
    safe_birth_date := (payload->>'date_of_birth')::date;
  exception when others then
    raise exception 'invalid_date_of_birth';
  end;

  if safe_birth_date > current_date
    or safe_birth_date < current_date - interval '110 years' then
    raise exception 'invalid_date_of_birth';
  end if;

  if char_length(trim(coalesce(payload->>'legal_first_name', ''))) < 1
    or char_length(trim(coalesce(payload->>'legal_last_name', ''))) < 1 then
    raise exception 'legal_name_required';
  end if;

  select * into previous
  from member_private_profiles mpp
  where mpp.profile_id = requester_profile;

  if previous.profile_id is null then
    raise exception 'complete_onboarding_first';
  end if;

  identity_changed :=
    previous.legal_first_name is distinct from trim(payload->>'legal_first_name')
    or previous.legal_last_name is distinct from trim(payload->>'legal_last_name')
    or previous.date_of_birth is distinct from safe_birth_date
    or previous.country_code is distinct from safe_country;

  is_young_member := safe_birth_date > current_date - interval '15 years';

  update member_private_profiles
  set
    legal_first_name = trim(payload->>'legal_first_name'),
    legal_last_name = trim(payload->>'legal_last_name'),
    date_of_birth = safe_birth_date,
    country_code = safe_country,
    guardian_email = nullif(lower(trim(coalesce(payload->>'guardian_email', ''))), ''),
    guardian_consent_status = case
      when is_young_member and nullif(trim(coalesce(payload->>'guardian_email', '')), '') is null then 'required'
      when is_young_member then 'pending'
      else 'not_required'
    end,
    updated_at = now()
  where profile_id = requester_profile;

  if identity_changed then
    update profiles
    set verification_status = 'unverified', updated_at = now()
    where id = requester_profile;
  end if;

  if is_young_member then
    update profiles
    set visibility = 'private', updated_at = now()
    where id = requester_profile;

    insert into profile_privacy_settings (
      profile_id,
      directory_visibility,
      allow_search_engines,
      show_city,
      show_current_organization,
      show_availability,
      show_age_band,
      message_permission,
      updated_at
    ) values (
      requester_profile,
      'private',
      false,
      false,
      false,
      false,
      false,
      'nobody',
      now()
    )
    on conflict (profile_id) do update set
      directory_visibility = 'private',
      allow_search_engines = false,
      message_permission = 'nobody',
      updated_at = now();
  end if;

  return jsonb_build_object(
    'saved', true,
    'verification_reset', identity_changed,
    'guardian_consent_status', case
      when is_young_member and nullif(trim(coalesce(payload->>'guardian_email', '')), '') is null then 'required'
      when is_young_member then 'pending'
      else 'not_required'
    end
  );
end;
$$;
create or replace function request_identity_verification(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_profile uuid := current_member_profile_id();
  private_identity member_private_profiles%rowtype;
  request_type text := lower(trim(coalesce(payload->>'verification_type', 'identity')));
  safe_document_type text := lower(trim(coalesce(payload->>'document_type', '')));
  safe_document_path text := trim(coalesce(payload->>'document_path', ''));
  created identity_verification_requests%rowtype;
begin
  if requester_profile is null then
    raise exception 'profile_required';
  end if;

  select * into private_identity
  from member_private_profiles mpp
  where mpp.profile_id = requester_profile;

  if private_identity.profile_id is null then
    raise exception 'complete_identity_first';
  end if;

  if request_type not in ('identity', 'professional', 'agent', 'club_representative') then
    raise exception 'invalid_verification_type';
  end if;

  if safe_document_type not in ('passport', 'identity_card', 'residence_permit', 'professional_card', 'licence', 'club_mandate') then
    raise exception 'invalid_document_type';
  end if;

  if split_part(safe_document_path, '/', 1) <> requester_profile::text then
    raise exception 'invalid_document_path';
  end if;

  if exists (
    select 1
    from identity_verification_requests ivr
    where ivr.profile_id = requester_profile
      and ivr.verification_type = request_type
      and ivr.status in ('submitted', 'in_review', 'needs_information')
  ) then
    raise exception 'verification_in_progress';
  end if;

  insert into identity_verification_requests (
    profile_id,
    verification_type,
    legal_first_name,
    legal_last_name,
    country_code,
    document_type,
    document_path,
    license_number,
    member_message
  ) values (
    requester_profile,
    request_type,
    private_identity.legal_first_name,
    private_identity.legal_last_name,
    private_identity.country_code,
    safe_document_type,
    safe_document_path,
    nullif(trim(coalesce(payload->>'license_number', '')), ''),
    nullif(trim(coalesce(payload->>'member_message', '')), '')
  )
  returning * into created;

  update profiles
  set verification_status = 'pending', updated_at = now()
  where id = requester_profile
    and verification_status <> 'verified';

  return jsonb_build_object(
    'submitted', true,
    'id', created.id,
    'status', created.status,
    'submitted_at', created.submitted_at
  );
end;
$$;

create or replace function cancel_identity_verification(target_request uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_profile uuid := current_member_profile_id();
  cancelled identity_verification_requests%rowtype;
begin
  if requester_profile is null then
    raise exception 'profile_required';
  end if;

  update identity_verification_requests
  set status = 'cancelled', updated_at = now()
  where id = target_request
    and profile_id = requester_profile
    and status in ('submitted', 'needs_information')
  returning * into cancelled;

  if cancelled.id is null then
    raise exception 'verification_cannot_be_cancelled';
  end if;

  if not exists (
    select 1
    from identity_verification_requests ivr
    where ivr.profile_id = requester_profile
      and ivr.status in ('submitted', 'in_review', 'needs_information', 'verified')
  ) then
    update profiles
    set verification_status = 'unverified', updated_at = now()
    where id = requester_profile;
  end if;

  return jsonb_build_object('cancelled', true, 'id', cancelled.id);
end;
$$;

create or replace function sync_profile_verification_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'verified' then
    update profiles
    set verification_status = 'verified', updated_at = now()
    where id = new.profile_id;
  elsif new.status in ('rejected', 'cancelled')
    and not exists (
      select 1
      from identity_verification_requests ivr
      where ivr.profile_id = new.profile_id
        and ivr.id <> new.id
        and ivr.status in ('submitted', 'in_review', 'needs_information', 'verified')
    ) then
    update profiles
    set verification_status = 'unverified', updated_at = now()
    where id = new.profile_id;
  end if;
  return new;
end;
$$;

drop trigger if exists identity_verification_status_sync on identity_verification_requests;
create trigger identity_verification_status_sync
after update of status on identity_verification_requests
for each row execute function sync_profile_verification_status();

create or replace function can_message_profile(
  sender_profile uuid,
  target_profile uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    sender_profile is not null
    and target_profile is not null
    and sender_profile <> target_profile
    and exists (
      select 1
      from profiles target
      left join profile_privacy_settings privacy on privacy.profile_id = target.id
      where target.id = target_profile
        and target.profile_type = 'person'
        and can_view_member_profile(target.id, target.visibility, target.user_id)
        and (
          coalesce(privacy.message_permission, 'connections') = 'everyone'
          or (
            coalesce(privacy.message_permission, 'connections') = 'connections'
            and exists (
              select 1
              from connections c
              where c.status = 'accepted'
                and sender_profile in (c.requester_profile_id, c.receiver_profile_id)
                and target_profile in (c.requester_profile_id, c.receiver_profile_id)
            )
          )
        )
    );
$$;

create or replace function start_direct_conversation(target_profile uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_profile uuid := current_member_profile_id();
  conversation_key text;
  conversation_record conversations%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('created', false, 'reason', 'authentication_required');
  end if;

  if requester_profile is null then
    return jsonb_build_object('created', false, 'reason', 'profile_required');
  end if;

  if target_profile is null or target_profile = requester_profile then
    return jsonb_build_object('created', false, 'reason', 'invalid_target');
  end if;

  if not can_message_profile(requester_profile, target_profile) then
    return jsonb_build_object('created', false, 'reason', 'messaging_not_allowed');
  end if;

  conversation_key := least(requester_profile::text, target_profile::text)
    || ':' || greatest(requester_profile::text, target_profile::text);

  select * into conversation_record
  from conversations c
  where c.direct_key = conversation_key
  limit 1;

  if conversation_record.id is not null then
    return jsonb_build_object(
      'created', false,
      'id', conversation_record.id,
      'status', 'ready'
    );
  end if;

  insert into conversations (
    created_by_profile_id,
    conversation_type,
    direct_key
  ) values (
    requester_profile,
    'direct',
    conversation_key
  )
  on conflict (direct_key) where direct_key is not null do nothing
  returning * into conversation_record;

  if conversation_record.id is null then
    select * into conversation_record
    from conversations c
    where c.direct_key = conversation_key
    limit 1;
  end if;

  insert into conversation_participants (conversation_id, profile_id, role)
  values
    (conversation_record.id, requester_profile, 'member'),
    (conversation_record.id, target_profile, 'member')
  on conflict (conversation_id, profile_id) do nothing;

  return jsonb_build_object(
    'created', true,
    'id', conversation_record.id,
    'status', 'ready'
  );
end;
$$;

create or replace function send_direct_message(
  target_conversation uuid,
  message_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sender_profile uuid := current_member_profile_id();
  recipient_profile uuid;
  safe_body text := trim(coalesce(message_body, ''));
  created_message messages%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('sent', false, 'reason', 'authentication_required');
  end if;

  if sender_profile is null then
    return jsonb_build_object('sent', false, 'reason', 'profile_required');
  end if;

  if char_length(safe_body) < 1 or char_length(safe_body) > 4000 then
    return jsonb_build_object('sent', false, 'reason', 'invalid_message');
  end if;

  if not exists (
    select 1
    from conversation_participants cp
    where cp.conversation_id = target_conversation
      and cp.profile_id = sender_profile
  ) then
    return jsonb_build_object('sent', false, 'reason', 'conversation_not_found');
  end if;

  select cp.profile_id into recipient_profile
  from conversation_participants cp
  join conversations c on c.id = cp.conversation_id
  where cp.conversation_id = target_conversation
    and cp.profile_id <> sender_profile
    and c.conversation_type = 'direct'
  limit 1;

  if recipient_profile is not null
    and not can_message_profile(sender_profile, recipient_profile) then
    return jsonb_build_object('sent', false, 'reason', 'messaging_not_allowed');
  end if;

  insert into messages (
    conversation_id,
    sender_profile_id,
    body,
    message_type
  ) values (
    target_conversation,
    sender_profile,
    safe_body,
    'text'
  )
  returning * into created_message;

  update conversations
  set updated_at = created_message.created_at
  where id = target_conversation;

  update conversation_participants
  set last_read_at = created_message.created_at
  where conversation_id = target_conversation
    and profile_id = sender_profile;

  return jsonb_build_object(
    'sent', true,
    'id', created_message.id,
    'conversation_id', created_message.conversation_id,
    'created_at', created_message.created_at
  );
end;
$$;

revoke all on function can_message_profile(uuid, uuid) from public;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'identity-verification',
  'identity-verification',
  false,
  10485760,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Members upload verification documents" on storage.objects;
create policy "Members upload verification documents"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'identity-verification'
    and split_part(name, '/', 1) = current_member_profile_id()::text
  );

drop policy if exists "Members read verification documents" on storage.objects;
create policy "Members read verification documents"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'identity-verification'
    and split_part(name, '/', 1) = current_member_profile_id()::text
  );

drop policy if exists "Members delete verification documents" on storage.objects;
create policy "Members delete verification documents"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'identity-verification'
    and split_part(name, '/', 1) = current_member_profile_id()::text
  );

grant select, insert, update, delete on member_private_profiles to authenticated;
grant select, insert, update, delete on profile_privacy_settings to authenticated;
grant select on identity_verification_requests to authenticated;
grant all on identity_verification_requests to service_role;

revoke all on function can_view_member_profile(uuid, text, uuid) from public;
revoke all on function complete_member_onboarding(jsonb) from public;
revoke all on function save_profile_privacy(jsonb) from public;
revoke all on function request_identity_verification(jsonb) from public;
revoke all on function cancel_identity_verification(uuid) from public;
revoke all on function sync_profile_verification_status() from public;

grant execute on function can_view_member_profile(uuid, text, uuid) to anon, authenticated;
grant execute on function complete_member_onboarding(jsonb) to authenticated;
grant execute on function save_profile_privacy(jsonb) to authenticated;
grant execute on function request_identity_verification(jsonb) to authenticated;
grant execute on function cancel_identity_verification(uuid) to authenticated;

commit;
