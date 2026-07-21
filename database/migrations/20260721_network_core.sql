-- Football Network: protected contact access, plan entitlements and JustRate linking.
-- Additive migration. Run after schema.sql and 20260721_multilingual_foundation.sql.

create table if not exists plan_entitlements (
  plan text not null,
  entitlement text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (plan, entitlement)
);

insert into plan_entitlements (plan, entitlement) values
  ('premium', 'direct_contact_access'),
  ('premium', 'advanced_search'),
  ('premium', 'priority_messaging'),
  ('club', 'direct_contact_access'),
  ('club', 'advanced_search'),
  ('club', 'priority_messaging'),
  ('club', 'recruitment_pipeline'),
  ('agency', 'direct_contact_access'),
  ('agency', 'advanced_search'),
  ('agency', 'priority_messaging'),
  ('agency', 'recruitment_pipeline')
on conflict (plan, entitlement) do update set enabled = excluded.enabled;

create table if not exists profile_contact_settings (
  profile_id uuid primary key references profiles(id) on delete cascade,
  allow_premium_viewers boolean not null default false,
  require_accepted_connection boolean not null default true,
  show_contact_request_button boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists profile_contacts (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references profiles(id) on delete cascade,
  contact_type text not null check (contact_type in ('email', 'phone', 'whatsapp', 'website', 'other')),
  label text,
  contact_value text not null,
  masked_value text,
  is_primary boolean not null default false,
  is_verified boolean not null default false,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, contact_type, contact_value)
);

create table if not exists contact_access_events (
  id uuid primary key default uuid_generate_v4(),
  target_profile_id uuid not null references profiles(id) on delete cascade,
  viewer_user_id uuid,
  viewer_profile_id uuid references profiles(id) on delete set null,
  access_source text not null default 'profile',
  decision text not null check (decision in ('granted', 'denied')),
  decision_reason text not null,
  created_at timestamptz not null default now()
);

