-- Football Network: secure recruitment marketplace, applications and targeted alerts.
-- Additive and idempotent. Run after 20260722_talent_search.sql.

begin;

alter table opportunities
  add column if not exists created_by_profile_id uuid references profiles(id) on delete cascade,
  add column if not exists organization_name text,
  add column if not exists role_code text,
  add column if not exists location_text text,
  add column if not exists work_mode text not null default 'on_site',
  add column if not exists compensation_text text,
  add column if not exists requirements jsonb not null default '{}'::jsonb,
  add column if not exists featured boolean not null default false,
  add column if not exists application_count integer not null default 0,
  add column if not exists published_at timestamptz not null default now(),
  add column if not exists closed_at timestamptz;

alter table applications
  add column if not exists recruiter_note text,
  add column if not exists viewed_at timestamptz,
  add column if not exists withdrawn_at timestamptz;

alter table opportunities drop constraint if exists opportunities_organization_profile_id_fkey;
alter table opportunities
  add constraint opportunities_organization_profile_id_fkey
  foreign key (organization_profile_id) references profiles(id) on delete cascade;

alter table applications drop constraint if exists applications_opportunity_id_fkey;
alter table applications
  add constraint applications_opportunity_id_fkey
  foreign key (opportunity_id) references opportunities(id) on delete cascade;

