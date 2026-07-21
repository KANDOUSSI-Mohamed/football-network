-- Football Network - installation complete des migrations 2026-07-21.
-- Le schema initial doit deja etre present.
-- Ce fichier est genere a partir des migrations versionnees.

begin;

-- ============================================================
-- 20260721_multilingual_foundation.sql
-- ============================================================

begin;

create table if not exists supported_locales (
  code text primary key,
  native_label text not null,
  text_direction text not null default 'ltr' check (text_direction in ('ltr', 'rtl')),
  is_enabled boolean not null default true,
  sort_order integer not null default 0
);

insert into supported_locales (code, native_label, text_direction, sort_order)
values
  ('fr', 'Français', 'ltr', 10),
  ('en', 'English', 'ltr', 20),
  ('es', 'Español', 'ltr', 30),
  ('it', 'Italiano', 'ltr', 40),
  ('pt', 'Português', 'ltr', 50),
  ('de', 'Deutsch', 'ltr', 60),
  ('nl', 'Nederlands', 'ltr', 70),
  ('ar', 'العربية', 'rtl', 80),
  ('tr', 'Türkçe', 'ltr', 90)
on conflict (code) do update
set
  native_label = excluded.native_label,
  text_direction = excluded.text_direction,
  sort_order = excluded.sort_order,
  is_enabled = true;

alter table profiles
  add column if not exists preferred_locale text not null default 'fr'
  references supported_locales(code);

alter table profiles
  add column if not exists source_locale text not null default 'fr'
  references supported_locales(code);

alter table opportunities
  add column if not exists source_locale text not null default 'fr'
  references supported_locales(code);

alter table media_assets
  add column if not exists source_locale text not null default 'fr'
  references supported_locales(code);

alter table messages
  add column if not exists source_locale text not null default 'fr'
  references supported_locales(code);

