-- Football Network: current database migrations.
-- Le schema initial doit deja etre present.
-- Ce fichier est genere a partir des migrations versionnees.
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

-- ============================================================
-- 20260721_reference_access.sql
-- ============================================================

-- Football Network: public read access for active reference data.

begin;

alter table supported_locales enable row level security;

drop policy if exists "Active locales are readable" on supported_locales;
create policy "Active locales are readable"
  on supported_locales for select
  using (is_enabled);

grant select on supported_locales to anon, authenticated;

commit;

-- ============================================================
-- 20260722_realtime_messaging.sql
-- ============================================================

-- Football Network: secure direct messaging between accepted connections.

begin;

alter table conversations
  add column if not exists direct_key text;

create unique index if not exists idx_conversations_direct_key
  on conversations(direct_key)
  where direct_key is not null;

create unique index if not exists idx_conversation_participants_unique
  on conversation_participants(conversation_id, profile_id);

create index if not exists idx_conversation_participants_profile
  on conversation_participants(profile_id, conversation_id);

create index if not exists idx_messages_conversation_created
  on messages(conversation_id, created_at desc);

alter table conversations enable row level security;
alter table conversation_participants enable row level security;
alter table messages enable row level security;

create or replace function current_member_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from profiles p
  where p.user_id = auth.uid()
    and p.profile_type = 'person'
  order by p.created_at
  limit 1;
$$;

create or replace function is_conversation_participant(target_conversation uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from conversation_participants cp
    where cp.conversation_id = target_conversation
      and cp.profile_id = current_member_profile_id()
  );
$$;

drop policy if exists "Conversation members can read" on conversations;
create policy "Conversation members can read"
  on conversations for select
  using (is_conversation_participant(id));

drop policy if exists "Conversation members can read participants" on conversation_participants;
create policy "Conversation members can read participants"
  on conversation_participants for select
  using (is_conversation_participant(conversation_id));

drop policy if exists "Conversation members can read messages" on messages;
create policy "Conversation members can read messages"
  on messages for select
  using (deleted_at is null and is_conversation_participant(conversation_id));

grant select on conversations to authenticated;
grant select on conversation_participants to authenticated;
grant select on messages to authenticated;

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

  if not exists (
    select 1 from profiles p
    where p.id = target_profile
      and p.profile_type = 'person'
      and p.visibility = 'public'
  ) then
    return jsonb_build_object('created', false, 'reason', 'profile_not_found');
  end if;

  if not exists (
    select 1 from connections c
    where c.status = 'accepted'
      and (
        (c.requester_profile_id = requester_profile and c.receiver_profile_id = target_profile)
        or (c.requester_profile_id = target_profile and c.receiver_profile_id = requester_profile)
      )
  ) then
    return jsonb_build_object('created', false, 'reason', 'accepted_connection_required');
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
    select 1 from conversation_participants cp
    where cp.conversation_id = target_conversation
      and cp.profile_id = sender_profile
  ) then
    return jsonb_build_object('sent', false, 'reason', 'conversation_not_found');
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

create or replace function mark_conversation_read(target_conversation uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  reader_profile uuid := current_member_profile_id();
  affected integer := 0;
begin
  if reader_profile is null then
    return jsonb_build_object('updated', false, 'reason', 'profile_required');
  end if;

  update conversation_participants
  set last_read_at = now()
  where conversation_id = target_conversation
    and profile_id = reader_profile;

  get diagnostics affected = row_count;

  return jsonb_build_object(
    'updated', affected > 0,
    'reason', case when affected > 0 then 'read' else 'conversation_not_found' end
  );
end;
$$;

revoke all on function current_member_profile_id() from public;
revoke all on function is_conversation_participant(uuid) from public;
revoke all on function start_direct_conversation(uuid) from public;
revoke all on function send_direct_message(uuid, text) from public;
revoke all on function mark_conversation_read(uuid) from public;

grant execute on function current_member_profile_id() to authenticated;
grant execute on function is_conversation_participant(uuid) to authenticated;
grant execute on function start_direct_conversation(uuid) to authenticated;
grant execute on function send_direct_message(uuid, text) to authenticated;
grant execute on function mark_conversation_read(uuid) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'messages'
    ) then
    alter publication supabase_realtime add table messages;
  end if;