alter table applications drop constraint if exists applications_applicant_profile_id_fkey;
alter table applications
  add constraint applications_applicant_profile_id_fkey
  foreign key (applicant_profile_id) references profiles(id) on delete cascade;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid='opportunities'::regclass and conname='opportunities_marketplace_type_check') then
    alter table opportunities add constraint opportunities_marketplace_type_check
      check (opportunity_type in ('player_recruitment','staff_job','trial','internship','service','partnership'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid='opportunities'::regclass and conname='opportunities_marketplace_status_check') then
    alter table opportunities add constraint opportunities_marketplace_status_check
      check (status in ('draft','open','paused','closed','filled'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid='opportunities'::regclass and conname='opportunities_work_mode_check') then
    alter table opportunities add constraint opportunities_work_mode_check
      check (work_mode in ('on_site','hybrid','remote','mobile'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid='applications'::regclass and conname='applications_marketplace_status_check') then
    alter table applications add constraint applications_marketplace_status_check
      check (status in ('submitted','viewed','shortlisted','interview','accepted','rejected','withdrawn'));
  end if;
end;
$$;

create unique index if not exists idx_applications_opportunity_applicant
  on applications(opportunity_id, applicant_profile_id);

create index if not exists idx_opportunities_marketplace_search
  on opportunities(status, visibility, opportunity_type, role_code, published_at desc);

create index if not exists idx_opportunities_creator
  on opportunities(created_by_profile_id, published_at desc);

create index if not exists idx_applications_applicant
  on applications(applicant_profile_id, submitted_at desc);

create index if not exists idx_applications_opportunity_status
  on applications(opportunity_id, status, submitted_at desc);

create table if not exists opportunity_bookmarks (
  opportunity_id uuid not null references opportunities(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (opportunity_id, profile_id)
);

create table if not exists opportunity_alerts (
  id uuid primary key default uuid_generate_v4(),
  owner_profile_id uuid not null references profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  query_text text,
  opportunity_type text,
  role_code text,
  location_query text,
  contract_type text,
  is_enabled boolean not null default true,
  last_notified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_opportunity_bookmarks_profile
  on opportunity_bookmarks(profile_id, created_at desc);

create index if not exists idx_opportunity_alerts_owner
  on opportunity_alerts(owner_profile_id, updated_at desc);

alter table notifications drop constraint if exists notifications_notification_type_check;
alter table notifications add constraint notifications_notification_type_check
  check (notification_type in (
    'post_reaction','post_comment','opportunity_match','application_received','application_status'
  ));

alter table opportunities enable row level security;
alter table applications enable row level security;
alter table opportunity_bookmarks enable row level security;
alter table opportunity_alerts enable row level security;

drop policy if exists "Public opportunities are readable" on opportunities;
create policy "Public opportunities are readable"
  on opportunities for select
  using (
    (visibility='public' and status='open' and (deadline is null or deadline >= current_date))
    or created_by_profile_id = current_member_profile_id()
  );

drop policy if exists "Publishers manage opportunities" on opportunities;
create policy "Publishers manage opportunities"
  on opportunities for all to authenticated
  using (created_by_profile_id = current_member_profile_id())
  with check (created_by_profile_id = current_member_profile_id());

drop policy if exists "Application participants can read" on applications;
create policy "Application participants can read"
  on applications for select to authenticated
  using (
    applicant_profile_id = current_member_profile_id()
    or exists (
      select 1 from opportunities o
      where o.id = opportunity_id and o.created_by_profile_id = current_member_profile_id()
    )
  );

drop policy if exists "Applicants own applications" on applications;
create policy "Applicants own applications"
  on applications for insert to authenticated
  with check (applicant_profile_id = current_member_profile_id());

drop policy if exists "Recruiters update applications" on applications;
create policy "Recruiters update applications"
  on applications for update to authenticated
  using (
    applicant_profile_id = current_member_profile_id()
    or exists (
      select 1 from opportunities o
      where o.id = opportunity_id and o.created_by_profile_id = current_member_profile_id()
    )
  );

drop policy if exists "Members manage opportunity bookmarks" on opportunity_bookmarks;
create policy "Members manage opportunity bookmarks"
  on opportunity_bookmarks for all to authenticated
  using (profile_id = current_member_profile_id())
  with check (profile_id = current_member_profile_id());

drop policy if exists "Members manage opportunity alerts" on opportunity_alerts;
create policy "Members manage opportunity alerts"
  on opportunity_alerts for all to authenticated
  using (owner_profile_id = current_member_profile_id())
  with check (owner_profile_id = current_member_profile_id());

grant select on opportunities to anon, authenticated;
grant select, insert, update on applications to authenticated;
grant select, insert, update, delete on opportunity_bookmarks to authenticated;
grant select, insert, update, delete on opportunity_alerts to authenticated;

create or replace function search_recruitment_opportunities(
  p_query text default '',
  p_opportunity_type text default '',
  p_role_code text default '',
  p_location text default '',
  p_contract_type text default '',
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  viewer uuid := current_member_profile_id();
  viewer_role text;
  safe_query text := left(trim(coalesce(p_query,'')),120);
  safe_type text := left(trim(coalesce(p_opportunity_type,'')),40);
  safe_role text := left(trim(coalesce(p_role_code,'')),80);
  safe_location text := left(trim(coalesce(p_location,'')),120);
  safe_contract text := left(trim(coalesce(p_contract_type,'')),40);
  safe_limit integer := greatest(1,least(coalesce(p_limit,20),50));
  safe_offset integer := greatest(0,least(coalesce(p_offset,0),5000));
  result jsonb;
begin
  if viewer is not null then select primary_role_code into viewer_role from profiles where id=viewer; end if;

  with matching as (
    select
      o.id,o.opportunity_type,o.title,o.description,o.organization_name,o.role_code,o.location_text,o.city,
      o.level,o.position,o.age_min,o.age_max,o.contract_type,o.work_mode,o.compensation_text,o.requirements,
      o.start_date,o.deadline,o.status,o.featured,o.application_count,o.source_locale,o.published_at,
      p.id as publisher_id,p.display_name as publisher_name,p.slug as publisher_slug,p.avatar_url as publisher_avatar,
      p.verification_status as publisher_verification,
      exists(select 1 from applications a where a.opportunity_id=o.id and a.applicant_profile_id=viewer) as applied,
      exists(select 1 from opportunity_bookmarks b where b.opportunity_id=o.id and b.profile_id=viewer) as bookmarked,
      (viewer_role is not null and o.role_code=viewer_role) as recommended
    from opportunities o
    join profiles p on p.id=coalesce(o.created_by_profile_id,o.organization_profile_id)
    where o.visibility='public' and o.status='open'
      and (o.deadline is null or o.deadline >= current_date)
      and (safe_type='' or o.opportunity_type=safe_type)
      and (safe_role='' or o.role_code=safe_role)
      and (safe_contract='' or o.contract_type=safe_contract)
      and (safe_location='' or coalesce(o.city,'') ilike '%'||safe_location||'%' or coalesce(o.location_text,'') ilike '%'||safe_location||'%')
      and (
        safe_query=''
        or coalesce(o.title,'') ilike '%'||safe_query||'%'
        or coalesce(o.description,'') ilike '%'||safe_query||'%'
        or coalesce(o.organization_name,'') ilike '%'||safe_query||'%'
        or coalesce(o.position,'') ilike '%'||safe_query||'%'
        or coalesce(o.role_code,'') ilike '%'||safe_query||'%'
      )
  ), counted as (select count(*)::integer as total from matching), paged as (
    select * from matching
    order by featured desc,recommended desc,published_at desc
    limit safe_limit offset safe_offset
  )
  select jsonb_build_object(
    'total',counted.total,
    'results',coalesce((select jsonb_agg(to_jsonb(paged) order by featured desc,recommended desc,published_at desc) from paged),'[]'::jsonb)
  ) into result from counted;

  return coalesce(result,jsonb_build_object('total',0,'results','[]'::jsonb));
end;
$$;

create or replace function publish_opportunity(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  publisher uuid := current_member_profile_id();
  publisher_profile profiles%rowtype;
  created opportunities%rowtype;
  safe_title text := trim(coalesce(payload->>'title',''));
  safe_description text := trim(coalesce(payload->>'description',''));
  safe_type text := trim(coalesce(payload->>'opportunity_type',''));
  safe_role text := trim(coalesce(payload->>'role_code',''));
  safe_contract text := trim(coalesce(payload->>'contract_type',''));
  safe_work_mode text := trim(coalesce(payload->>'work_mode','on_site'));
  safe_locale text := lower(trim(coalesce(payload->>'source_locale','fr')));
  safe_deadline date;
  min_age integer;
  max_age integer;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if publisher is null then raise exception 'profile_required'; end if;
  select * into publisher_profile from profiles where id=publisher;
  if char_length(safe_title)<5 or char_length(safe_title)>140 then raise exception 'invalid_title'; end if;
  if char_length(safe_description)<20 or char_length(safe_description)>5000 then raise exception 'invalid_description'; end if;
  if safe_type not in ('player_recruitment','staff_job','trial','internship','service','partnership') then raise exception 'invalid_opportunity_type'; end if;
  if safe_role<>'' and not exists(select 1 from professional_roles where code=safe_role and is_active) then raise exception 'invalid_professional_role'; end if;
  if safe_contract not in ('permanent','fixed_term','trial','internship','freelance','volunteer','partnership','other') then raise exception 'invalid_contract_type'; end if;
  if safe_work_mode not in ('on_site','hybrid','remote','mobile') then safe_work_mode:='on_site'; end if;
  if not exists(select 1 from supported_locales where code=safe_locale and is_enabled) then safe_locale:='fr'; end if;
  if coalesce(payload->>'deadline','') ~ '^\d{4}-\d{2}-\d{2}$' then safe_deadline:=(payload->>'deadline')::date; end if;
  if safe_deadline is not null and safe_deadline<current_date then raise exception 'invalid_deadline'; end if;
  if coalesce(payload->>'age_min','') ~ '^\d{1,2}$' then min_age:=(payload->>'age_min')::integer; end if;
  if coalesce(payload->>'age_max','') ~ '^\d{1,2}$' then max_age:=(payload->>'age_max')::integer; end if;
  if min_age is not null and max_age is not null and min_age>max_age then raise exception 'invalid_age_range'; end if;

  insert into opportunities(
    organization_profile_id,created_by_profile_id,organization_name,opportunity_type,title,description,city,location_text,
    level,position,role_code,age_min,age_max,contract_type,work_mode,compensation_text,requirements,start_date,deadline,
    visibility,status,source_locale,published_at
  ) values (
    publisher,publisher,coalesce(nullif(left(trim(coalesce(payload->>'organization_name','')),140),''),publisher_profile.current_organization,publisher_profile.display_name),
    safe_type,left(safe_title,140),left(safe_description,5000),nullif(left(trim(coalesce(payload->>'city','')),80),''),
    nullif(left(trim(coalesce(payload->>'location_text','')),160),''),nullif(left(trim(coalesce(payload->>'level','')),80),''),
    nullif(left(trim(coalesce(payload->>'position','')),120),''),nullif(safe_role,''),min_age,max_age,safe_contract,safe_work_mode,
    nullif(left(trim(coalesce(payload->>'compensation_text','')),160),''),
    case when jsonb_typeof(payload->'requirements')='object' then payload->'requirements' else '{}'::jsonb end,
    case when coalesce(payload->>'start_date','') ~ '^\d{4}-\d{2}-\d{2}$' then (payload->>'start_date')::date else null end,
    safe_deadline,'public','open',safe_locale,now()
  ) returning * into created;

  insert into opportunity_translations(opportunity_id,locale,title,description,translation_origin,review_status)
  values(created.id,safe_locale,created.title,created.description,'human','reviewed')
  on conflict(opportunity_id,locale) do update set title=excluded.title,description=excluded.description,updated_at=now();

  return jsonb_build_object('published',true,'id',created.id,'title',created.title);
end;
$$;

create or replace function apply_to_opportunity(target_opportunity uuid, application_message text default '')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  applicant uuid := current_member_profile_id();
  target opportunities%rowtype;
  created applications%rowtype;
  safe_message text := left(trim(coalesce(application_message,'')),2000);
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if applicant is null then raise exception 'profile_required'; end if;
  select * into target from opportunities where id=target_opportunity;
  if target.id is null or target.visibility<>'public' or target.status<>'open' or (target.deadline is not null and target.deadline<current_date) then raise exception 'opportunity_not_open'; end if;
  if coalesce(target.created_by_profile_id,target.organization_profile_id)=applicant then raise exception 'cannot_apply_to_own_opportunity'; end if;
  if char_length(safe_message)>0 and char_length(safe_message)<10 then raise exception 'application_message_too_short'; end if;

  insert into applications(opportunity_id,applicant_profile_id,status,message,submitted_at,updated_at)
  values(target.id,applicant,'submitted',nullif(safe_message,''),now(),now())
  on conflict(opportunity_id,applicant_profile_id) do nothing
  returning * into created;
  if created.id is null then raise exception 'application_already_exists'; end if;
  return jsonb_build_object('submitted',true,'id',created.id,'status',created.status);
end;
$$;

create or replace function toggle_opportunity_bookmark(target_opportunity uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  member uuid := current_member_profile_id();
  affected integer;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if member is null then raise exception 'profile_required'; end if;
  if not exists(select 1 from opportunities where id=target_opportunity and visibility='public') then raise exception 'opportunity_not_found'; end if;
  delete from opportunity_bookmarks where opportunity_id=target_opportunity and profile_id=member;
  get diagnostics affected=row_count;
  if affected=1 then return jsonb_build_object('saved',false); end if;
  insert into opportunity_bookmarks(opportunity_id,profile_id) values(target_opportunity,member) on conflict do nothing;
  return jsonb_build_object('saved',true);
end;
$$;

create or replace function save_opportunity_alert(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  member uuid := current_member_profile_id();
  created opportunity_alerts%rowtype;
  safe_name text := left(trim(coalesce(payload->>'name','')),80);
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if member is null then raise exception 'profile_required'; end if;
  if safe_name='' then raise exception 'alert_name_required'; end if;
  if (select count(*) from opportunity_alerts where owner_profile_id=member)>=20 then raise exception 'alert_limit_reached'; end if;
  insert into opportunity_alerts(owner_profile_id,name,query_text,opportunity_type,role_code,location_query,contract_type)
  values(member,safe_name,nullif(left(trim(coalesce(payload->>'query','')),120),''),nullif(left(trim(coalesce(payload->>'opportunity_type','')),40),''),
    nullif(left(trim(coalesce(payload->>'role_code','')),80),''),nullif(left(trim(coalesce(payload->>'location','')),120),''),
    nullif(left(trim(coalesce(payload->>'contract_type','')),40),'')) returning * into created;
  return jsonb_build_object('saved',true,'id',created.id,'name',created.name);
end;
$$;

create or replace function delete_opportunity_alert(target_alert uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare member uuid:=current_member_profile_id(); affected integer;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  delete from opportunity_alerts where id=target_alert and owner_profile_id=member;
  get diagnostics affected=row_count;
  return jsonb_build_object('deleted',affected=1);
end;
$$;

create or replace function update_application_status(target_application uuid, new_status text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare recruiter uuid:=current_member_profile_id(); updated applications%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if new_status not in ('viewed','shortlisted','interview','accepted','rejected') then raise exception 'invalid_application_status'; end if;
  update applications a set status=new_status,viewed_at=case when new_status='viewed' then coalesce(a.viewed_at,now()) else a.viewed_at end,updated_at=now()
  from opportunities o where a.id=target_application and o.id=a.opportunity_id and o.created_by_profile_id=recruiter returning a.* into updated;
  if updated.id is null then raise exception 'application_not_found'; end if;
  return jsonb_build_object('updated',true,'id',updated.id,'status',updated.status);
end;
$$;

create or replace function withdraw_application(target_application uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare member uuid:=current_member_profile_id(); updated applications%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  update applications set status='withdrawn',withdrawn_at=now(),updated_at=now()
  where id=target_application and applicant_profile_id=member and status not in ('accepted','rejected','withdrawn') returning * into updated;
  if updated.id is null then raise exception 'application_not_found'; end if;
  return jsonb_build_object('withdrawn',true,'id',updated.id);
end;
$$;

create or replace function close_opportunity(target_opportunity uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare member uuid:=current_member_profile_id(); updated opportunities%rowtype;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  update opportunities set status='closed',closed_at=now(),updated_at=now()
  where id=target_opportunity and created_by_profile_id=member and status in ('open','paused') returning * into updated;
  if updated.id is null then raise exception 'opportunity_not_found'; end if;
  return jsonb_build_object('closed',true,'id',updated.id);
end;
$$;

create or replace function get_recruitment_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare member uuid:=current_member_profile_id();
begin
  if auth.uid() is null or member is null then return jsonb_build_object('applications','[]'::jsonb,'published','[]'::jsonb,'bookmarks','[]'::jsonb,'alerts','[]'::jsonb); end if;
  return jsonb_build_object(
    'applications',coalesce((select jsonb_agg(jsonb_build_object(
      'id',a.id,'status',a.status,'message',a.message,'submitted_at',a.submitted_at,
      'opportunity',jsonb_build_object('id',o.id,'title',o.title,'organization_name',o.organization_name,'location_text',o.location_text,'city',o.city,'deadline',o.deadline,'status',o.status,'opportunity_type',o.opportunity_type,'role_code',o.role_code)
    ) order by a.submitted_at desc) from applications a join opportunities o on o.id=a.opportunity_id where a.applicant_profile_id=member),'[]'::jsonb),
    'published',coalesce((select jsonb_agg(jsonb_build_object(
      'id',o.id,'title',o.title,'organization_name',o.organization_name,'status',o.status,'deadline',o.deadline,'application_count',o.application_count,'opportunity_type',o.opportunity_type,'role_code',o.role_code,
      'applicants',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'status',a.status,'message',a.message,'submitted_at',a.submitted_at,'profile',jsonb_build_object('id',p.id,'display_name',p.display_name,'slug',p.slug,'avatar_url',p.avatar_url,'headline',p.headline,'primary_role_code',p.primary_role_code,'location_text',p.location_text,'profile_completion_score',p.profile_completion_score)) order by a.submitted_at desc) from applications a join profiles p on p.id=a.applicant_profile_id where a.opportunity_id=o.id),'[]'::jsonb)
    ) order by o.published_at desc) from opportunities o where o.created_by_profile_id=member),'[]'::jsonb),
    'bookmarks',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'title',o.title,'organization_name',o.organization_name,'location_text',o.location_text,'city',o.city,'deadline',o.deadline,'status',o.status,'opportunity_type',o.opportunity_type,'role_code',o.role_code) order by b.created_at desc) from opportunity_bookmarks b join opportunities o on o.id=b.opportunity_id where b.profile_id=member),'[]'::jsonb),
    'alerts',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'name',a.name,'query',a.query_text,'opportunity_type',a.opportunity_type,'role_code',a.role_code,'location',a.location_query,'contract_type',a.contract_type,'is_enabled',a.is_enabled,'last_notified_at',a.last_notified_at) order by a.updated_at desc) from opportunity_alerts a where a.owner_profile_id=member),'[]'::jsonb)
  );
end;
$$;

create or replace function update_opportunity_application_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update opportunities set application_count=(select count(*) from applications where opportunity_id=coalesce(new.opportunity_id,old.opportunity_id) and status<>'withdrawn'),updated_at=now()
  where id=coalesce(new.opportunity_id,old.opportunity_id);
  return coalesce(new,old);
end;
$$;

drop trigger if exists opportunity_application_count_trigger on applications;
create trigger opportunity_application_count_trigger after insert or delete or update of status on applications
for each row execute function update_opportunity_application_count();

create or replace function notify_recruitment_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target opportunities%rowtype; actor_name text;
begin
  select * into target from opportunities where id=new.opportunity_id;
  if tg_op='INSERT' then
    select display_name into actor_name from profiles where id=new.applicant_profile_id;
    insert into notifications(recipient_profile_id,actor_profile_id,notification_type,entity_type,entity_id,payload)
    values(coalesce(target.created_by_profile_id,target.organization_profile_id),new.applicant_profile_id,'application_received','opportunity',target.id,jsonb_build_object('title',target.title,'actor_name',actor_name,'application_id',new.id))
    on conflict(recipient_profile_id,actor_profile_id,notification_type,entity_id) do update set payload=excluded.payload,read_at=null,created_at=now();
  elsif old.status is distinct from new.status and new.status in ('viewed','shortlisted','interview','accepted','rejected') then
    select display_name into actor_name from profiles where id=coalesce(target.created_by_profile_id,target.organization_profile_id);
    insert into notifications(recipient_profile_id,actor_profile_id,notification_type,entity_type,entity_id,payload)
    values(new.applicant_profile_id,coalesce(target.created_by_profile_id,target.organization_profile_id),'application_status','opportunity',target.id,jsonb_build_object('title',target.title,'actor_name',actor_name,'status',new.status,'application_id',new.id))
    on conflict(recipient_profile_id,actor_profile_id,notification_type,entity_id) do update set payload=excluded.payload,read_at=null,created_at=now();
  end if;
  return new;
end;
$$;

drop trigger if exists recruitment_application_notification_trigger on applications;
create trigger recruitment_application_notification_trigger after insert or update of status on applications
for each row execute function notify_recruitment_application();

create or replace function notify_matching_opportunity_alerts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status<>'open' or new.visibility<>'public' then return new; end if;
  insert into notifications(recipient_profile_id,actor_profile_id,notification_type,entity_type,entity_id,payload)
  select a.owner_profile_id,new.created_by_profile_id,'opportunity_match','opportunity',new.id,
    jsonb_build_object('title',new.title,'organization_name',new.organization_name,'alert_name',a.name)
  from opportunity_alerts a
  where a.is_enabled and a.owner_profile_id<>new.created_by_profile_id
    and (a.opportunity_type is null or a.opportunity_type=new.opportunity_type)
    and (a.role_code is null or a.role_code=new.role_code)
    and (a.contract_type is null or a.contract_type=new.contract_type)
    and (a.location_query is null or coalesce(new.city,'') ilike '%'||a.location_query||'%' or coalesce(new.location_text,'') ilike '%'||a.location_query||'%')
    and (a.query_text is null or coalesce(new.title,'') ilike '%'||a.query_text||'%' or coalesce(new.description,'') ilike '%'||a.query_text||'%' or coalesce(new.organization_name,'') ilike '%'||a.query_text||'%')
  on conflict(recipient_profile_id,actor_profile_id,notification_type,entity_id) do update set payload=excluded.payload,read_at=null,created_at=now();
  update opportunity_alerts set last_notified_at=now() where id in (
    select a.id from opportunity_alerts a where a.is_enabled and a.owner_profile_id<>new.created_by_profile_id
      and (a.opportunity_type is null or a.opportunity_type=new.opportunity_type)
      and (a.role_code is null or a.role_code=new.role_code)
      and (a.contract_type is null or a.contract_type=new.contract_type)
      and (a.location_query is null or coalesce(new.city,'') ilike '%'||a.location_query||'%' or coalesce(new.location_text,'') ilike '%'||a.location_query||'%')
      and (a.query_text is null or coalesce(new.title,'') ilike '%'||a.query_text||'%' or coalesce(new.description,'') ilike '%'||a.query_text||'%' or coalesce(new.organization_name,'') ilike '%'||a.query_text||'%')
  );
  return new;
end;
$$;

drop trigger if exists opportunity_alert_notification_trigger on opportunities;
create trigger opportunity_alert_notification_trigger after insert on opportunities
for each row execute function notify_matching_opportunity_alerts();

revoke all on function search_recruitment_opportunities(text,text,text,text,text,integer,integer) from public;
revoke all on function publish_opportunity(jsonb) from public;
revoke all on function apply_to_opportunity(uuid,text) from public;
revoke all on function toggle_opportunity_bookmark(uuid) from public;
revoke all on function save_opportunity_alert(jsonb) from public;
revoke all on function delete_opportunity_alert(uuid) from public;
revoke all on function update_application_status(uuid,text) from public;
revoke all on function withdraw_application(uuid) from public;
revoke all on function close_opportunity(uuid) from public;
revoke all on function get_recruitment_dashboard() from public;

grant execute on function search_recruitment_opportunities(text,text,text,text,text,integer,integer) to anon,authenticated;
grant execute on function publish_opportunity(jsonb) to authenticated;
grant execute on function apply_to_opportunity(uuid,text) to authenticated;
grant execute on function toggle_opportunity_bookmark(uuid) to authenticated;
grant execute on function save_opportunity_alert(jsonb) to authenticated;
grant execute on function delete_opportunity_alert(uuid) to authenticated;
grant execute on function update_application_status(uuid,text) to authenticated;
grant execute on function withdraw_application(uuid) to authenticated;
grant execute on function close_opportunity(uuid) to authenticated;
grant execute on function get_recruitment_dashboard() to authenticated;

commit;