create table if not exists profile_translations (
  profile_id uuid not null references profiles(id) on delete cascade,
  locale text not null references supported_locales(code),
  headline text,
  bio text,
  translation_origin text not null default 'human'
    check (translation_origin in ('human', 'machine')),
  review_status text not null default 'draft'
    check (review_status in ('draft', 'machine', 'reviewed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, locale)
);

create table if not exists opportunity_translations (
  opportunity_id uuid not null references opportunities(id) on delete cascade,
  locale text not null references supported_locales(code),
  title text not null,
  description text,
  translation_origin text not null default 'human'
    check (translation_origin in ('human', 'machine')),
  review_status text not null default 'draft'
    check (review_status in ('draft', 'machine', 'reviewed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (opportunity_id, locale)
);

create table if not exists posts (
  id uuid primary key default uuid_generate_v4(),
  author_profile_id uuid not null references profiles(id) on delete cascade,
  post_type text not null default 'update'
    check (post_type in ('update', 'media', 'statistics', 'recruitment')),
  body text,
  source_locale text not null default 'fr' references supported_locales(code),
  visibility text not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists post_translations (
  post_id uuid not null references posts(id) on delete cascade,
  locale text not null references supported_locales(code),
  body text not null,
  translation_origin text not null default 'machine'
    check (translation_origin in ('human', 'machine')),
  review_status text not null default 'machine'
    check (review_status in ('draft', 'machine', 'reviewed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (post_id, locale)
);

create table if not exists media_asset_translations (
  media_asset_id uuid not null references media_assets(id) on delete cascade,
  locale text not null references supported_locales(code),
  title text,
  description text,
  translation_origin text not null default 'human'
    check (translation_origin in ('human', 'machine')),
  review_status text not null default 'draft'
    check (review_status in ('draft', 'machine', 'reviewed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (media_asset_id, locale)
);

create table if not exists professional_roles (
  id uuid primary key default uuid_generate_v4(),
  code text not null unique,
  category text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists professional_role_translations (
  role_id uuid not null references professional_roles(id) on delete cascade,
  locale text not null references supported_locales(code),
  label text not null,
  description text,
  primary key (role_id, locale)
);

create table if not exists profile_roles (
  profile_id uuid not null references profiles(id) on delete cascade,
  role_id uuid not null references professional_roles(id),
  is_primary boolean not null default false,
  years_experience numeric(4,1),
  created_at timestamptz not null default now(),
  primary key (profile_id, role_id)
);

insert into professional_roles (code, category, sort_order)
values
  ('player', 'sporting', 10),
  ('head_coach', 'technical_staff', 20),
  ('assistant_coach', 'technical_staff', 30),
  ('fitness_coach', 'performance', 40),
  ('sports_doctor', 'medical', 50),
  ('physiotherapist', 'medical', 60),
  ('osteopath', 'medical', 70),
  ('video_analyst', 'analysis', 80),
  ('scout', 'recruitment', 90),
  ('agent', 'representation', 100),
  ('club_president', 'management', 110),
  ('general_manager', 'management', 120),
  ('marketing_manager', 'business', 130),
  ('logistics_manager', 'operations', 140),
  ('administrative_manager', 'operations', 150)
on conflict (code) do update
set
  category = excluded.category,
  sort_order = excluded.sort_order,
  is_active = true;

with role_labels (code, labels) as (
  values
    ('player', '{"fr":"Joueur","en":"Player","es":"Jugador","it":"Giocatore","pt":"Jogador","de":"Spieler","nl":"Speler","ar":"لاعب","tr":"Oyuncu"}'::jsonb),
    ('head_coach', '{"fr":"Entraîneur","en":"Head coach","es":"Entrenador","it":"Allenatore","pt":"Treinador","de":"Cheftrainer","nl":"Hoofdtrainer","ar":"مدرب","tr":"Teknik direktör"}'::jsonb),
    ('assistant_coach', '{"fr":"Entraîneur adjoint","en":"Assistant coach","es":"Segundo entrenador","it":"Vice allenatore","pt":"Treinador adjunto","de":"Co-Trainer","nl":"Assistent-trainer","ar":"مدرب مساعد","tr":"Yardımcı antrenör"}'::jsonb),
    ('fitness_coach', '{"fr":"Préparateur physique","en":"Fitness coach","es":"Preparador físico","it":"Preparatore atletico","pt":"Preparador físico","de":"Athletiktrainer","nl":"Conditietrainer","ar":"معد بدني","tr":"Kondisyoner"}'::jsonb),
    ('sports_doctor', '{"fr":"Médecin du sport","en":"Sports doctor","es":"Médico deportivo","it":"Medico sportivo","pt":"Médico desportivo","de":"Sportarzt","nl":"Sportarts","ar":"طبيب رياضي","tr":"Spor doktoru"}'::jsonb),
    ('physiotherapist', '{"fr":"Kinésithérapeute","en":"Physiotherapist","es":"Fisioterapeuta","it":"Fisioterapista","pt":"Fisioterapeuta","de":"Physiotherapeut","nl":"Fysiotherapeut","ar":"أخصائي علاج طبيعي","tr":"Fizyoterapist"}'::jsonb),
    ('osteopath', '{"fr":"Ostéopathe","en":"Osteopath","es":"Osteópata","it":"Osteopata","pt":"Osteopata","de":"Osteopath","nl":"Osteopaat","ar":"أخصائي تقويم","tr":"Osteopat"}'::jsonb),
    ('video_analyst', '{"fr":"Analyste vidéo","en":"Video analyst","es":"Analista de vídeo","it":"Video analyst","pt":"Analista de vídeo","de":"Videoanalyst","nl":"Videoanalist","ar":"محلل فيديو","tr":"Video analisti"}'::jsonb),
    ('scout', '{"fr":"Recruteur","en":"Scout","es":"Ojeador","it":"Scout","pt":"Olheiro","de":"Scout","nl":"Scout","ar":"كشاف","tr":"Gözlemci"}'::jsonb),
    ('agent', '{"fr":"Agent","en":"Agent","es":"Agente","it":"Agente","pt":"Agente","de":"Spielerberater","nl":"Makelaar","ar":"وكيل لاعبين","tr":"Menajer"}'::jsonb),
    ('club_president', '{"fr":"Président de club","en":"Club president","es":"Presidente de club","it":"Presidente del club","pt":"Presidente do clube","de":"Vereinspräsident","nl":"Clubvoorzitter","ar":"رئيس نادٍ","tr":"Kulüp başkanı"}'::jsonb),
    ('general_manager', '{"fr":"Directeur général","en":"General manager","es":"Director general","it":"Direttore generale","pt":"Diretor-geral","de":"Geschäftsführer","nl":"Algemeen directeur","ar":"مدير عام","tr":"Genel müdür"}'::jsonb),
    ('marketing_manager', '{"fr":"Responsable marketing","en":"Marketing manager","es":"Responsable de marketing","it":"Responsabile marketing","pt":"Responsável de marketing","de":"Marketingleiter","nl":"Marketingmanager","ar":"مسؤول تسويق","tr":"Pazarlama yöneticisi"}'::jsonb),
    ('logistics_manager', '{"fr":"Responsable logistique","en":"Logistics manager","es":"Responsable de logística","it":"Responsabile logistica","pt":"Responsável de logística","de":"Logistikleiter","nl":"Logistiek manager","ar":"مسؤول لوجستيك","tr":"Lojistik yöneticisi"}'::jsonb),
    ('administrative_manager', '{"fr":"Responsable administratif","en":"Administrative manager","es":"Responsable administrativo","it":"Responsabile amministrativo","pt":"Responsável administrativo","de":"Verwaltungsleiter","nl":"Administratief manager","ar":"مسؤول إداري","tr":"İdari yönetici"}'::jsonb)
)
insert into professional_role_translations (role_id, locale, label)
select roles.id, labels.key, labels.value
from role_labels
join professional_roles roles on roles.code = role_labels.code
cross join lateral jsonb_each_text(role_labels.labels) labels
on conflict (role_id, locale) do update
set label = excluded.label;

create index if not exists idx_profiles_preferred_locale
  on profiles(preferred_locale);

create index if not exists idx_opportunities_source_locale
  on opportunities(source_locale);

create index if not exists idx_posts_author_created
  on posts(author_profile_id, created_at desc);

create index if not exists idx_posts_source_locale
  on posts(source_locale);

create index if not exists idx_profile_roles_role
  on profile_roles(role_id);

commit;


-- ============================================================
-- 20260721_network_core.sql
-- ============================================================

-- Football Network: protected contacts, plan entitlements and JustRate API link metadata.
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
  last_api_check_at timestamptz,
  api_status text not null default 'not_checked' check (api_status in ('not_checked', 'ready', 'checking', 'available', 'error')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists justrate_api_events (
  id uuid primary key default uuid_generate_v4(),
  link_id uuid not null references justrate_profile_links(id) on delete cascade,
  status text not null check (status in ('started', 'completed', 'failed')),
  remote_version text,
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

create index if not exists idx_justrate_api_link_created
  on justrate_api_events(link_id, created_at desc);

alter table profile_contact_settings enable row level security;
alter table profile_contacts enable row level security;
alter table contact_access_events enable row level security;
alter table justrate_profile_links enable row level security;
alter table justrate_api_events enable row level security;
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

drop policy if exists "JustRate API events are readable" on justrate_api_events;
create policy "JustRate API events are readable"
  on justrate_api_events for select
  using (exists (
    select 1 from justrate_profile_links link
    where link.id = justrate_api_events.link_id
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


-- ============================================================
-- 20260721_member_onboarding.sql
-- ============================================================

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

  if not exists (select 1 from supported_locales sl where sl.code = safe_locale and sl.is_active) then
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

commit;