end;
$$;

commit;

-- ============================================================
-- 20260722_social_feed.sql
-- ============================================================

-- Football Network: secure social feed, media, comments, reactions and notifications.

begin;

alter table posts
  add column if not exists media_url text,
  add column if not exists media_kind text,
  add column if not exists statistics jsonb not null default '{}'::jsonb,
  add column if not exists reaction_count integer not null default 0,
  add column if not exists comment_count integer not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'posts'::regclass
      and conname = 'posts_media_kind_check'
  ) then
    alter table posts
      add constraint posts_media_kind_check
      check (media_kind is null or media_kind in ('image', 'video'));
  end if;
end;
$$;

create table if not exists post_comments (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid not null references posts(id) on delete cascade,
  author_profile_id uuid not null references profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists post_reactions (
  post_id uuid not null references posts(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  reaction_type text not null default 'support'
    check (reaction_type in ('support')),
  created_at timestamptz not null default now(),
  primary key (post_id, profile_id, reaction_type)
);

create table if not exists notifications (
  id uuid primary key default uuid_generate_v4(),
  recipient_profile_id uuid not null references profiles(id) on delete cascade,
  actor_profile_id uuid references profiles(id) on delete cascade,
  notification_type text not null
    check (notification_type in ('post_reaction', 'post_comment')),
  entity_type text not null,
  entity_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (recipient_profile_id, actor_profile_id, notification_type, entity_id)
);

create index if not exists idx_posts_public_created
  on posts(created_at desc)
  where deleted_at is null and visibility = 'public';

create index if not exists idx_post_comments_post_created
  on post_comments(post_id, created_at)
  where deleted_at is null;

create index if not exists idx_post_reactions_profile
  on post_reactions(profile_id, created_at desc);

create index if not exists idx_notifications_recipient_created
  on notifications(recipient_profile_id, created_at desc);

alter table posts enable row level security;
alter table post_translations enable row level security;
alter table post_comments enable row level security;
alter table post_reactions enable row level security;
alter table notifications enable row level security;

drop policy if exists "Public posts are readable" on posts;
create policy "Public posts are readable"
  on posts for select
  using (
    (visibility = 'public' and deleted_at is null)
    or author_profile_id = current_member_profile_id()
  );

drop policy if exists "Members own their posts" on posts;
create policy "Members own their posts"
  on posts for all
  using (author_profile_id = current_member_profile_id())
  with check (author_profile_id = current_member_profile_id());

drop policy if exists "Public post translations are readable" on post_translations;
create policy "Public post translations are readable"
  on post_translations for select
  using (exists (
    select 1 from posts p
    where p.id = post_translations.post_id
      and p.visibility = 'public'
      and p.deleted_at is null
  ));

drop policy if exists "Public comments are readable" on post_comments;
create policy "Public comments are readable"
  on post_comments for select
  using (
    deleted_at is null
    and exists (
      select 1 from posts p
      where p.id = post_comments.post_id
        and p.visibility = 'public'
        and p.deleted_at is null
    )
  );

drop policy if exists "Members own their comments" on post_comments;
create policy "Members own their comments"
  on post_comments for all
  using (author_profile_id = current_member_profile_id())
  with check (author_profile_id = current_member_profile_id());

drop policy if exists "Members read their reactions" on post_reactions;
create policy "Members read their reactions"
  on post_reactions for select
  using (profile_id = current_member_profile_id());

drop policy if exists "Members own their reactions" on post_reactions;
create policy "Members own their reactions"
  on post_reactions for all
  using (profile_id = current_member_profile_id())
  with check (profile_id = current_member_profile_id());

drop policy if exists "Members read their notifications" on notifications;
create policy "Members read their notifications"
  on notifications for select
  using (recipient_profile_id = current_member_profile_id());

drop policy if exists "Members update their notifications" on notifications;
create policy "Members update their notifications"
  on notifications for update
  using (recipient_profile_id = current_member_profile_id())
  with check (recipient_profile_id = current_member_profile_id());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'post-media',
  'post-media',
  true,
  52428800,
  array['image/jpeg','image/png','image/webp','video/mp4','video/webm']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public post media is readable" on storage.objects;
create policy "Public post media is readable"
  on storage.objects for select
  using (bucket_id = 'post-media');

drop policy if exists "Members upload their post media" on storage.objects;
create policy "Members upload their post media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = current_member_profile_id()::text
  );

drop policy if exists "Members update their post media" on storage.objects;
create policy "Members update their post media"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = current_member_profile_id()::text
  )
  with check (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = current_member_profile_id()::text
  );

