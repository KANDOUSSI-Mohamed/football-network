-- Football Network: worldwide club directory, follows and secure claims.
-- Additive and idempotent. Initial public imports are intentionally unclaimed.

begin;

alter table clubs
  add column if not exists club_type text not null default 'professional',
  add column if not exists description text,
  add column if not exists address text,
  add column if not exists public_email text,
  add column if not exists public_phone text,
  add column if not exists linkedin_url text,
  add column if not exists instagram_url text,
  add column if not exists x_url text,
  add column if not exists followers_count integer not null default 0,
  add column if not exists featured boolean not null default false,
  add column if not exists source_locale text not null default 'fr';

alter table claims
  add column if not exists claimant_profile_id uuid references profiles(id) on delete cascade,
  add column if not exists organization_role text,
  add column if not exists contact_email text,
  add column if not exists evidence jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

alter table clubs drop constraint if exists clubs_profile_id_fkey;
alter table clubs add constraint clubs_profile_id_fkey
  foreign key (profile_id) references profiles(id) on delete cascade;

alter table claims drop constraint if exists claims_target_profile_id_fkey;
alter table claims add constraint claims_target_profile_id_fkey
  foreign key (target_profile_id) references profiles(id) on delete cascade;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid='clubs'::regclass and conname='clubs_type_check') then
    alter table clubs add constraint clubs_type_check
      check (club_type in ('professional','semi_professional','amateur','academy','women','futsal','other'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid='clubs'::regclass and conname='clubs_claim_status_check') then
    alter table clubs add constraint clubs_claim_status_check
      check (claim_status in ('unclaimed','pending','claimed','disputed'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid='claims'::regclass and conname='claims_marketplace_status_check') then
    alter table claims add constraint claims_marketplace_status_check
      check (status in ('submitted','reviewing','approved','rejected','withdrawn'));
  end if;
end;
$$;

create unique index if not exists idx_clubs_profile_unique on clubs(profile_id) where profile_id is not null;
create index if not exists idx_clubs_directory_search on clubs(country_id,club_type,claim_status,official_name);
create index if not exists idx_clubs_featured on clubs(featured desc,followers_count desc);
create index if not exists idx_claims_claimant_profile on claims(claimant_profile_id,submitted_at desc);
create unique index if not exists idx_claims_active_club_claimant
  on claims(target_profile_id,claimant_user_id)
  where status in ('submitted','reviewing');

create table if not exists club_follows (
  club_id uuid not null references clubs(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (club_id,profile_id)
);

create index if not exists idx_club_follows_profile on club_follows(profile_id,created_at desc);

alter table clubs enable row level security;
alter table claims enable row level security;
alter table club_follows enable row level security;

drop policy if exists "Public clubs are readable" on clubs;
create policy "Public clubs are readable" on clubs for select using (true);

drop policy if exists "Members read their club claims" on claims;
create policy "Members read their club claims" on claims for select to authenticated
  using (claimant_user_id=auth.uid() or claimant_profile_id=current_member_profile_id());

drop policy if exists "Members submit club claims" on claims;
create policy "Members submit club claims" on claims for insert to authenticated
  with check (claimant_user_id=auth.uid() and claimant_profile_id=current_member_profile_id());

drop policy if exists "Members manage club follows" on club_follows;
create policy "Members manage club follows" on club_follows for all to authenticated
  using (profile_id=current_member_profile_id())
  with check (profile_id=current_member_profile_id());

grant select on clubs to anon,authenticated;
revoke insert,update,delete on claims from anon,authenticated;
grant select on claims to authenticated;
grant select,insert,delete on club_follows to authenticated;

create or replace function search_clubs(
  p_query text default '',
  p_country text default '',
  p_club_type text default '',
  p_claim_status text default '',
  p_followed_only boolean default false,
  p_limit integer default 24,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  viewer uuid:=current_member_profile_id();
  safe_query text:=left(trim(coalesce(p_query,'')),120);
  safe_country text:=upper(left(trim(coalesce(p_country,'')),80));
  safe_type text:=left(trim(coalesce(p_club_type,'')),40);
  safe_claim text:=left(trim(coalesce(p_claim_status,'')),40);
  safe_limit integer:=greatest(1,least(coalesce(p_limit,24),60));
  safe_offset integer:=greatest(0,least(coalesce(p_offset,0),5000));
  result jsonb;
begin
  with matching as (
    select
      c.id,c.profile_id,c.official_name,c.short_name,c.slug,c.city,c.region,c.founded_year,c.website_url,c.logo_url,
      c.colors,c.club_status,c.club_type,c.description,c.data_quality,c.claim_status,c.verification_status,c.followers_count,
      c.featured,co.name as country_name,co.iso2 as country_code,p.avatar_url,p.cover_url,
      exists(select 1 from club_follows f where f.club_id=c.id and f.profile_id=viewer) as followed,
      (select count(*)::integer from opportunities o where o.organization_profile_id=c.profile_id and o.status='open' and o.visibility='public' and (o.deadline is null or o.deadline>=current_date)) as open_opportunities
    from clubs c
    join profiles p on p.id=c.profile_id
    left join countries co on co.id=c.country_id
    where p.visibility='public'
      and (safe_query='' or c.official_name ilike '%'||safe_query||'%' or coalesce(c.short_name,'') ilike '%'||safe_query||'%' or coalesce(c.city,'') ilike '%'||safe_query||'%' or coalesce(c.region,'') ilike '%'||safe_query||'%')
      and (safe_country='' or upper(coalesce(co.iso2,''))=safe_country or upper(coalesce(co.name,''))=safe_country)
      and (safe_type='' or c.club_type=safe_type)
      and (safe_claim='' or c.claim_status=safe_claim)
      and (not coalesce(p_followed_only,false) or exists(select 1 from club_follows f where f.club_id=c.id and f.profile_id=viewer))
  ), counted as (select count(*)::integer total from matching), paged as (
    select * from matching order by featured desc,followers_count desc,official_name limit safe_limit offset safe_offset
  )
  select jsonb_build_object(
    'total',counted.total,
    'results',coalesce((select jsonb_agg(to_jsonb(paged) order by featured desc,followers_count desc,official_name) from paged),'[]'::jsonb)
  ) into result from counted;
  return coalesce(result,jsonb_build_object('total',0,'results','[]'::jsonb));
end;
$$;

create or replace function get_club_detail(target_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare viewer uuid:=current_member_profile_id(); result jsonb;
begin
  select jsonb_build_object(
    'id',c.id,'profile_id',c.profile_id,'official_name',c.official_name,'short_name',c.short_name,'slug',c.slug,
    'city',c.city,'region',c.region,'founded_year',c.founded_year,'website_url',c.website_url,'logo_url',c.logo_url,
    'colors',c.colors,'club_status',c.club_status,'club_type',c.club_type,'description',c.description,'address',c.address,
    'public_email',case when c.claim_status='claimed' then c.public_email else null end,
    'public_phone',case when c.claim_status='claimed' then c.public_phone else null end,
    'linkedin_url',c.linkedin_url,'instagram_url',c.instagram_url,'x_url',c.x_url,'data_quality',c.data_quality,
    'claim_status',c.claim_status,'verification_status',c.verification_status,'followers_count',c.followers_count,
    'country_name',co.name,'country_code',co.iso2,'avatar_url',p.avatar_url,'cover_url',p.cover_url,
    'followed',exists(select 1 from club_follows f where f.club_id=c.id and f.profile_id=viewer),
    'open_opportunities',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'title',o.title,'opportunity_type',o.opportunity_type,'role_code',o.role_code,'city',o.city,'location_text',o.location_text,'contract_type',o.contract_type,'deadline',o.deadline) order by o.published_at desc) from opportunities o where o.organization_profile_id=c.profile_id and o.status='open' and o.visibility='public' and (o.deadline is null or o.deadline>=current_date)),'[]'::jsonb)
  ) into result
  from clubs c join profiles p on p.id=c.profile_id left join countries co on co.id=c.country_id
  where c.slug=left(trim(coalesce(target_slug,'')),160) and p.visibility='public';
  if result is null then raise exception 'club_not_found'; end if;
  return result;
end;
$$;

create or replace function toggle_club_follow(target_club uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare member uuid:=current_member_profile_id(); affected integer;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if member is null then raise exception 'profile_required'; end if;
  if not exists(select 1 from clubs where id=target_club) then raise exception 'club_not_found'; end if;
  delete from club_follows where club_id=target_club and profile_id=member;
  get diagnostics affected=row_count;
  if affected=1 then return jsonb_build_object('followed',false); end if;
  insert into club_follows(club_id,profile_id) values(target_club,member) on conflict do nothing;
  return jsonb_build_object('followed',true);
end;
$$;

create or replace function submit_club_claim(target_club uuid,payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  member uuid:=current_member_profile_id();
  target clubs%rowtype;
  created claims%rowtype;
  safe_role text:=left(trim(coalesce(payload->>'organization_role','')),100);
  safe_email text:=lower(left(trim(coalesce(payload->>'contact_email','')),180));
  safe_message text:=left(trim(coalesce(payload->>'message','')),2500);
  proof_url text:=left(trim(coalesce(payload->>'proof_url','')),500);
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if member is null then raise exception 'profile_required'; end if;
  select * into target from clubs where id=target_club;
  if target.id is null then raise exception 'club_not_found'; end if;
  if target.claim_status='claimed' then raise exception 'club_already_claimed'; end if;
  if char_length(safe_role)<2 then raise exception 'organization_role_required'; end if;
  if safe_email!~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then raise exception 'valid_contact_email_required'; end if;
  if char_length(safe_message)<20 then raise exception 'claim_message_too_short'; end if;
  if proof_url<>'' and proof_url!~* '^https?://' then raise exception 'invalid_proof_url'; end if;
  insert into claims(claimant_user_id,claimant_profile_id,target_profile_id,claim_type,status,message,organization_role,contact_email,evidence,submitted_at,updated_at)
  values(auth.uid(),member,target.profile_id,'club_ownership','submitted',safe_message,safe_role,safe_email,jsonb_build_object('proof_url',nullif(proof_url,'')),now(),now())
  returning * into created;
  update clubs set claim_status='pending',updated_at=now() where id=target.id and claim_status='unclaimed';
  update profiles set claim_status='pending',updated_at=now() where id=target.profile_id and claim_status='unclaimed';
  return jsonb_build_object('submitted',true,'id',created.id,'status',created.status);
exception when unique_violation then
  raise exception 'claim_already_submitted';
end;
$$;

create or replace function get_my_club_claims()
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',cl.id,'status',cl.status,'message',cl.message,'organization_role',cl.organization_role,'submitted_at',cl.submitted_at,
    'club',jsonb_build_object('id',c.id,'official_name',c.official_name,'slug',c.slug,'city',c.city,'claim_status',c.claim_status,'country_name',co.name)
  ) order by cl.submitted_at desc),'[]'::jsonb)
  from claims cl join clubs c on c.profile_id=cl.target_profile_id left join countries co on co.id=c.country_id
  where cl.claimant_user_id=auth.uid() and cl.claim_type='club_ownership';
