-- Football Network: worldwide talent search, saved searches and private shortlists.
-- Additive and idempotent. Run after 20260722_professional_profiles.sql.

begin;

create table if not exists saved_profile_searches (
  id uuid primary key default uuid_generate_v4(),
  owner_profile_id uuid not null references profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  filters jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_profile_id, name)
);

create table if not exists profile_shortlists (
  id uuid primary key default uuid_generate_v4(),
  owner_profile_id uuid not null references profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_profile_id, name)
);

create table if not exists profile_shortlist_items (
  shortlist_id uuid not null references profile_shortlists(id) on delete cascade,
  target_profile_id uuid not null references profiles(id) on delete cascade,
  note text,
  status text not null default 'saved' check (status in ('saved', 'contacted', 'reviewing', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shortlist_id, target_profile_id)
);

create index if not exists idx_saved_profile_searches_owner
  on saved_profile_searches(owner_profile_id, updated_at desc);

create index if not exists idx_profile_shortlists_owner
  on profile_shortlists(owner_profile_id, updated_at desc);

create index if not exists idx_profile_shortlist_items_target
  on profile_shortlist_items(target_profile_id, created_at desc);

create index if not exists idx_profiles_public_search
  on profiles(profile_type, visibility, primary_role_code, availability_status, profile_completion_score desc);

alter table saved_profile_searches enable row level security;
alter table profile_shortlists enable row level security;
alter table profile_shortlist_items enable row level security;

drop policy if exists "Members manage their saved profile searches" on saved_profile_searches;
create policy "Members manage their saved profile searches"
  on saved_profile_searches for all to authenticated
  using (owner_profile_id = current_member_profile_id())
  with check (owner_profile_id = current_member_profile_id());

drop policy if exists "Members manage their profile shortlists" on profile_shortlists;
create policy "Members manage their profile shortlists"
  on profile_shortlists for all to authenticated
  using (owner_profile_id = current_member_profile_id())
  with check (owner_profile_id = current_member_profile_id());

drop policy if exists "Members manage their profile shortlist items" on profile_shortlist_items;
create policy "Members manage their profile shortlist items"
  on profile_shortlist_items for all to authenticated
  using (
    exists (
      select 1 from profile_shortlists s
      where s.id = shortlist_id and s.owner_profile_id = current_member_profile_id()
    )
  )
  with check (
    exists (
      select 1 from profile_shortlists s
      where s.id = shortlist_id and s.owner_profile_id = current_member_profile_id()
    )
  );

grant select, insert, update, delete on saved_profile_searches to authenticated;
grant select, insert, update, delete on profile_shortlists to authenticated;
grant select, insert, update, delete on profile_shortlist_items to authenticated;

create or replace function search_professional_profiles(
  p_query text default '',
  p_role_code text default '',
  p_location text default '',
  p_availability text default '',
  p_min_completion integer default 0,
  p_limit integer default 24,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  safe_query text := left(trim(coalesce(p_query, '')), 120);
  safe_role text := left(trim(coalesce(p_role_code, '')), 80);
  safe_location text := left(trim(coalesce(p_location, '')), 120);
  safe_availability text := left(trim(coalesce(p_availability, '')), 40);
  safe_min_completion integer := greatest(0, least(coalesce(p_min_completion, 0), 100));
  safe_limit integer := greatest(1, least(coalesce(p_limit, 24), 50));
  safe_offset integer := greatest(0, least(coalesce(p_offset, 0), 5000));
  result jsonb;
begin
  with matching as (
    select
      p.id,
      p.display_name,
      p.slug,
      p.primary_role_code,
      p.headline,
      p.current_organization,
      p.city,
      p.location_text,
      p.avatar_url,
      p.availability_status,
      p.profile_completion_score,
      p.verification_status,
      p.years_experience,
      p.created_at
    from profiles p
    where p.profile_type = 'person'
      and p.visibility = 'public'
      and (safe_role = '' or p.primary_role_code = safe_role)
      and (safe_availability = '' or p.availability_status = safe_availability)
      and coalesce(p.profile_completion_score, 0) >= safe_min_completion
      and (
        safe_location = ''
        or coalesce(p.city, '') ilike '%' || safe_location || '%'
        or coalesce(p.location_text, '') ilike '%' || safe_location || '%'
      )
      and (
        safe_query = ''
        or coalesce(p.display_name, '') ilike '%' || safe_query || '%'
        or coalesce(p.headline, '') ilike '%' || safe_query || '%'
        or coalesce(p.current_organization, '') ilike '%' || safe_query || '%'
        or coalesce(p.bio, '') ilike '%' || safe_query || '%'
        or coalesce(p.city, '') ilike '%' || safe_query || '%'
        or coalesce(p.location_text, '') ilike '%' || safe_query || '%'
        or exists (
          select 1 from profile_skills ps
          where ps.profile_id = p.id and ps.skill_name ilike '%' || safe_query || '%'
        )
        or exists (
          select 1 from player_profiles pp
          where pp.profile_id = p.id
            and (
              coalesce(pp.primary_position, '') ilike '%' || safe_query || '%'
              or coalesce(pp.birth_place, '') ilike '%' || safe_query || '%'
            )
        )
      )
  ), counted as (
    select count(*)::integer as total from matching
  ), paged as (
    select * from matching
    order by
      case availability_status when 'available_now' then 0 when 'open_to_opportunities' then 1 else 2 end,
      profile_completion_score desc,
      verification_status = 'verified' desc,
      created_at desc
    limit safe_limit offset safe_offset
  )
  select jsonb_build_object(
    'total', counted.total,
    'results', coalesce((select jsonb_agg(to_jsonb(paged) - 'created_at') from paged), '[]'::jsonb)
  ) into result
  from counted;

  return coalesce(result, jsonb_build_object('total', 0, 'results', '[]'::jsonb));
end;
$$;

create or replace function save_profile_search(p_name text, p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid := current_member_profile_id();
  safe_name text := left(trim(coalesce(p_name, '')), 80);
  saved saved_profile_searches%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if owner_id is null then raise exception 'profile_required'; end if;
  if safe_name = '' then raise exception 'search_name_required'; end if;

  insert into saved_profile_searches(owner_profile_id, name, filters)
  values (owner_id, safe_name, coalesce(p_filters, '{}'::jsonb))
  on conflict (owner_profile_id, name) do update set
    filters = excluded.filters,
    updated_at = now()
  returning * into saved;

  return jsonb_build_object('saved', true, 'id', saved.id, 'name', saved.name, 'filters', saved.filters);
end;
$$;

create or replace function get_saved_profile_searches()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  owner_id uuid := current_member_profile_id();
begin
  if auth.uid() is null or owner_id is null then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'filters', s.filters, 'updated_at', s.updated_at) order by s.updated_at desc)
    from saved_profile_searches s where s.owner_profile_id = owner_id
  ), '[]'::jsonb);
