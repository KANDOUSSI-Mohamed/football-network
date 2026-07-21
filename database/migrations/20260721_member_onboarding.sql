-- Football Network: member onboarding, profile ownership and safe connections.
-- Run after 20260721_multilingual_foundation.sql and 20260721_network_core.sql.

alter table profiles
  add column if not exists location_text text;

alter table profiles
  add column if not exists primary_role_code text;

alter table profiles
  add column if not exists onboarding_completed_at timestamptz;

create index if not exists idx_profiles_public_created
  on profiles(visibility, created_at desc);

create index if not exists idx_profiles_primary_role
  on profiles(primary_role_code);

create unique index if not exists idx_connections_active_pair
  on connections (
    least(requester_profile_id, receiver_profile_id),
    greatest(requester_profile_id, receiver_profile_id)
  )
  where status in ('pending', 'accepted');

alter table profiles enable row level security;
alter table profile_roles enable row level security;
alter table connections enable row level security;
alter table professional_roles enable row level security;
alter table professional_role_translations enable row level security;

drop policy if exists "Public profiles are readable" on profiles;
create policy "Public profiles are readable"
  on profiles for select
  using (visibility = 'public' or user_id = auth.uid());

drop policy if exists "Members create their profiles" on profiles;
create policy "Members create their profiles"
  on profiles for insert
  with check (user_id = auth.uid());

drop policy if exists "Members update their profiles" on profiles;
create policy "Members update their profiles"
  on profiles for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Members delete their profiles" on profiles;
create policy "Members delete their profiles"
  on profiles for delete
  using (user_id = auth.uid());

drop policy if exists "Public profile roles are readable" on profile_roles;
create policy "Public profile roles are readable"
  on profile_roles for select
  using (exists (
    select 1 from profiles p
    where p.id = profile_roles.profile_id
      and (p.visibility = 'public' or p.user_id = auth.uid())
  ));

drop policy if exists "Members manage their profile roles" on profile_roles;
create policy "Members manage their profile roles"
  on profile_roles for all
  using (exists (
    select 1 from profiles p
    where p.id = profile_roles.profile_id
      and p.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from profiles p
    where p.id = profile_roles.profile_id
      and p.user_id = auth.uid()
  ));

drop policy if exists "Professional roles are readable" on professional_roles;
create policy "Professional roles are readable"
  on professional_roles for select
  using (is_active);

drop policy if exists "Professional role translations are readable" on professional_role_translations;
create policy "Professional role translations are readable"
  on professional_role_translations for select
  using (true);

drop policy if exists "Connection participants can read" on connections;
create policy "Connection participants can read"
  on connections for select
  using (exists (
    select 1 from profiles p
    where p.user_id = auth.uid()
      and p.id in (connections.requester_profile_id, connections.receiver_profile_id)
  ));

grant select on profiles to anon, authenticated;
grant insert, update, delete on profiles to authenticated;
grant select on profile_roles to anon, authenticated;
grant insert, update, delete on profile_roles to authenticated;
grant select on professional_roles to anon, authenticated;
grant select on professional_role_translations to anon, authenticated;
grant select on connections to authenticated;

