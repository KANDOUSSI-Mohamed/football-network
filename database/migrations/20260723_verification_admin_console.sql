-- Football Network: secure verification and club-claim administration.
-- Staff access is explicit, least-privilege and fully audited.

begin;

create table if not exists platform_staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  staff_role text not null
    check (staff_role in ('super_admin', 'verifier', 'moderator', 'support')),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists organization_memberships (
  id uuid primary key default uuid_generate_v4(),
  organization_profile_id uuid not null references profiles(id) on delete cascade,
  member_profile_id uuid not null references profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  access_role text not null default 'owner'
    check (access_role in ('owner', 'admin', 'editor', 'viewer')),
  status text not null default 'active'
    check (status in ('active', 'invited', 'suspended', 'revoked')),
  source_claim_id uuid references claims(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_profile_id, user_id)
);

create table if not exists verification_audit_log (
  id uuid primary key default uuid_generate_v4(),
  entity_type text not null
    check (entity_type in ('identity', 'club_claim')),
  identity_request_id uuid references identity_verification_requests(id) on delete set null,
  club_claim_id uuid references claims(id) on delete set null,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  action text not null
    check (action in ('start_review', 'needs_information', 'approve', 'reject', 'auto_reject')),
  previous_status text not null,
  new_status text not null,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (
    (entity_type = 'identity' and identity_request_id is not null and club_claim_id is null)
    or
    (entity_type = 'club_claim' and club_claim_id is not null and identity_request_id is null)
  )
);

alter table claims
  add column if not exists reviewer_notes text;

create index if not exists idx_platform_staff_active
  on platform_staff(staff_role, is_active);

create index if not exists idx_organization_memberships_user
  on organization_memberships(user_id, status, updated_at desc);

create index if not exists idx_organization_memberships_organization
  on organization_memberships(organization_profile_id, status);

create index if not exists idx_verification_audit_identity
  on verification_audit_log(identity_request_id, created_at desc)
  where identity_request_id is not null;

create index if not exists idx_verification_audit_club_claim
  on verification_audit_log(club_claim_id, created_at desc)
  where club_claim_id is not null;

alter table platform_staff enable row level security;
alter table organization_memberships enable row level security;
alter table verification_audit_log enable row level security;

create or replace function is_platform_staff(required_roles text[] default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from platform_staff ps
    where ps.user_id = auth.uid()
      and ps.is_active
      and (required_roles is null or ps.staff_role = any(required_roles))
  );
$$;

drop policy if exists "Staff read their own role" on platform_staff;
create policy "Staff read their own role"
  on platform_staff for select to authenticated
  using (user_id = auth.uid() and is_active);

drop policy if exists "Members read their organization memberships" on organization_memberships;
create policy "Members read their organization memberships"
  on organization_memberships for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Staff read verification audit" on verification_audit_log;
create policy "Staff read verification audit"
  on verification_audit_log for select to authenticated
  using (is_platform_staff(array['super_admin', 'verifier', 'moderator', 'support']));

drop policy if exists "Staff read identity verification requests" on identity_verification_requests;
create policy "Staff read identity verification requests"
  on identity_verification_requests for select to authenticated
  using (is_platform_staff(array['super_admin', 'verifier']));

drop policy if exists "Staff read private identities" on member_private_profiles;
create policy "Staff read private identities"
  on member_private_profiles for select to authenticated
  using (is_platform_staff(array['super_admin', 'verifier']));

drop policy if exists "Staff read club claims" on claims;
create policy "Staff read club claims"
  on claims for select to authenticated
  using (is_platform_staff(array['super_admin', 'verifier', 'moderator', 'support']));

drop policy if exists "Staff read verification documents" on storage.objects;
create policy "Staff read verification documents"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'identity-verification'
    and is_platform_staff(array['super_admin', 'verifier'])
  );