drop policy if exists "Members delete their post media" on storage.objects;
create policy "Members delete their post media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = current_member_profile_id()::text
  );

create or replace function update_post_reaction_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update posts set reaction_count = reaction_count + 1 where id = new.post_id;
    return new;
  end if;

  update posts set reaction_count = greatest(0, reaction_count - 1) where id = old.post_id;
  return old;
end;
$$;

drop trigger if exists post_reaction_count_trigger on post_reactions;
create trigger post_reaction_count_trigger
after insert or delete on post_reactions
for each row execute function update_post_reaction_count();

create or replace function update_post_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update posts set comment_count = comment_count + 1 where id = new.post_id;
    return new;
  end if;

  update posts set comment_count = greatest(0, comment_count - 1) where id = old.post_id;
  return old;
end;
$$;

drop trigger if exists post_comment_count_trigger on post_comments;
create trigger post_comment_count_trigger
after insert or delete on post_comments
for each row execute function update_post_comment_count();

create or replace function notify_post_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient uuid;
begin
  select p.author_profile_id into recipient
  from posts p
  where p.id = coalesce(new.post_id, old.post_id);

  if recipient is null or recipient = coalesce(new.profile_id, old.profile_id) then
    if tg_op = 'INSERT' then
      return new;
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    insert into notifications (
      recipient_profile_id,
      actor_profile_id,
      notification_type,
      entity_type,
      entity_id,
      payload,
      read_at,
      created_at
    ) values (
      recipient,
      new.profile_id,
      'post_reaction',
      'post',
      new.post_id,
      jsonb_build_object('post_id', new.post_id),
      null,
      now()
    )
    on conflict (recipient_profile_id, actor_profile_id, notification_type, entity_id)
    do update set read_at = null, created_at = now();
    return new;
  end if;

  delete from notifications n
  where n.recipient_profile_id = recipient
    and n.actor_profile_id = old.profile_id
    and n.notification_type = 'post_reaction'
    and n.entity_id = old.post_id;
  return old;
end;
$$;

drop trigger if exists post_reaction_notification_trigger on post_reactions;
create trigger post_reaction_notification_trigger
after insert or delete on post_reactions
for each row execute function notify_post_reaction();

create or replace function notify_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient uuid;
begin
  select p.author_profile_id into recipient
  from posts p
  where p.id = new.post_id;

  if recipient is not null and recipient <> new.author_profile_id then
    insert into notifications (
      recipient_profile_id,
      actor_profile_id,
      notification_type,
      entity_type,
      entity_id,
      payload
    ) values (
      recipient,
      new.author_profile_id,
      'post_comment',
      'comment',
      new.id,
      jsonb_build_object('post_id', new.post_id)
    )
    on conflict (recipient_profile_id, actor_profile_id, notification_type, entity_id)
    do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists post_comment_notification_trigger on post_comments;
create trigger post_comment_notification_trigger
after insert on post_comments
for each row execute function notify_post_comment();

