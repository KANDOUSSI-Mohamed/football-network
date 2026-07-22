-- Football Network: complete professional profiles for every football role.
-- Additive and idempotent. Run after 20260722_social_feed.sql.

begin;

alter table profiles
  add column if not exists headline text,
  add column if not exists current_organization text,
  add column if not exists availability_status text not null default 'open_to_opportunities',
  add column if not exists years_experience numeric(4,1),
  add column if not exists languages text[] not null default '{}'::text[],
  add column if not exists profile_completion_score integer not null default 20;

create table if not exists professional_experiences (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references profiles(id) on delete cascade,
  organization_name text not null,
  role_title text not null,
  location_text text,
  start_date date,
  end_date date,
  is_current boolean not null default false,
  description text,
  sort_order integer not null default 0,
  visibility text not null default 'public' check (visibility in ('public', 'connections', 'private')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);

create table if not exists profile_skills (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references profiles(id) on delete cascade,
  skill_name text not null,
  category text not null default 'professional',
  endorsement_count integer not null default 0,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (profile_id, skill_name)
);

create index if not exists idx_professional_experiences_profile
  on professional_experiences(profile_id, sort_order, start_date desc);

create index if not exists idx_profile_skills_profile
  on profile_skills(profile_id, sort_order, skill_name);

create unique index if not exists idx_player_profiles_profile_unique
  on player_profiles(profile_id);

alter table professional_experiences enable row level security;
alter table profile_skills enable row level security;
alter table player_profiles enable row level security;
alter table media_assets enable row level security;
alter table documents enable row level security;

drop policy if exists "Visible experiences are readable" on professional_experiences;
create policy "Visible experiences are readable"
  on professional_experiences for select
  using (
    visibility = 'public'
    or exists (select 1 from profiles p where p.id = profile_id and p.user_id = auth.uid())
  );

drop policy if exists "Owners manage experiences" on professional_experiences;
create policy "Owners manage experiences"
  on professional_experiences for all
  using (exists (select 1 from profiles p where p.id = profile_id and p.user_id = auth.uid()))
  with check (exists (select 1 from profiles p where p.id = profile_id and p.user_id = auth.uid()));

drop policy if exists "Public skills are readable" on profile_skills;
create policy "Public skills are readable"
  on profile_skills for select
  using (exists (
    select 1 from profiles p
    where p.id = profile_id and (p.visibility = 'public' or p.user_id = auth.uid())
  ));

drop policy if exists "Owners manage skills" on profile_skills;
create policy "Owners manage skills"
  on profile_skills for all
  using (exists (select 1 from profiles p where p.id = profile_id and p.user_id = auth.uid()))
  with check (exists (select 1 from profiles p where p.id = profile_id and p.user_id = auth.uid()));

drop policy if exists "Public player details are readable" on player_profiles;
create policy "Public player details are readable"
  on player_profiles for select
  using (exists (
    select 1 from profiles p
    where p.id = profile_id and (p.visibility = 'public' or p.user_id = auth.uid())
  ));

drop policy if exists "Owners manage player details" on player_profiles;
create policy "Owners manage player details"
  on player_profiles for all
  using (exists (select 1 from profiles p where p.id = profile_id and p.user_id = auth.uid()))
  with check (exists (select 1 from profiles p where p.id = profile_id and p.user_id = auth.uid()));

drop policy if exists "Visible profile media are readable" on media_assets;
create policy "Visible profile media are readable"
  on media_assets for select
  using (
    visibility = 'public'
    or exists (select 1 from profiles p where p.id = owner_profile_id and p.user_id = auth.uid())
  );

drop policy if exists "Owners manage profile media" on media_assets;
create policy "Owners manage profile media"
  on media_assets for all
  using (exists (select 1 from profiles p where p.id = owner_profile_id and p.user_id = auth.uid()))
  with check (exists (select 1 from profiles p where p.id = owner_profile_id and p.user_id = auth.uid()));

drop policy if exists "Owners read profile documents" on documents;
create policy "Owners read profile documents"
  on documents for select
  using (exists (select 1 from profiles p where p.id = owner_profile_id and p.user_id = auth.uid()));

drop policy if exists "Owners manage profile documents" on documents;
create policy "Owners manage profile documents"
  on documents for all
  using (exists (select 1 from profiles p where p.id = owner_profile_id and p.user_id = auth.uid()))
  with check (exists (select 1 from profiles p where p.id = owner_profile_id and p.user_id = auth.uid()));

grant select, insert, update, delete on professional_experiences to authenticated;
grant select on professional_experiences to anon;
grant select, insert, update, delete on profile_skills to authenticated;
grant select on profile_skills to anon;
grant select, insert, update, delete on player_profiles to authenticated;
grant select on player_profiles to anon;
grant select, insert, update, delete on media_assets to authenticated;
grant select on media_assets to anon;
grant select, insert, update, delete on documents to authenticated;
grant select, insert, update, delete on profile_contacts to authenticated;
grant select, insert, update, delete on profile_contact_settings to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('profile-media', 'profile-media', true, 15728640, array['image/jpeg','image/png','image/webp','video/mp4','video/webm']),
  ('profile-documents', 'profile-documents', false, 10485760, array['application/pdf'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public profile media are readable" on storage.objects;
create policy "Public profile media are readable"
  on storage.objects for select
  using (bucket_id = 'profile-media');

drop policy if exists "Members upload their profile media" on storage.objects;
create policy "Members upload their profile media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-media'
    and exists (
      select 1 from profiles p
      where p.user_id = auth.uid()
        and p.id::text = (storage.foldername(name))[1]
    )
  );

drop policy if exists "Members update their profile media" on storage.objects;
create policy "Members update their profile media"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profile-media'
    and exists (select 1 from profiles p where p.user_id = auth.uid() and p.id::text = (storage.foldername(name))[1])
  )
  with check (
    bucket_id = 'profile-media'
    and exists (select 1 from profiles p where p.user_id = auth.uid() and p.id::text = (storage.foldername(name))[1])
  );

drop policy if exists "Members delete their profile media" on storage.objects;
create policy "Members delete their profile media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-media'
    and exists (select 1 from profiles p where p.user_id = auth.uid() and p.id::text = (storage.foldername(name))[1])
  );