create or replace function create_member_profile(
  p_display_name text,
  p_slug text,
  p_role_code text,
  p_bio text default null,
  p_city text default null,
  p_location_text text default null,
  p_preferred_locale text default 'fr'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  existing_profile profiles%rowtype;
  role_record professional_roles%rowtype;
  created_profile profiles%rowtype;
  safe_name text := trim(coalesce(p_display_name, ''));
  safe_slug text;
  safe_locale text := lower(trim(coalesce(p_preferred_locale, 'fr')));
begin
  if requester is null then
    raise exception 'authentication_required';
  end if;

  if char_length(safe_name) < 2 or char_length(safe_name) > 120 then
    raise exception 'invalid_display_name';
  end if;

  select * into existing_profile
  from profiles p
  where p.user_id = requester
    and p.profile_type = 'person'
  order by p.created_at
  limit 1;

  if existing_profile.id is not null then
    return jsonb_build_object(
      'created', false,
      'id', existing_profile.id,
      'slug', existing_profile.slug
    );
  end if;

  select * into role_record
  from professional_roles pr
  where pr.code = p_role_code
    and pr.is_active;

  if role_record.id is null then
    raise exception 'invalid_professional_role';
  end if;

  if not exists (select 1 from supported_locales sl where sl.code = safe_locale and sl.is_enabled) then
    safe_locale := 'fr';
  end if;

  safe_slug := lower(regexp_replace(trim(coalesce(p_slug, '')), '[^a-z0-9-]+', '', 'g'));
  safe_slug := regexp_replace(safe_slug, '-+', '-', 'g');
  safe_slug := trim(both '-' from safe_slug);

  if char_length(safe_slug) < 3 then
    safe_slug := 'member-' || left(replace(requester::text, '-', ''), 10);
  end if;

  if exists (select 1 from profiles p where p.slug = safe_slug) then
    safe_slug := left(safe_slug, 76) || '-' || left(replace(requester::text, '-', ''), 8);
  end if;

  insert into profiles (
    user_id,
    profile_type,
    display_name,
    slug,
    bio,
    city,
    location_text,
    primary_role_code,
    visibility,
    verification_status,
    claim_status,
    preferred_locale,
    source_locale,
    onboarding_completed_at
  ) values (
    requester,
    'person',
    safe_name,
    safe_slug,
    nullif(trim(coalesce(p_bio, '')), ''),
    nullif(trim(coalesce(p_city, '')), ''),
    nullif(trim(coalesce(p_location_text, '')), ''),
    role_record.code,
    'public',
    'unverified',
    'claimed',
    safe_locale,
    safe_locale,
    now()
  )
  returning * into created_profile;

  insert into profile_roles (profile_id, role_id, is_primary)
  values (created_profile.id, role_record.id, true)
  on conflict (profile_id, role_id) do update set is_primary = true;

  insert into profile_contact_settings (
    profile_id,
    allow_premium_viewers,
    require_accepted_connection,
    show_contact_request_button
  ) values (
    created_profile.id,
    false,
    true,
    true
  )
  on conflict (profile_id) do nothing;

  return jsonb_build_object(
    'created', true,
    'id', created_profile.id,
    'slug', created_profile.slug
  );
end;
$$;

create or replace function request_connection(target_profile uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_user uuid := auth.uid();
  requester_profile uuid;
  existing_connection connections%rowtype;
  created_connection connections%rowtype;
begin
  if requester_user is null then
    return jsonb_build_object('created', false, 'reason', 'authentication_required');
  end if;

  select p.id into requester_profile
  from profiles p
  where p.user_id = requester_user
    and p.profile_type = 'person'
  order by p.created_at
  limit 1;

  if requester_profile is null then
    return jsonb_build_object('created', false, 'reason', 'profile_required');
  end if;

  if requester_profile = target_profile then
    return jsonb_build_object('created', false, 'reason', 'self_connection');
  end if;

  if not exists (
    select 1 from profiles p
    where p.id = target_profile
      and p.visibility = 'public'
  ) then
    return jsonb_build_object('created', false, 'reason', 'profile_not_found');
  end if;

  select * into existing_connection
  from connections c
  where c.status in ('pending', 'accepted')
    and least(c.requester_profile_id, c.receiver_profile_id) = least(requester_profile, target_profile)
    and greatest(c.requester_profile_id, c.receiver_profile_id) = greatest(requester_profile, target_profile)
  limit 1;

  if existing_connection.id is not null then
    return jsonb_build_object(
      'created', false,
      'reason', 'connection_exists',
      'id', existing_connection.id,
      'status', existing_connection.status
    );
  end if;

  insert into connections (requester_profile_id, receiver_profile_id, status)
  values (requester_profile, target_profile, 'pending')
  returning * into created_connection;

  return jsonb_build_object(
    'created', true,
    'id', created_connection.id,
    'status', created_connection.status
  );
end;
$$;

create or replace function respond_to_connection(
  connection_id uuid,
  decision text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  responder uuid := auth.uid();
  updated_connection connections%rowtype;
begin
  if responder is null then
    return jsonb_build_object('updated', false, 'reason', 'authentication_required');
  end if;

  if decision not in ('accepted', 'rejected') then
    return jsonb_build_object('updated', false, 'reason', 'invalid_decision');
  end if;

  update connections c
  set
    status = decision,
    accepted_at = case when decision = 'accepted' then now() else null end
  where c.id = connection_id
    and c.status = 'pending'
    and exists (
      select 1 from profiles p
      where p.id = c.receiver_profile_id
        and p.user_id = responder
    )
  returning * into updated_connection;

  if updated_connection.id is null then
    return jsonb_build_object('updated', false, 'reason', 'connection_not_found');
  end if;

  return jsonb_build_object(
    'updated', true,
    'id', updated_connection.id,
    'status', updated_connection.status
  );
end;
$$;

revoke all on function create_member_profile(text, text, text, text, text, text, text) from public;
revoke all on function request_connection(uuid) from public;
revoke all on function respond_to_connection(uuid, text) from public;

grant execute on function create_member_profile(text, text, text, text, text, text, text) to authenticated;
grant execute on function request_connection(uuid) to authenticated;
grant execute on function respond_to_connection(uuid, text) to authenticated;