end;
$$;

create or replace function delete_saved_profile_search(target_search uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid := current_member_profile_id();
  affected integer := 0;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  delete from saved_profile_searches where id = target_search and owner_profile_id = owner_id;
  get diagnostics affected = row_count;
  return jsonb_build_object('deleted', affected = 1);
end;
$$;

create or replace function toggle_shortlist_profile(target_profile uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid := current_member_profile_id();
  list_id uuid;
  affected integer := 0;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if owner_id is null then raise exception 'profile_required'; end if;
  if target_profile is null or target_profile = owner_id then raise exception 'invalid_target'; end if;
  if not exists (
    select 1 from profiles p
    where p.id = target_profile and p.profile_type = 'person' and p.visibility = 'public'
  ) then raise exception 'profile_not_found'; end if;

  select id into list_id from profile_shortlists
  where owner_profile_id = owner_id and is_default
  order by created_at limit 1;

  if list_id is null then
    insert into profile_shortlists(owner_profile_id, name, is_default)
    values (owner_id, 'Mes favoris', true)
    on conflict (owner_profile_id, name) do update set is_default = true, updated_at = now()
    returning id into list_id;
  end if;

  delete from profile_shortlist_items
  where shortlist_id = list_id and target_profile_id = target_profile;
  get diagnostics affected = row_count;

  if affected = 1 then
    update profile_shortlists set updated_at = now() where id = list_id;
    return jsonb_build_object('saved', false, 'shortlist_id', list_id);
  end if;

  insert into profile_shortlist_items(shortlist_id, target_profile_id)
  values (list_id, target_profile)
  on conflict (shortlist_id, target_profile_id) do nothing;
  update profile_shortlists set updated_at = now() where id = list_id;
  return jsonb_build_object('saved', true, 'shortlist_id', list_id);
end;
$$;

create or replace function get_member_shortlist()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  owner_id uuid := current_member_profile_id();
begin
  if auth.uid() is null or owner_id is null then
    return jsonb_build_object('profile_ids', '[]'::jsonb, 'profiles', '[]'::jsonb);
  end if;

  return jsonb_build_object(
    'profile_ids', coalesce((
      select jsonb_agg(i.target_profile_id)
      from profile_shortlist_items i
      join profile_shortlists s on s.id = i.shortlist_id
      where s.owner_profile_id = owner_id and s.is_default
    ), '[]'::jsonb),
    'profiles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'display_name', p.display_name,
        'slug', p.slug,
        'primary_role_code', p.primary_role_code,
        'headline', p.headline,
        'current_organization', p.current_organization,
        'city', p.city,
        'location_text', p.location_text,
        'avatar_url', p.avatar_url,
        'availability_status', p.availability_status,
        'profile_completion_score', p.profile_completion_score,
        'verification_status', p.verification_status,
        'saved_at', i.created_at
      ) order by i.created_at desc)
      from profile_shortlist_items i
      join profile_shortlists s on s.id = i.shortlist_id
      join profiles p on p.id = i.target_profile_id
      where s.owner_profile_id = owner_id and s.is_default
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function search_professional_profiles(text,text,text,text,integer,integer,integer) from public;
revoke all on function save_profile_search(text,jsonb) from public;
revoke all on function get_saved_profile_searches() from public;
revoke all on function delete_saved_profile_search(uuid) from public;
revoke all on function toggle_shortlist_profile(uuid) from public;
revoke all on function get_member_shortlist() from public;

grant execute on function search_professional_profiles(text,text,text,text,integer,integer,integer) to anon, authenticated;
grant execute on function save_profile_search(text,jsonb) to authenticated;
grant execute on function get_saved_profile_searches() to authenticated;
grant execute on function delete_saved_profile_search(uuid) to authenticated;
grant execute on function toggle_shortlist_profile(uuid) to authenticated;
grant execute on function get_member_shortlist() to authenticated;

commit;