create table if not exists justrate_profile_links (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null unique references profiles(id) on delete cascade,
  justrate_player_id text not null unique,
  justrate_profile_url text,
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected', 'revoked')),
  verification_method text,
  verification_notes text,
  requested_by_user_id uuid,
  reviewed_by_user_id uuid,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  last_synced_at timestamptz,
  sync_status text not null default 'not_started' check (sync_status in ('not_started', 'ready', 'syncing', 'synced', 'error')),
  public_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists justrate_sync_events (
  id uuid primary key default uuid_generate_v4(),
  link_id uuid not null references justrate_profile_links(id) on delete cascade,
  status text not null check (status in ('started', 'completed', 'failed')),
  snapshot_version text,
  error_code text,
  created_at timestamptz not null default now()
);

create index if not exists idx_profile_contacts_profile
  on profile_contacts(profile_id);

create index if not exists idx_contact_access_target_created
  on contact_access_events(target_profile_id, created_at desc);

create index if not exists idx_contact_access_viewer_created
  on contact_access_events(viewer_user_id, created_at desc);

create index if not exists idx_justrate_links_status
  on justrate_profile_links(status);

create index if not exists idx_justrate_sync_link_created
  on justrate_sync_events(link_id, created_at desc);

alter table profile_contact_settings enable row level security;
alter table profile_contacts enable row level security;
alter table contact_access_events enable row level security;
alter table justrate_profile_links enable row level security;
alter table justrate_sync_events enable row level security;
alter table plan_entitlements enable row level security;

drop policy if exists "Plan entitlements are readable" on plan_entitlements;
create policy "Plan entitlements are readable"
  on plan_entitlements for select
  using (true);

drop policy if exists "Profile owners manage contact settings" on profile_contact_settings;
create policy "Profile owners manage contact settings"
  on profile_contact_settings for all
  using (exists (
    select 1 from profiles p
    where p.id = profile_contact_settings.profile_id
      and p.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from profiles p
    where p.id = profile_contact_settings.profile_id
      and p.user_id = auth.uid()
  ));

drop policy if exists "Profile owners manage contacts" on profile_contacts;
create policy "Profile owners manage contacts"
  on profile_contacts for all
  using (exists (
    select 1 from profiles p
    where p.id = profile_contacts.profile_id
      and p.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from profiles p
    where p.id = profile_contacts.profile_id
      and p.user_id = auth.uid()
  ));

drop policy if exists "Users read their contact access history" on contact_access_events;
create policy "Users read their contact access history"
  on contact_access_events for select
  using (
    viewer_user_id = auth.uid()
    or exists (
      select 1 from profiles p
      where p.id = contact_access_events.target_profile_id
        and p.user_id = auth.uid()
    )
  );

drop policy if exists "Owners create JustRate link requests" on justrate_profile_links;
create policy "Owners create JustRate link requests"
  on justrate_profile_links for insert
  with check (
    status = 'pending'
    and requested_by_user_id = auth.uid()
    and exists (
      select 1 from profiles p
      where p.id = justrate_profile_links.profile_id
        and p.user_id = auth.uid()
    )
  );

drop policy if exists "Owners read their JustRate links" on justrate_profile_links;
create policy "Owners read their JustRate links"
  on justrate_profile_links for select
  using (
    status = 'verified'
    or exists (
      select 1 from profiles p
      where p.id = justrate_profile_links.profile_id
        and p.user_id = auth.uid()
    )
  );

drop policy if exists "Owners update pending JustRate links" on justrate_profile_links;
create policy "Owners update pending JustRate links"
  on justrate_profile_links for update
  using (
    status in ('pending', 'rejected')
    and exists (
      select 1 from profiles p
      where p.id = justrate_profile_links.profile_id
        and p.user_id = auth.uid()
    )
  )
  with check (
    status = 'pending'
    and reviewed_by_user_id is null
    and reviewed_at is null
    and exists (
      select 1 from profiles p
      where p.id = justrate_profile_links.profile_id
        and p.user_id = auth.uid()
    )
  );

drop policy if exists "Verified JustRate sync events are readable" on justrate_sync_events;
create policy "Verified JustRate sync events are readable"
  on justrate_sync_events for select
  using (exists (
    select 1 from justrate_profile_links link
    where link.id = justrate_sync_events.link_id
      and (
        link.status = 'verified'
        or exists (
          select 1 from profiles p
          where p.id = link.profile_id
            and p.user_id = auth.uid()
        )
      )
  ));

create or replace function request_profile_contacts(
  target_profile uuid,
  access_source text default 'profile'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_user uuid := auth.uid();
  requester_profile uuid;
  target_owner uuid;
  settings profile_contact_settings%rowtype;
  has_entitlement boolean := false;
  has_connection boolean := false;
  granted boolean := false;
  reason text := 'authentication_required';
  contacts jsonb := '[]'::jsonb;
begin
  select p.user_id into target_owner
  from profiles p
  where p.id = target_profile;

  if target_owner is null then
    return jsonb_build_object('granted', false, 'reason', 'profile_not_found', 'contacts', contacts);
  end if;

  if requester_user is not null then
    select p.id into requester_profile
    from profiles p
    where p.user_id = requester_user
    order by p.created_at
    limit 1;
  end if;

  if requester_user = target_owner then
    granted := true;
    reason := 'profile_owner';
  elsif requester_user is not null then
    select exists (
      select 1
      from subscriptions s
      join plan_entitlements pe
        on pe.plan = s.plan
       and pe.entitlement = 'direct_contact_access'
       and pe.enabled
      where s.user_id = requester_user
        and s.status = 'active'
        and (s.ends_at is null or s.ends_at > now())
    ) into has_entitlement;

    select * into settings
    from profile_contact_settings pcs
    where pcs.profile_id = target_profile;

    if settings.profile_id is null or not settings.allow_premium_viewers then
      reason := 'profile_contact_disabled';
    elsif not has_entitlement then
      reason := 'premium_required';
    elsif settings.require_accepted_connection then
      select exists (
        select 1 from connections c
        where c.status = 'accepted'
          and (
            (c.requester_profile_id = requester_profile and c.receiver_profile_id = target_profile)
            or (c.receiver_profile_id = requester_profile and c.requester_profile_id = target_profile)
          )
      ) into has_connection;

      if has_connection then
        granted := true;
        reason := 'premium_connected';
      else
        reason := 'accepted_connection_required';
      end if;
    else
      granted := true;
      reason := 'premium_authorized';
    end if;
  end if;

  if granted then
    select coalesce(jsonb_agg(jsonb_build_object(
      'type', pc.contact_type,
      'label', pc.label,
      'value', pc.contact_value,
      'verified', pc.is_verified
    ) order by pc.is_primary desc, pc.created_at), '[]'::jsonb)
    into contacts
    from profile_contacts pc
    where pc.profile_id = target_profile;
  end if;

  insert into contact_access_events (
    target_profile_id,
    viewer_user_id,
    viewer_profile_id,
    access_source,
    decision,
    decision_reason
  ) values (
    target_profile,
    requester_user,
    requester_profile,
    left(coalesce(access_source, 'profile'), 64),
    case when granted then 'granted' else 'denied' end,
    reason
  );

  return jsonb_build_object('granted', granted, 'reason', reason, 'contacts', contacts);
end;
$$;

revoke all on function request_profile_contacts(uuid, text) from public;
grant execute on function request_profile_contacts(uuid, text) to authenticated;