create or replace function create_feed_post(
  p_body text,
  p_post_type text default 'update',
  p_source_locale text default 'fr',
  p_media_url text default null,
  p_media_kind text default null,
  p_statistics jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  author_id uuid := current_member_profile_id();
  safe_body text := trim(coalesce(p_body, ''));
  safe_type text := lower(trim(coalesce(p_post_type, 'update')));
  safe_locale text := lower(trim(coalesce(p_source_locale, 'fr')));
  safe_media text := nullif(trim(coalesce(p_media_url, '')), '');
  created_post posts%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if author_id is null then
    raise exception 'profile_required';
  end if;

  if char_length(safe_body) < 3 or char_length(safe_body) > 4000 then
    raise exception 'invalid_post_body';
  end if;

  if safe_type not in ('update', 'media', 'statistics', 'recruitment') then
    raise exception 'invalid_post_type';
  end if;

  if not exists (select 1 from supported_locales sl where sl.code = safe_locale and sl.is_enabled) then
    safe_locale := 'fr';
  end if;

  if safe_media is not null and (
    char_length(safe_media) > 2048
    or safe_media !~ '^https://'
  ) then
    raise exception 'invalid_media_url';
  end if;

  if safe_media is null then
    p_media_kind := null;
  elsif p_media_kind not in ('image', 'video') then
    raise exception 'invalid_media_kind';
  end if;

  if jsonb_typeof(coalesce(p_statistics, '{}'::jsonb)) <> 'object'
    or octet_length(coalesce(p_statistics, '{}'::jsonb)::text) > 1500 then
    raise exception 'invalid_statistics';
  end if;

  insert into posts (
    author_profile_id,
    post_type,
    body,
    source_locale,
    visibility,
    media_url,
    media_kind,
    statistics
  ) values (
    author_id,
    safe_type,
    safe_body,
    safe_locale,
    'public',
    safe_media,
    p_media_kind,
    coalesce(p_statistics, '{}'::jsonb)
  )
  returning * into created_post;

  return jsonb_build_object('created', true, 'id', created_post.id);
end;
$$;

create or replace function get_feed_posts(
  feed_locale text default 'fr',
  feed_limit integer default 30,
  feed_offset integer default 0
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(result.item order by result.created_at desc), '[]'::jsonb)
  from (
    select
      po.created_at,
      jsonb_build_object(
        'id', po.id,
        'post_type', po.post_type,
        'body', coalesce(pt.body, po.body),
        'source_locale', po.source_locale,
        'media_url', po.media_url,
        'media_kind', po.media_kind,
        'statistics', po.statistics,
        'reaction_count', po.reaction_count,
        'comment_count', po.comment_count,
        'created_at', po.created_at,
        'reacted', exists (
          select 1 from post_reactions pr
          where pr.post_id = po.id
            and pr.profile_id = current_member_profile_id()
            and pr.reaction_type = 'support'
        ),
        'author', jsonb_build_object(
          'id', author.id,
          'display_name', author.display_name,
          'slug', author.slug,
          'primary_role_code', author.primary_role_code,
          'location_text', author.location_text,
          'verification_status', author.verification_status
        )
      ) as item
    from posts po
    join profiles author on author.id = po.author_profile_id
    left join post_translations pt
      on pt.post_id = po.id
      and pt.locale = feed_locale
    where po.visibility = 'public'
      and po.deleted_at is null
      and author.visibility = 'public'
    order by po.created_at desc
    limit least(greatest(coalesce(feed_limit, 30), 1), 50)
    offset greatest(coalesce(feed_offset, 0), 0)
  ) result;
$$;

create or replace function toggle_post_reaction(target_post uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id uuid := current_member_profile_id();
  is_active boolean;
  total integer;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if actor_id is null then
    raise exception 'profile_required';
  end if;

  if not exists (
    select 1 from posts p
    where p.id = target_post
      and p.visibility = 'public'
      and p.deleted_at is null
  ) then
    raise exception 'post_not_found';
  end if;

  if exists (
    select 1 from post_reactions pr
    where pr.post_id = target_post
      and pr.profile_id = actor_id
      and pr.reaction_type = 'support'
  ) then
    delete from post_reactions
    where post_id = target_post
      and profile_id = actor_id
      and reaction_type = 'support';
    is_active := false;
  else
    insert into post_reactions (post_id, profile_id, reaction_type)
    values (target_post, actor_id, 'support');
    is_active := true;
  end if;

  select p.reaction_count into total from posts p where p.id = target_post;
  return jsonb_build_object('active', is_active, 'count', coalesce(total, 0));
end;
$$;

create or replace function add_post_comment(target_post uuid, comment_body text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  author_id uuid := current_member_profile_id();
  safe_body text := trim(coalesce(comment_body, ''));
  created_comment post_comments%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if author_id is null then
    raise exception 'profile_required';
  end if;

  if char_length(safe_body) < 1 or char_length(safe_body) > 1500 then
    raise exception 'invalid_comment';
  end if;

  if not exists (
    select 1 from posts p
    where p.id = target_post
      and p.visibility = 'public'
      and p.deleted_at is null
  ) then
    raise exception 'post_not_found';
  end if;

  insert into post_comments (post_id, author_profile_id, body)
  values (target_post, author_id, safe_body)
  returning * into created_comment;

  return jsonb_build_object('created', true, 'id', created_comment.id);
end;
$$;

create or replace function get_post_comments(target_post uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(result.item order by result.created_at), '[]'::jsonb)
  from (
    select
      pc.created_at,
      jsonb_build_object(
        'id', pc.id,
        'body', pc.body,
        'created_at', pc.created_at,
        'author', jsonb_build_object(
          'display_name', author.display_name,
          'slug', author.slug,
          'primary_role_code', author.primary_role_code
        )
      ) as item
    from post_comments pc
    join profiles author on author.id = pc.author_profile_id
    join posts po on po.id = pc.post_id
    where pc.post_id = target_post
      and pc.deleted_at is null
      and po.visibility = 'public'
      and po.deleted_at is null
    order by pc.created_at
    limit 100
  ) result;
$$;

create or replace function get_member_notifications(member_limit integer default 20)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(result.item order by result.created_at desc), '[]'::jsonb)
  from (
    select
      n.created_at,
      jsonb_build_object(
        'id', n.id,
        'notification_type', n.notification_type,
        'entity_type', n.entity_type,
        'entity_id', n.entity_id,
        'post_id', n.payload ->> 'post_id',
        'read', n.read_at is not null,
        'created_at', n.created_at,
        'actor', jsonb_build_object(
          'display_name', actor.display_name,
          'slug', actor.slug
        )
      ) as item
    from notifications n
    left join profiles actor on actor.id = n.actor_profile_id
    where n.recipient_profile_id = current_member_profile_id()
    order by n.created_at desc
    limit least(greatest(coalesce(member_limit, 20), 1), 50)
  ) result;
$$;

create or replace function mark_member_notifications_read()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  member_profile uuid := current_member_profile_id();
  affected integer;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if member_profile is null then
    raise exception 'profile_required';
  end if;

  update notifications
  set read_at = now()
  where recipient_profile_id = member_profile
    and read_at is null;

  get diagnostics affected = row_count;
  return jsonb_build_object('updated', affected);
end;
$$;

grant select on posts, post_translations, post_comments to anon, authenticated;
grant select on post_reactions, notifications to authenticated;

revoke all on function create_feed_post(text, text, text, text, text, jsonb) from public;
revoke all on function get_feed_posts(text, integer, integer) from public;
revoke all on function toggle_post_reaction(uuid) from public;
revoke all on function add_post_comment(uuid, text) from public;
revoke all on function get_post_comments(uuid) from public;
revoke all on function get_member_notifications(integer) from public;
revoke all on function mark_member_notifications_read() from public;

grant execute on function create_feed_post(text, text, text, text, text, jsonb) to authenticated;
grant execute on function get_feed_posts(text, integer, integer) to anon, authenticated;
grant execute on function toggle_post_reaction(uuid) to authenticated;
grant execute on function add_post_comment(uuid, text) to authenticated;
grant execute on function get_post_comments(uuid) to anon, authenticated;
grant execute on function get_member_notifications(integer) to authenticated;
grant execute on function mark_member_notifications_read() to authenticated;

commit;