create or replace function get_admin_verification_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  role_name text;
begin
  select ps.staff_role into role_name
  from platform_staff ps
  where ps.user_id = auth.uid() and ps.is_active;

  if role_name is null then
    raise exception 'staff_access_required';
  end if;

  return jsonb_build_object(
    'staff_role', role_name,
    'identity', jsonb_build_object(
      'submitted', (select count(*) from identity_verification_requests where status = 'submitted'),
      'in_review', (select count(*) from identity_verification_requests where status = 'in_review'),
      'needs_information', (select count(*) from identity_verification_requests where status = 'needs_information'),
      'verified', (select count(*) from identity_verification_requests where status = 'verified'),
      'rejected', (select count(*) from identity_verification_requests where status = 'rejected')
    ),
    'club_claims', jsonb_build_object(
      'submitted', (select count(*) from claims where claim_type = 'club_ownership' and status = 'submitted'),
      'reviewing', (select count(*) from claims where claim_type = 'club_ownership' and status = 'reviewing'),
      'approved', (select count(*) from claims where claim_type = 'club_ownership' and status = 'approved'),
      'rejected', (select count(*) from claims where claim_type = 'club_ownership' and status = 'rejected')
    )
  );
end;
$$;

create or replace function get_admin_review_queue(
  p_kind text default 'identity',
  p_status text default '',
  p_type text default '',
  p_query text default '',
  p_limit integer default 30,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  safe_kind text := lower(trim(coalesce(p_kind, 'identity')));
  safe_status text := lower(trim(coalesce(p_status, '')));
  safe_type text := lower(trim(coalesce(p_type, '')));
  safe_query text := left(trim(coalesce(p_query, '')), 120);
  safe_limit integer := least(greatest(coalesce(p_limit, 30), 1), 100);
  safe_offset integer := greatest(coalesce(p_offset, 0), 0);
  total_count bigint := 0;
  items jsonb := '[]'::jsonb;
begin
  if safe_kind = 'identity' then
    if not is_platform_staff(array['super_admin', 'verifier']) then
      raise exception 'verification_staff_required';
    end if;

    select count(*) into total_count
    from identity_verification_requests ivr
    join profiles p on p.id = ivr.profile_id
    where (safe_status = '' or ivr.status = safe_status)
      and (safe_type = '' or ivr.verification_type = safe_type)
      and (
        safe_query = ''
        or p.display_name ilike '%' || safe_query || '%'
        or ivr.legal_first_name ilike '%' || safe_query || '%'
        or ivr.legal_last_name ilike '%' || safe_query || '%'
        or coalesce(ivr.license_number, '') ilike '%' || safe_query || '%'
      );

    select coalesce(jsonb_agg(row_value order by sort_date asc), '[]'::jsonb)
    into items
    from (
      select
        ivr.submitted_at as sort_date,
        jsonb_build_object(
          'kind', 'identity',
          'id', ivr.id,
          'status', ivr.status,
          'verification_type', ivr.verification_type,
          'document_type', ivr.document_type,
          'document_path', ivr.document_path,
          'license_number', ivr.license_number,
          'member_message', ivr.member_message,
          'reviewer_notes', ivr.reviewer_notes,
          'submitted_at', ivr.submitted_at,
          'reviewed_at', ivr.reviewed_at,
          'profile', jsonb_build_object(
            'id', p.id,
            'display_name', p.display_name,
            'slug', p.slug,
            'primary_role_code', p.primary_role_code,
            'current_organization', p.current_organization,
            'city', p.city,
            'verification_status', p.verification_status
          ),
          'identity', jsonb_build_object(
            'legal_first_name', ivr.legal_first_name,
            'legal_last_name', ivr.legal_last_name,
            'date_of_birth', mpp.date_of_birth,
            'country_code', ivr.country_code,
            'guardian_consent_status', mpp.guardian_consent_status
          )
        ) as row_value
      from identity_verification_requests ivr
      join profiles p on p.id = ivr.profile_id
      left join member_private_profiles mpp on mpp.profile_id = ivr.profile_id
      where (safe_status = '' or ivr.status = safe_status)
        and (safe_type = '' or ivr.verification_type = safe_type)
        and (
          safe_query = ''
          or p.display_name ilike '%' || safe_query || '%'
          or ivr.legal_first_name ilike '%' || safe_query || '%'
          or ivr.legal_last_name ilike '%' || safe_query || '%'
          or coalesce(ivr.license_number, '') ilike '%' || safe_query || '%'
        )
      order by ivr.submitted_at asc
      limit safe_limit offset safe_offset
    ) queue_rows;
  elsif safe_kind = 'club_claim' then
    if not is_platform_staff(array['super_admin', 'verifier', 'moderator', 'support']) then
      raise exception 'claim_staff_required';
    end if;

    select count(*) into total_count
    from claims cl
    join clubs c on c.profile_id = cl.target_profile_id
    left join profiles claimant on claimant.id = cl.claimant_profile_id
    where cl.claim_type = 'club_ownership'
      and (safe_status = '' or cl.status = safe_status)
      and (
        safe_query = ''
        or c.official_name ilike '%' || safe_query || '%'
        or coalesce(c.city, '') ilike '%' || safe_query || '%'
        or coalesce(claimant.display_name, '') ilike '%' || safe_query || '%'
        or coalesce(cl.contact_email, '') ilike '%' || safe_query || '%'
      );

    select coalesce(jsonb_agg(row_value order by sort_date asc), '[]'::jsonb)
    into items
    from (
      select
        cl.submitted_at as sort_date,
        jsonb_build_object(
          'kind', 'club_claim',
          'id', cl.id,
          'status', cl.status,
          'organization_role', cl.organization_role,
          'contact_email', cl.contact_email,
          'member_message', cl.message,
          'reviewer_notes', cl.reviewer_notes,
          'evidence', cl.evidence,
          'submitted_at', cl.submitted_at,
          'reviewed_at', cl.reviewed_at,
          'claimant', jsonb_build_object(
            'id', claimant.id,
            'display_name', claimant.display_name,
            'slug', claimant.slug,
            'primary_role_code', claimant.primary_role_code,
            'city', claimant.city
          ),
          'club', jsonb_build_object(
            'id', c.id,
            'profile_id', c.profile_id,
            'official_name', c.official_name,
            'slug', c.slug,
            'city', c.city,
            'country_code', co.iso2,
            'claim_status', c.claim_status,
            'verification_status', c.verification_status
          )
        ) as row_value
      from claims cl
      join clubs c on c.profile_id = cl.target_profile_id
      left join profiles claimant on claimant.id = cl.claimant_profile_id
      left join countries co on co.id = c.country_id
      where cl.claim_type = 'club_ownership'
        and (safe_status = '' or cl.status = safe_status)
        and (
          safe_query = ''
          or c.official_name ilike '%' || safe_query || '%'
          or coalesce(c.city, '') ilike '%' || safe_query || '%'
          or coalesce(claimant.display_name, '') ilike '%' || safe_query || '%'
          or coalesce(cl.contact_email, '') ilike '%' || safe_query || '%'
        )
      order by cl.submitted_at asc
      limit safe_limit offset safe_offset
    ) queue_rows;
  else
    raise exception 'invalid_review_kind';
  end if;

  return jsonb_build_object(
    'kind', safe_kind,
    'total', total_count,
    'limit', safe_limit,
    'offset', safe_offset,
    'items', items
  );
end;
$$;

create or replace function get_admin_review_audit(
  p_entity_type text,
  p_entity_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  safe_type text := lower(trim(coalesce(p_entity_type, '')));
begin
  if not is_platform_staff(array['super_admin', 'verifier', 'moderator', 'support']) then
    raise exception 'staff_access_required';
  end if;

  if safe_type not in ('identity', 'club_claim') then
    raise exception 'invalid_review_kind';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', val.id,
      'action', val.action,
      'previous_status', val.previous_status,
      'new_status', val.new_status,
      'notes', val.notes,
      'created_at', val.created_at,
      'actor_role', ps.staff_role
    ) order by val.created_at desc)
    from verification_audit_log val
    left join platform_staff ps on ps.user_id = val.actor_user_id
    where val.entity_type = safe_type
      and (
        (safe_type = 'identity' and val.identity_request_id = p_entity_id)
        or
        (safe_type = 'club_claim' and val.club_claim_id = p_entity_id)
      )
  ), '[]'::jsonb);