drop policy if exists "Members read their profile documents" on storage.objects;
create policy "Members read their profile documents"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profile-documents'
    and exists (select 1 from profiles p where p.user_id = auth.uid() and p.id::text = (storage.foldername(name))[1])
  );

drop policy if exists "Members upload their profile documents" on storage.objects;
create policy "Members upload their profile documents"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-documents'
    and exists (select 1 from profiles p where p.user_id = auth.uid() and p.id::text = (storage.foldername(name))[1])
  );

drop policy if exists "Members delete their profile documents" on storage.objects;
create policy "Members delete their profile documents"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-documents'
    and exists (select 1 from profiles p where p.user_id = auth.uid() and p.id::text = (storage.foldername(name))[1])
  );

create or replace function update_professional_profile(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  target profiles%rowtype;
  role_record professional_roles%rowtype;
  safe_name text := trim(coalesce(payload->>'display_name', ''));
  safe_role text := trim(coalesce(payload->>'primary_role_code', ''));
  completion integer := 20;
begin
  if requester is null then raise exception 'authentication_required'; end if;

  select * into target from profiles
  where user_id = requester and profile_type = 'person'
  order by created_at limit 1;
  if target.id is null then raise exception 'profile_required'; end if;

  select * into role_record from professional_roles
  where code = safe_role and is_active;
  if role_record.id is null then raise exception 'invalid_professional_role'; end if;
  if char_length(safe_name) < 2 or char_length(safe_name) > 120 then raise exception 'invalid_display_name'; end if;

  completion := 20
    + case when nullif(trim(coalesce(payload->>'headline','')), '') is not null then 10 else 0 end
    + case when nullif(trim(coalesce(payload->>'bio','')), '') is not null then 10 else 0 end
    + case when nullif(trim(coalesce(payload->>'city','')), '') is not null then 5 else 0 end
    + case when nullif(trim(coalesce(payload->>'location_text','')), '') is not null then 5 else 0 end
    + case when nullif(trim(coalesce(payload->>'current_organization','')), '') is not null then 10 else 0 end
    + case when jsonb_array_length(coalesce(payload->'languages','[]'::jsonb)) > 0 then 5 else 0 end
    + case when nullif(trim(coalesce(payload->>'avatar_url','')), '') is not null then 10 else 0 end
    + case when exists (select 1 from professional_experiences e where e.profile_id = target.id) then 10 else 0 end
    + case when exists (select 1 from profile_skills s where s.profile_id = target.id) then 5 else 0 end
    + case when exists (select 1 from profile_contacts c where c.profile_id = target.id) then 5 else 0 end;

  update profiles set
    display_name = safe_name,
    primary_role_code = safe_role,
    headline = nullif(left(trim(coalesce(payload->>'headline','')), 180), ''),
    bio = nullif(left(trim(coalesce(payload->>'bio','')), 2000), ''),
    city = nullif(left(trim(coalesce(payload->>'city','')), 80), ''),
    location_text = nullif(left(trim(coalesce(payload->>'location_text','')), 120), ''),
    current_organization = nullif(left(trim(coalesce(payload->>'current_organization','')), 140), ''),
    availability_status = case
      when payload->>'availability_status' in ('available_now','open_to_opportunities','not_available') then payload->>'availability_status'
      else 'open_to_opportunities'
    end,
    years_experience = case when payload->>'years_experience' ~ '^\d{1,2}(\.\d)?$' then least((payload->>'years_experience')::numeric, 70) else null end,
    languages = coalesce(array(select left(trim(value), 40) from jsonb_array_elements_text(coalesce(payload->'languages','[]'::jsonb)) value where trim(value) <> '' limit 12), '{}'::text[]),
    avatar_url = coalesce(nullif(left(trim(coalesce(payload->>'avatar_url','')), 1000), ''), avatar_url),
    cover_url = coalesce(nullif(left(trim(coalesce(payload->>'cover_url','')), 1000), ''), cover_url),
    profile_completion_score = least(completion, 100),
    updated_at = now()
  where id = target.id
  returning * into target;

  update profile_roles set is_primary = false where profile_id = target.id;
  insert into profile_roles(profile_id, role_id, is_primary)
  values (target.id, role_record.id, true)
  on conflict (profile_id, role_id) do update set is_primary = true;

  return jsonb_build_object('updated', true, 'id', target.id, 'slug', target.slug, 'completion', target.profile_completion_score);
end;
$$;

create or replace function replace_profile_skills(skill_names text[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requester uuid := auth.uid();
  target_id uuid;
begin
  if requester is null then raise exception 'authentication_required'; end if;
  select id into target_id from profiles where user_id = requester and profile_type = 'person' order by created_at limit 1;
  if target_id is null then raise exception 'profile_required'; end if;

  delete from profile_skills where profile_id = target_id;
  insert into profile_skills(profile_id, skill_name, sort_order)
  select target_id, left(trim(value), 80), row_number() over ()::integer
  from unnest(coalesce(skill_names, '{}'::text[])) value
  where trim(value) <> ''
  group by value
  limit 20;

  return jsonb_build_object('updated', true, 'count', (select count(*) from profile_skills where profile_id = target_id));
end;
$$;

revoke all on function update_professional_profile(jsonb) from public;
revoke all on function replace_profile_skills(text[]) from public;
grant execute on function update_professional_profile(jsonb) to authenticated;
grant execute on function replace_profile_skills(text[]) to authenticated;

commit;