$$;

create or replace function withdraw_club_claim(target_claim uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare updated claims%rowtype; target_profile uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  update claims set status='withdrawn',updated_at=now()
  where id=target_claim and claimant_user_id=auth.uid() and status in ('submitted','reviewing')
  returning * into updated;
  if updated.id is null then raise exception 'claim_not_found'; end if;
  target_profile:=updated.target_profile_id;
  if not exists(select 1 from claims where target_profile_id=target_profile and status in ('submitted','reviewing','approved')) then
    update clubs set claim_status='unclaimed',updated_at=now() where profile_id=target_profile and claim_status='pending';
    update profiles set claim_status='unclaimed',updated_at=now() where id=target_profile and claim_status='pending';
  end if;
  return jsonb_build_object('withdrawn',true,'id',updated.id);
end;
$$;

create or replace function update_club_follower_count()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare target_id uuid:=coalesce(new.club_id,old.club_id);
begin
  update clubs set followers_count=(select count(*) from club_follows where club_id=target_id),updated_at=now() where id=target_id;
  return coalesce(new,old);
end;
$$;

drop trigger if exists club_follower_count_trigger on club_follows;
create trigger club_follower_count_trigger after insert or delete on club_follows
for each row execute function update_club_follower_count();

revoke all on function search_clubs(text,text,text,text,boolean,integer,integer) from public;
revoke all on function get_club_detail(text) from public;
revoke all on function toggle_club_follow(uuid) from public;
revoke all on function submit_club_claim(uuid,jsonb) from public;
revoke all on function get_my_club_claims() from public;
revoke all on function withdraw_club_claim(uuid) from public;
grant execute on function search_clubs(text,text,text,text,boolean,integer,integer) to anon,authenticated;
grant execute on function get_club_detail(text) to anon,authenticated;
grant execute on function toggle_club_follow(uuid) to authenticated;
grant execute on function submit_club_claim(uuid,jsonb) to authenticated;
grant execute on function get_my_club_claims() to authenticated;
grant execute on function withdraw_club_claim(uuid) to authenticated;

with seed(country_code,official_name,short_name,slug,city,club_type,source_url) as (values
  ('FR','Paris Saint-Germain','PSG','paris-saint-germain','Paris','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Olympique de Marseille','OM','olympique-de-marseille','Marseille','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Olympique Lyonnais','OL','olympique-lyonnais','Lyon','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','AS Monaco','ASM','as-monaco','Monaco','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','LOSC Lille','LOSC','losc-lille','Lille','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','RC Lens','RCL','rc-lens','Lens','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Stade Rennais FC','SRFC','stade-rennais-fc','Rennes','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','RC Strasbourg Alsace','RCSA','rc-strasbourg-alsace','Strasbourg','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','OGC Nice','OGCN','ogc-nice','Nice','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Toulouse FC','TFC','toulouse-fc','Toulouse','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Stade Brestois 29','SB29','stade-brestois-29','Brest','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','AJ Auxerre','AJA','aj-auxerre','Auxerre','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Le Havre AC','HAC','le-havre-ac','Le Havre','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','FC Lorient','FCL','fc-lorient','Lorient','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Paris FC','PFC','paris-fc','Paris','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Angers SCO','SCO','angers-sco','Angers','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','ESTAC Troyes','ESTAC','estac-troyes','Troyes','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Le Mans FC','LMFC','le-mans-fc','Le Mans','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('MA','Association Sportive des FAR','AS FAR','as-far-rabat','Rabat','professional','https://frmf.ma'),
  ('MA','Wydad Athletic Club','WAC','wydad-athletic-club','Casablanca','professional','https://frmf.ma'),
  ('MA','Raja Club Athletic','RCA','raja-club-athletic','Casablanca','professional','https://frmf.ma'),
  ('MA','Renaissance Sportive de Berkane','RSB','rs-berkane','Berkane','professional','https://frmf.ma'),
  ('MA','Fath Union Sport','FUS','fath-union-sport','Rabat','professional','https://frmf.ma'),
  ('MA','Maghreb Association Sportive de Fès','MAS','maghreb-de-fes','Fès','professional','https://frmf.ma'),
  ('MA','Moghreb Athletic de Tétouan','MAT','moghreb-de-tetouan','Tétouan','professional','https://frmf.ma'),
  ('MA','Hassania Union Sport d’Agadir','HUSA','hassania-agadir','Agadir','professional','https://frmf.ma'),
  ('MA','Ittihad Riadhi de Tanger','IRT','ittihad-tanger','Tanger','professional','https://frmf.ma'),
  ('MA','Olympique Club de Safi','OCS','olympique-safi','Safi','professional','https://frmf.ma'),
  ('MA','Difaâ Hassani d’El Jadida','DHJ','difaa-el-jadida','El Jadida','professional','https://frmf.ma'),
  ('MA','Club Omnisports de Meknès','CODM','codm-meknes','Meknès','professional','https://frmf.ma'),
  ('MA','Renaissance Club Athletic Zemamra','RCAZ','renaissance-zemamra','Zemamra','professional','https://frmf.ma'),
  ('MA','Union Touarga Sportif','UTS','union-touarga-sportif','Rabat','professional','https://frmf.ma'),
  ('MA','Jeunesse Sportive Soualem','JSS','jeunesse-soualem','Soualem','professional','https://frmf.ma'),
  ('MA','Olympique Club de Khouribga','OCK','olympique-khouribga','Khouribga','professional','https://frmf.ma'),
  ('MA','Mouloudia Club d’Oujda','MCO','mouloudia-oujda','Oujda','professional','https://frmf.ma'),
  ('MA','Kénitra Athletic Club','KAC','kenitra-athletic-club','Kénitra','professional','https://frmf.ma'),
  ('MA','Kawkab Athlétique Club de Marrakech','KACM','kawkab-marrakech','Marrakech','professional','https://frmf.ma'),
  ('MA','Chabab Mohammédia','SCCM','chabab-mohammedia','Mohammédia','professional','https://frmf.ma'),
  ('MA','Racing Athletic Club Casablanca','RAC','racing-casablanca','Casablanca','professional','https://frmf.ma'),
  ('MA','Stade Marocain','SM','stade-marocain','Rabat','professional','https://frmf.ma'),
  ('MA','Chabab Atlas Khénifra','CAK','chabab-atlas-khenifra','Khénifra','professional','https://frmf.ma'),
  ('MA','Club Athletic Youssoufia Berrechid','CAYB','youssoufia-berrechid','Berrechid','professional','https://frmf.ma')
)
insert into profiles(profile_type,display_name,slug,country_id,city,visibility,verification_status,claim_status,preferred_locale,source_locale,location_text)
select 'club',s.official_name,s.slug,co.id,s.city,'public','public_import','unclaimed','fr','fr',s.city||', '||co.name
from seed s join countries co on co.iso2=s.country_code
on conflict(slug) do nothing;

with seed(country_code,official_name,short_name,slug,city,club_type,source_url) as (values
  ('FR','Paris Saint-Germain','PSG','paris-saint-germain','Paris','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Olympique de Marseille','OM','olympique-de-marseille','Marseille','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Olympique Lyonnais','OL','olympique-lyonnais','Lyon','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','AS Monaco','ASM','as-monaco','Monaco','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','LOSC Lille','LOSC','losc-lille','Lille','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','RC Lens','RCL','rc-lens','Lens','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Stade Rennais FC','SRFC','stade-rennais-fc','Rennes','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','RC Strasbourg Alsace','RCSA','rc-strasbourg-alsace','Strasbourg','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','OGC Nice','OGCN','ogc-nice','Nice','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Toulouse FC','TFC','toulouse-fc','Toulouse','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Stade Brestois 29','SB29','stade-brestois-29','Brest','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','AJ Auxerre','AJA','aj-auxerre','Auxerre','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Le Havre AC','HAC','le-havre-ac','Le Havre','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','FC Lorient','FCL','fc-lorient','Lorient','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Paris FC','PFC','paris-fc','Paris','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Angers SCO','SCO','angers-sco','Angers','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','ESTAC Troyes','ESTAC','estac-troyes','Troyes','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('FR','Le Mans FC','LMFC','le-mans-fc','Le Mans','professional','https://ligue1.com/fr/articles/l1_article_5293-les-dates-de-reprise-des-clubs-de-l1-2627'),
  ('MA','Association Sportive des FAR','AS FAR','as-far-rabat','Rabat','professional','https://frmf.ma'),
  ('MA','Wydad Athletic Club','WAC','wydad-athletic-club','Casablanca','professional','https://frmf.ma'),
  ('MA','Raja Club Athletic','RCA','raja-club-athletic','Casablanca','professional','https://frmf.ma'),
  ('MA','Renaissance Sportive de Berkane','RSB','rs-berkane','Berkane','professional','https://frmf.ma'),
  ('MA','Fath Union Sport','FUS','fath-union-sport','Rabat','professional','https://frmf.ma'),
  ('MA','Maghreb Association Sportive de Fès','MAS','maghreb-de-fes','Fès','professional','https://frmf.ma'),
  ('MA','Moghreb Athletic de Tétouan','MAT','moghreb-de-tetouan','Tétouan','professional','https://frmf.ma'),
  ('MA','Hassania Union Sport d’Agadir','HUSA','hassania-agadir','Agadir','professional','https://frmf.ma'),
  ('MA','Ittihad Riadhi de Tanger','IRT','ittihad-tanger','Tanger','professional','https://frmf.ma'),
  ('MA','Olympique Club de Safi','OCS','olympique-safi','Safi','professional','https://frmf.ma'),
  ('MA','Difaâ Hassani d’El Jadida','DHJ','difaa-el-jadida','El Jadida','professional','https://frmf.ma'),
  ('MA','Club Omnisports de Meknès','CODM','codm-meknes','Meknès','professional','https://frmf.ma'),
  ('MA','Renaissance Club Athletic Zemamra','RCAZ','renaissance-zemamra','Zemamra','professional','https://frmf.ma'),
  ('MA','Union Touarga Sportif','UTS','union-touarga-sportif','Rabat','professional','https://frmf.ma'),
  ('MA','Jeunesse Sportive Soualem','JSS','jeunesse-soualem','Soualem','professional','https://frmf.ma'),
  ('MA','Olympique Club de Khouribga','OCK','olympique-khouribga','Khouribga','professional','https://frmf.ma'),
  ('MA','Mouloudia Club d’Oujda','MCO','mouloudia-oujda','Oujda','professional','https://frmf.ma'),
  ('MA','Kénitra Athletic Club','KAC','kenitra-athletic-club','Kénitra','professional','https://frmf.ma'),
  ('MA','Kawkab Athlétique Club de Marrakech','KACM','kawkab-marrakech','Marrakech','professional','https://frmf.ma'),
  ('MA','Chabab Mohammédia','SCCM','chabab-mohammedia','Mohammédia','professional','https://frmf.ma'),
  ('MA','Racing Athletic Club Casablanca','RAC','racing-casablanca','Casablanca','professional','https://frmf.ma'),
  ('MA','Stade Marocain','SM','stade-marocain','Rabat','professional','https://frmf.ma'),
  ('MA','Chabab Atlas Khénifra','CAK','chabab-atlas-khenifra','Khénifra','professional','https://frmf.ma'),
  ('MA','Club Athletic Youssoufia Berrechid','CAYB','youssoufia-berrechid','Berrechid','professional','https://frmf.ma')
)
insert into clubs(profile_id,country_id,official_name,short_name,slug,city,club_type,club_status,source_url,data_quality,claim_status,verification_status,source_locale)
select p.id,co.id,s.official_name,s.short_name,s.slug,s.city,s.club_type,'active',s.source_url,'public_seed','unclaimed','public_import','fr'
from seed s join countries co on co.iso2=s.country_code join profiles p on p.slug=s.slug and p.profile_type='club'
on conflict(slug) do update set
  profile_id=excluded.profile_id,country_id=excluded.country_id,official_name=excluded.official_name,short_name=excluded.short_name,
  city=excluded.city,source_url=excluded.source_url,updated_at=now()
where clubs.claim_status='unclaimed';

commit;