end;
$$;

create or replace function review_identity_verification(
  target_request uuid,
  decision text,
  notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  request_row identity_verification_requests%rowtype;
  safe_decision text := lower(trim(coalesce(decision, '')));
  safe_notes text := nullif(left(trim(coalesce(notes, '')), 4000), '');
  next_status text;
begin
  if actor is null or not is_platform_staff(array['super_admin', 'verifier']) then
    raise exception 'verification_staff_required';
  end if;

  select * into request_row
  from identity_verification_requests
  where id = target_request
  for update;

  if request_row.id is null then
    raise exception 'verification_request_not_found';
  end if;

  if safe_decision = 'start_review' then
    if request_row.status not in ('submitted', 'needs_information') then
      raise exception 'invalid_status_transition';
    end if;
    next_status := 'in_review';
  elsif safe_decision = 'needs_information' then
    if request_row.status not in ('submitted', 'in_review') or safe_notes is null then
      raise exception 'review_notes_required';
    end if;
    next_status := 'needs_information';
  elsif safe_decision = 'approve' then
    if request_row.status not in ('submitted', 'in_review', 'needs_information') then
      raise exception 'invalid_status_transition';
    end if;
    next_status := 'verified';
  elsif safe_decision = 'reject' then
    if request_row.status not in ('submitted', 'in_review', 'needs_information') or safe_notes is null then
      raise exception 'review_notes_required';
    end if;
    next_status := 'rejected';
  else
    raise exception 'invalid_review_decision';
  end if;

  update identity_verification_requests
  set
    status = next_status,
    reviewer_notes = case
      when safe_notes is not null then safe_notes
      else reviewer_notes
    end,
    reviewed_by = actor,
    reviewed_at = case
      when next_status in ('verified', 'rejected') then now()
      else reviewed_at
    end,
    updated_at = now()
  where id = request_row.id;

  insert into verification_audit_log (
    entity_type,
    identity_request_id,
    actor_user_id,
    action,
    previous_status,
    new_status,
    notes,
    metadata
  ) values (
    'identity',
    request_row.id,
    actor,
    safe_decision,
    request_row.status,
    next_status,
    safe_notes,
    jsonb_build_object(
      'profile_id', request_row.profile_id,
      'verification_type', request_row.verification_type,
      'document_type', request_row.document_type
    )
  );

  return jsonb_build_object(
    'reviewed', true,
    'id', request_row.id,
    'previous_status', request_row.status,
    'status', next_status,
    'profile_id', request_row.profile_id
  );
end;
$$;

create or replace function review_club_claim(
  target_claim uuid,
  decision text,
  notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  claim_row claims%rowtype;
  safe_decision text := lower(trim(coalesce(decision, '')));
  safe_notes text := nullif(left(trim(coalesce(notes, '')), 4000), '');
  next_status text;
  rejected_claim record;
begin
  if actor is null or not is_platform_staff(array['super_admin', 'verifier', 'moderator']) then
    raise exception 'claim_staff_required';
  end if;

  select * into claim_row
  from claims
  where id = target_claim and claim_type = 'club_ownership'
  for update;

  if claim_row.id is null then
    raise exception 'club_claim_not_found';
  end if;

  if safe_decision = 'start_review' then
    if claim_row.status <> 'submitted' then
      raise exception 'invalid_status_transition';
    end if;
    next_status := 'reviewing';
  elsif safe_decision = 'approve' then
    if claim_row.status not in ('submitted', 'reviewing') then
      raise exception 'invalid_status_transition';
    end if;
    next_status := 'approved';
  elsif safe_decision = 'reject' then
    if claim_row.status not in ('submitted', 'reviewing') or safe_notes is null then
      raise exception 'review_notes_required';
    end if;
    next_status := 'rejected';
  else
    raise exception 'invalid_review_decision';
  end if;

  update claims
  set
    status = next_status,
    reviewer_notes = case
      when safe_notes is not null then safe_notes
      else reviewer_notes
    end,
    reviewed_at = case
      when next_status in ('approved', 'rejected') then now()
      else reviewed_at
    end,
    reviewed_by_user_id = actor,
    updated_at = now()
  where id = claim_row.id;

  insert into verification_audit_log (
    entity_type,
    club_claim_id,
    actor_user_id,
    action,
    previous_status,
    new_status,
    notes,
    metadata
  ) values (
    'club_claim',
    claim_row.id,
    actor,
    safe_decision,
    claim_row.status,
    next_status,
    safe_notes,
    jsonb_build_object(
      'target_profile_id', claim_row.target_profile_id,
      'claimant_profile_id', claim_row.claimant_profile_id
    )
  );

  if next_status = 'approved' then
    insert into organization_memberships (
      organization_profile_id,
      member_profile_id,
      user_id,
      access_role,
      status,
      source_claim_id,
      updated_at
    ) values (
      claim_row.target_profile_id,
      claim_row.claimant_profile_id,
      claim_row.claimant_user_id,
      'owner',
      'active',
      claim_row.id,
      now()
    )
    on conflict (organization_profile_id, user_id) do update set
      member_profile_id = excluded.member_profile_id,
      access_role = 'owner',
      status = 'active',
      source_claim_id = excluded.source_claim_id,
      updated_at = now();

    for rejected_claim in
      select id, status
      from claims
      where target_profile_id = claim_row.target_profile_id
        and id <> claim_row.id
        and claim_type = 'club_ownership'
        and status in ('submitted', 'reviewing')
      for update
    loop
      update claims
      set
        status = 'rejected',
        reviewer_notes = 'Another ownership claim was approved.',
        reviewed_at = now(),
        reviewed_by_user_id = actor,
        updated_at = now()
      where id = rejected_claim.id;
      insert into verification_audit_log (
        entity_type,
        club_claim_id,
        actor_user_id,
        action,
        previous_status,
        new_status,
        notes,
        metadata
      ) values (
        'club_claim',
        rejected_claim.id,
        actor,
        'auto_reject',
        rejected_claim.status,
        'rejected',
        'Another ownership claim was approved.',
        jsonb_build_object('approved_claim_id', claim_row.id)
      );
    end loop;

    update clubs
    set claim_status = 'claimed', verification_status = 'verified', updated_at = now()
    where profile_id = claim_row.target_profile_id;

    update profiles
    set claim_status = 'claimed', verification_status = 'verified', updated_at = now()
    where id = claim_row.target_profile_id;
  elsif next_status = 'rejected' then
    if exists (
      select 1
      from claims
      where target_profile_id = claim_row.target_profile_id
        and id <> claim_row.id
        and claim_type = 'club_ownership'
        and status in ('submitted', 'reviewing')
    ) then
      update clubs set claim_status = 'pending', updated_at = now()
      where profile_id = claim_row.target_profile_id and claim_status <> 'claimed';
      update profiles set claim_status = 'pending', updated_at = now()
      where id = claim_row.target_profile_id and claim_status <> 'claimed';
    else
      update clubs set claim_status = 'unclaimed', updated_at = now()
      where profile_id = claim_row.target_profile_id and claim_status <> 'claimed';
      update profiles set claim_status = 'unclaimed', updated_at = now()
      where id = claim_row.target_profile_id and claim_status <> 'claimed';
    end if;
  end if;

  return jsonb_build_object(
    'reviewed', true,
    'id', claim_row.id,
    'previous_status', claim_row.status,
    'status', next_status,
    'target_profile_id', claim_row.target_profile_id
  );
end;
$$;

revoke all on table platform_staff from public, anon, authenticated;
revoke all on table organization_memberships from public, anon, authenticated;
revoke all on table verification_audit_log from public, anon, authenticated;

grant select on table platform_staff to authenticated;
grant select on table organization_memberships to authenticated;
grant all on table platform_staff to service_role;
grant all on table organization_memberships to service_role;
grant all on table verification_audit_log to service_role;

revoke all on function is_platform_staff(text[]) from public, anon;
revoke all on function get_admin_verification_dashboard() from public, anon;
revoke all on function get_admin_review_queue(text, text, text, text, integer, integer) from public, anon;
revoke all on function get_admin_review_audit(text, uuid) from public, anon;
revoke all on function review_identity_verification(uuid, text, text) from public, anon;
revoke all on function review_club_claim(uuid, text, text) from public, anon;

grant execute on function is_platform_staff(text[]) to authenticated;
grant execute on function get_admin_verification_dashboard() to authenticated;
grant execute on function get_admin_review_queue(text, text, text, text, integer, integer) to authenticated;
grant execute on function get_admin_review_audit(text, uuid) to authenticated;
grant execute on function review_identity_verification(uuid, text, text) to authenticated;
grant execute on function review_club_claim(uuid, text, text) to authenticated;

commit;
