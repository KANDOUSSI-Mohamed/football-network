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


-- ============================================================
-- 20260722_professional_profiles.sql
-- ============================================================

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


-- Football Network: global geographic and club-data backbone.
-- Additive, idempotent and designed for bulk imports with traceable sources.

begin;

create extension if not exists unaccent with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create table if not exists data_sources (
  id bigint generated by default as identity primary key,
  slug text not null unique,
  name text not null,
  website_url text not null,
  license_name text,
  license_url text,
  attribution_text text,
  terms_url text,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into data_sources(slug,name,website_url,license_name,license_url,attribution_text,terms_url)
values
  ('geonames','GeoNames','https://www.geonames.org/','CC BY 4.0','https://creativecommons.org/licenses/by/4.0/','Geographic data provided by GeoNames.','https://www.geonames.org/export/'),
  ('wikidata','Wikidata','https://www.wikidata.org/','CC0 1.0','https://creativecommons.org/publicdomain/zero/1.0/','Structured data provided by Wikidata.','https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use/'),
  ('openstreetmap','OpenStreetMap','https://www.openstreetmap.org/','ODbL 1.0','https://opendatacommons.org/licenses/odbl/1-0/','Data © OpenStreetMap contributors.','https://www.openstreetmap.org/copyright'),
  ('national_federation','National football federations','https://www.fifa.com/about-fifa/associations','Source-specific','https://www.fifa.com/legal','Club records verified against official federation publications when available.','https://www.fifa.com/legal')
on conflict(slug) do update set
  name=excluded.name,
  website_url=excluded.website_url,
  license_name=excluded.license_name,
  license_url=excluded.license_url,
  attribution_text=excluded.attribution_text,
  terms_url=excluded.terms_url,
  updated_at=now();

create or replace function normalize_search_text(value text)
returns text
language sql
stable
parallel safe
set search_path=public,extensions
as $$
  select trim(regexp_replace(lower(unaccent(coalesce(value,''))),'[^a-z0-9]+',' ','g'));
$$;

create table if not exists geographic_places (
  id bigint generated by default as identity primary key,
  source_id bigint not null references data_sources(id),
  source_key text not null,
  country_code text not null,
  postal_code text,
  place_name text not null,
  normalized_place_name text not null default '',
  admin_name1 text,
  admin_code1 text,
  admin_name2 text,
  admin_code2 text,
  admin_name3 text,
  admin_code3 text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  accuracy smallint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(source_id,source_key)
);

create table if not exists place_aliases (
  id bigint generated by default as identity primary key,
  geographic_place_id bigint not null references geographic_places(id) on delete cascade,
  alias text not null,
  normalized_alias text not null default '',
  locale text,
  source_id bigint references data_sources(id),
  created_at timestamptz not null default now(),
  unique(geographic_place_id,normalized_alias)
);

create or replace function prepare_geographic_place_search()
returns trigger
language plpgsql
set search_path=public,extensions
as $$
begin
  new.country_code:=upper(left(trim(coalesce(new.country_code,'')),2));
  new.postal_code:=nullif(upper(trim(coalesce(new.postal_code,''))), '');
  new.normalized_place_name:=normalize_search_text(new.place_name);
  new.updated_at:=now();
  return new;
end;
$$;

drop trigger if exists geographic_place_search_trigger on geographic_places;
create trigger geographic_place_search_trigger
before insert or update of country_code,postal_code,place_name on geographic_places
for each row execute function prepare_geographic_place_search();

create or replace function prepare_place_alias_search()
returns trigger
language plpgsql
set search_path=public,extensions
as $$
begin
  new.normalized_alias:=normalize_search_text(new.alias);
  return new;
end;
$$;

drop trigger if exists place_alias_search_trigger on place_aliases;
create trigger place_alias_search_trigger
before insert or update of alias on place_aliases
for each row execute function prepare_place_alias_search();

create index if not exists idx_geographic_places_country_postal
  on geographic_places(country_code,postal_code);
create index if not exists idx_geographic_places_country_name
  on geographic_places(country_code,normalized_place_name);
create index if not exists idx_geographic_places_name_trgm
  on geographic_places using gin(normalized_place_name extensions.gin_trgm_ops);
create index if not exists idx_place_aliases_name_trgm
  on place_aliases using gin(normalized_alias extensions.gin_trgm_ops);

alter table clubs
  add column if not exists postal_code text,
  add column if not exists address_line text,
  add column if not exists admin1_code text,
  add column if not exists admin2_code text,
  add column if not exists latitude numeric(10,7),
  add column if not exists longitude numeric(10,7),
  add column if not exists geographic_place_id bigint references geographic_places(id) on delete set null,
  add column if not exists normalized_name text not null default '',
  add column if not exists normalized_city text not null default '',
  add column if not exists search_vector tsvector,
  add column if not exists canonical_key text,
  add column if not exists source_priority integer not null default 100,
  add column if not exists last_synced_at timestamptz;

create table if not exists club_aliases (
  id bigint generated by default as identity primary key,
  club_id uuid not null references clubs(id) on delete cascade,
  alias_name text not null,
  normalized_alias text not null default '',
  locale text,
  source_id bigint references data_sources(id),
  created_at timestamptz not null default now(),
  unique(club_id,normalized_alias)
);

create table if not exists club_external_ids (
  id bigint generated by default as identity primary key,
  club_id uuid not null references clubs(id) on delete cascade,
  source_id bigint not null references data_sources(id),
  external_id text not null,
  source_url text,
  raw_hash text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(source_id,external_id)
);

create table if not exists data_import_jobs (
  id uuid primary key default uuid_generate_v4(),
  source_id bigint not null references data_sources(id),
  import_type text not null,
  country_code text,
  status text not null default 'pending',
  rows_read integer not null default 0,
  rows_inserted integer not null default 0,
  rows_updated integer not null default 0,
  rows_rejected integer not null default 0,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  constraint data_import_jobs_status_check check(status in ('pending','running','completed','failed','cancelled'))
);

create table if not exists club_import_staging (
  id bigint generated by default as identity primary key,
  import_job_id uuid not null references data_import_jobs(id) on delete cascade,
  source_id bigint not null references data_sources(id),
  external_id text,
  raw_name text not null,
  normalized_name text not null default '',
  country_code text,
  city text,
  normalized_city text not null default '',
  postal_code text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  website_url text,
  source_url text,
  raw_data jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  matched_club_id uuid references clubs(id) on delete set null,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint club_import_staging_status_check check(status in ('pending','matched','created','rejected','review'))
);

create table if not exists club_merge_candidates (
  id bigint generated by default as identity primary key,
  staging_id bigint not null references club_import_staging(id) on delete cascade,
  candidate_club_id uuid not null references clubs(id) on delete cascade,
  match_score numeric(5,4) not null,
  match_reasons jsonb not null default '[]'::jsonb,
  status text not null default 'pending',
  reviewed_by uuid references profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(staging_id,candidate_club_id),
  constraint club_merge_candidates_status_check check(status in ('pending','accepted','rejected'))
);

create or replace function prepare_club_search()
returns trigger
language plpgsql
set search_path=public,extensions
as $$
begin
  new.normalized_name:=normalize_search_text(concat_ws(' ',new.official_name,new.short_name));
  new.normalized_city:=normalize_search_text(new.city);
  new.postal_code:=nullif(upper(trim(coalesce(new.postal_code,''))), '');
  new.canonical_key:=normalize_search_text(concat_ws(' ',new.official_name,new.city,new.postal_code));
  new.search_vector:=to_tsvector('simple',concat_ws(' ',new.official_name,new.short_name,new.city,new.region,new.postal_code));
  return new;
end;
$$;

drop trigger if exists club_search_prepare_trigger on clubs;
create trigger club_search_prepare_trigger
before insert or update of official_name,short_name,city,region,postal_code on clubs
for each row execute function prepare_club_search();

create or replace function prepare_club_alias_search()
returns trigger
language plpgsql
set search_path=public,extensions
as $$
begin
  new.normalized_alias:=normalize_search_text(new.alias_name);
  return new;
end;
$$;

drop trigger if exists club_alias_search_trigger on club_aliases;
create trigger club_alias_search_trigger
before insert or update of alias_name on club_aliases
for each row execute function prepare_club_alias_search();

update geographic_places
set normalized_place_name=normalize_search_text(place_name)
where normalized_place_name='' or normalized_place_name is null;

update clubs set
  normalized_name=normalize_search_text(concat_ws(' ',official_name,short_name)),
  normalized_city=normalize_search_text(city),
  canonical_key=normalize_search_text(concat_ws(' ',official_name,city,postal_code)),
  search_vector=to_tsvector('simple',concat_ws(' ',official_name,short_name,city,region,postal_code))
where normalized_name='' or normalized_city='' or search_vector is null or canonical_key is null;

create index if not exists idx_clubs_search_vector on clubs using gin(search_vector);
create index if not exists idx_clubs_normalized_name_trgm on clubs using gin(normalized_name extensions.gin_trgm_ops);
create index if not exists idx_clubs_normalized_city on clubs(normalized_city);
create index if not exists idx_clubs_postal_code on clubs(postal_code);
create index if not exists idx_clubs_canonical_key on clubs(canonical_key);
create index if not exists idx_club_aliases_name_trgm on club_aliases using gin(normalized_alias extensions.gin_trgm_ops);
create index if not exists idx_import_jobs_status on data_import_jobs(status,created_at desc);
create index if not exists idx_club_staging_match on club_import_staging(country_code,normalized_city,normalized_name);
create index if not exists idx_club_merge_pending on club_merge_candidates(status,match_score desc);

create or replace function search_places(
  p_query text default '',
  p_country text default '',
  p_limit integer default 15
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,extensions
as $$
declare
  safe_query text:=normalize_search_text(left(trim(coalesce(p_query,'')),120));
  safe_country text:=upper(left(trim(coalesce(p_country,'')),2));
  safe_limit integer:=greatest(1,least(coalesce(p_limit,15),50));
  result jsonb;
begin
  if char_length(safe_query)<2 and char_length(safe_country)<>2 then
    return '[]'::jsonb;
  end if;

  with matched as (
    select gp.country_code,gp.postal_code,gp.place_name,gp.admin_name1,gp.admin_name2,gp.latitude,gp.longitude,
      case
        when normalize_search_text(coalesce(gp.postal_code,''))=safe_query then 100
        when gp.normalized_place_name=safe_query then 95
        when normalize_search_text(coalesce(gp.postal_code,'')) like safe_query||'%' then 90
        when gp.normalized_place_name like safe_query||'%' then 85
        else greatest(similarity(gp.normalized_place_name,safe_query),0)*70
      end as rank_score
    from geographic_places gp
    where (safe_country='' or gp.country_code=safe_country)
      and (
        safe_query=''
        or normalize_search_text(coalesce(gp.postal_code,'')) like safe_query||'%'
        or gp.normalized_place_name like safe_query||'%'
        or gp.normalized_place_name % safe_query
        or exists(select 1 from place_aliases pa where pa.geographic_place_id=gp.id and (pa.normalized_alias like safe_query||'%' or pa.normalized_alias % safe_query))
      )
  ), deduplicated as (
    select distinct on(country_code,postal_code,place_name,admin_name1)
      country_code,postal_code,place_name,admin_name1,admin_name2,latitude,longitude,rank_score
    from matched
    order by country_code,postal_code,place_name,admin_name1,rank_score desc
  )
  select coalesce(jsonb_agg(to_jsonb(ranked) order by rank_score desc,place_name,postal_code),'[]'::jsonb)
  into result
  from (select * from deduplicated order by rank_score desc,place_name,postal_code limit safe_limit) ranked;

  return coalesce(result,'[]'::jsonb);
end;
$$;

create or replace function search_clubs_v2(
  p_query text default '',
  p_country text default '',
  p_city text default '',
  p_postal_code text default '',
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
set search_path=public,extensions
as $$
declare
  viewer uuid:=current_member_profile_id();
  safe_query text:=normalize_search_text(left(trim(coalesce(p_query,'')),120));
  safe_country text:=normalize_search_text(upper(left(trim(coalesce(p_country,'')),80)));
  safe_city text:=normalize_search_text(left(trim(coalesce(p_city,'')),120));
  safe_postal text:=upper(left(trim(coalesce(p_postal_code,'')),32));
  safe_type text:=left(trim(coalesce(p_club_type,'')),40);
  safe_claim text:=left(trim(coalesce(p_claim_status,'')),40);
  safe_limit integer:=greatest(1,least(coalesce(p_limit,24),60));
  safe_offset integer:=greatest(0,least(coalesce(p_offset,0),1000000));
  result jsonb;
begin
  with matching as (
    select
      c.id,c.profile_id,c.official_name,c.short_name,c.slug,c.city,c.region,c.postal_code,c.address_line,
      c.latitude,c.longitude,c.founded_year,c.website_url,c.logo_url,c.colors,c.club_status,c.club_type,c.description,
      c.data_quality,c.claim_status,c.verification_status,c.followers_count,c.featured,
      co.name as country_name,co.iso2 as country_code,p.avatar_url,p.cover_url,
      exists(select 1 from club_follows f where f.club_id=c.id and f.profile_id=viewer) as followed,
      (select count(*)::integer from opportunities o where o.organization_profile_id=c.profile_id and o.status='open' and o.visibility='public' and (o.deadline is null or o.deadline>=current_date)) as open_opportunities,
      case
        when safe_query='' then 0
        when normalize_search_text(c.official_name)=safe_query then 100
        when normalize_search_text(coalesce(c.short_name,''))=safe_query then 98
        when c.normalized_name like safe_query||'%' then 90
        when c.search_vector @@ websearch_to_tsquery('simple',safe_query) then 80+ts_rank(c.search_vector,websearch_to_tsquery('simple',safe_query))*10
        else greatest(similarity(c.normalized_name,safe_query),0)*70
      end as rank_score
    from clubs c
    left join profiles p on p.id=c.profile_id
    left join countries co on co.id=c.country_id
    where (p.id is null or p.visibility='public')
      and (
        safe_query=''
        or c.search_vector @@ websearch_to_tsquery('simple',safe_query)
        or c.normalized_name % safe_query
        or c.normalized_name like '%'||safe_query||'%'
        or c.normalized_city like safe_query||'%'
        or coalesce(c.postal_code,'') like upper(safe_query)||'%'
        or exists(select 1 from club_aliases ca where ca.club_id=c.id and (ca.normalized_alias like '%'||safe_query||'%' or ca.normalized_alias % safe_query))
      )
      and (safe_country='' or normalize_search_text(coalesce(co.iso2,''))=safe_country or normalize_search_text(coalesce(co.name,''))=safe_country)
      and (safe_city='' or c.normalized_city=safe_city or c.normalized_city like safe_city||'%')
      and (safe_postal='' or coalesce(c.postal_code,'') like safe_postal||'%')
      and (safe_type='' or c.club_type=safe_type)
      and (safe_claim='' or c.claim_status=safe_claim)
      and (not coalesce(p_followed_only,false) or exists(select 1 from club_follows f where f.club_id=c.id and f.profile_id=viewer))
  ), counted as (
    select count(*)::integer total from matching
  ), paged as (
    select * from matching
    order by featured desc,rank_score desc,followers_count desc,official_name
    limit safe_limit offset safe_offset
  )
  select jsonb_build_object(
    'total',counted.total,
    'results',coalesce((select jsonb_agg(to_jsonb(paged) order by featured desc,rank_score desc,followers_count desc,official_name) from paged),'[]'::jsonb)
  ) into result from counted;

  return coalesce(result,jsonb_build_object('total',0,'results','[]'::jsonb));
end;
$$;

create or replace function get_data_attributions()
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'slug',slug,'name',name,'website_url',website_url,'license_name',license_name,
    'license_url',license_url,'attribution_text',attribution_text
  ) order by name),'[]'::jsonb)
  from data_sources where enabled=true;
$$;

alter table data_sources enable row level security;
alter table geographic_places enable row level security;
alter table place_aliases enable row level security;
alter table club_aliases enable row level security;
alter table club_external_ids enable row level security;
alter table data_import_jobs enable row level security;
alter table club_import_staging enable row level security;
alter table club_merge_candidates enable row level security;

revoke all on data_sources,geographic_places,place_aliases,club_aliases,club_external_ids,data_import_jobs,club_import_staging,club_merge_candidates from anon,authenticated;
revoke all on function search_places(text,text,integer) from public;
revoke all on function search_clubs_v2(text,text,text,text,text,text,boolean,integer,integer) from public;
revoke all on function get_data_attributions() from public;
grant execute on function search_places(text,text,integer) to anon,authenticated;
grant execute on function search_clubs_v2(text,text,text,text,text,text,boolean,integer,integer) to anon,authenticated;
grant execute on function get_data_attributions() to anon,authenticated;

-- Repair legacy seed strings that were previously committed with mojibake.
update clubs set official_name='Maghreb Association Sportive de Fès',city='Fès' where slug='maghreb-de-fes' and claim_status='unclaimed';
update clubs set official_name='Moghreb Athletic de Tétouan',city='Tétouan' where slug='moghreb-de-tetouan' and claim_status='unclaimed';
update clubs set official_name='Hassania Union Sport d''Agadir' where slug='hassania-agadir' and claim_status='unclaimed';
update clubs set official_name='Difaâ Hassani d''El Jadida' where slug='difaa-el-jadida' and claim_status='unclaimed';
update clubs set official_name='Club Omnisports de Meknès',city='Meknès' where slug='codm-meknes' and claim_status='unclaimed';
update clubs set official_name='Mouloudia Club d''Oujda' where slug='mouloudia-oujda' and claim_status='unclaimed';
update clubs set official_name='Kénitra Athletic Club',city='Kénitra' where slug='kenitra-athletic-club' and claim_status='unclaimed';
update clubs set official_name='Kawkab Athlétique Club de Marrakech' where slug='kawkab-marrakech' and claim_status='unclaimed';
update clubs set official_name='Chabab Mohammédia',city='Mohammédia' where slug='chabab-mohammedia' and claim_status='unclaimed';
update clubs set official_name='Chabab Atlas Khénifra',city='Khénifra' where slug='chabab-atlas-khenifra' and claim_status='unclaimed';

commit;



-- Football Network: indexed search across places, regions and provinces.

begin;

alter table geographic_places
  add column if not exists normalized_admin_name1 text not null default '',
  add column if not exists normalized_admin_name2 text not null default '';

create or replace function prepare_geographic_place_search()
returns trigger
language plpgsql
set search_path=public,extensions
as $$
begin
  new.country_code:=upper(left(trim(coalesce(new.country_code,'')),2));
  new.postal_code:=nullif(upper(trim(coalesce(new.postal_code,''))), '');
  new.normalized_place_name:=normalize_search_text(new.place_name);
  new.normalized_admin_name1:=normalize_search_text(new.admin_name1);
  new.normalized_admin_name2:=normalize_search_text(new.admin_name2);
  new.updated_at:=now();
  return new;
end;
$$;

drop trigger if exists geographic_place_search_trigger on geographic_places;
create trigger geographic_place_search_trigger
before insert or update of country_code,postal_code,place_name,admin_name1,admin_name2 on geographic_places
for each row execute function prepare_geographic_place_search();

update geographic_places set
  normalized_admin_name1=normalize_search_text(admin_name1),
  normalized_admin_name2=normalize_search_text(admin_name2)
where normalized_admin_name1='' or normalized_admin_name2='';

create index if not exists idx_geographic_places_admin1_trgm
  on geographic_places using gin(normalized_admin_name1 extensions.gin_trgm_ops);
create index if not exists idx_geographic_places_admin2_trgm
  on geographic_places using gin(normalized_admin_name2 extensions.gin_trgm_ops);

create or replace function search_places(
  p_query text default '',
  p_country text default '',
  p_limit integer default 15
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,extensions
as $$
declare
  safe_query text:=normalize_search_text(left(trim(coalesce(p_query,'')),120));
  safe_country text:=upper(left(trim(coalesce(p_country,'')),2));
  safe_limit integer:=greatest(1,least(coalesce(p_limit,15),50));
  result jsonb;
begin
  if char_length(safe_query)<2 and char_length(safe_country)<>2 then
    return '[]'::jsonb;
  end if;

  with primary_matches as (
    select gp.country_code,gp.postal_code,gp.place_name,gp.admin_name1,gp.admin_name2,gp.latitude,gp.longitude,
      case
        when normalize_search_text(coalesce(gp.postal_code,''))=safe_query then 100
        when gp.normalized_place_name=safe_query then 95
        when normalize_search_text(coalesce(gp.postal_code,'')) like safe_query||'%' then 90
        when gp.normalized_place_name like safe_query||'%' then 85
        else greatest(similarity(gp.normalized_place_name,safe_query),0)*70
      end as rank_score
    from geographic_places gp
    where (safe_country='' or gp.country_code=safe_country)
      and (
        safe_query=''
        or normalize_search_text(coalesce(gp.postal_code,'')) like safe_query||'%'
        or gp.normalized_place_name like safe_query||'%'
        or gp.normalized_place_name % safe_query
        or exists(select 1 from place_aliases pa where pa.geographic_place_id=gp.id and (pa.normalized_alias like safe_query||'%' or pa.normalized_alias % safe_query))
      )
  ), admin2_matches as (
    select gp.country_code,null::text as postal_code,gp.admin_name2 as place_name,gp.admin_name1,gp.admin_name2,
      avg(gp.latitude)::numeric(10,7) as latitude,avg(gp.longitude)::numeric(10,7) as longitude,
      case when gp.normalized_admin_name2=safe_query then 94 when gp.normalized_admin_name2 like safe_query||'%' then 84 else greatest(similarity(gp.normalized_admin_name2,safe_query),0)*68 end as rank_score
    from geographic_places gp
    where safe_query<>'' and gp.admin_name2 is not null
      and (safe_country='' or gp.country_code=safe_country)
      and (gp.normalized_admin_name2 like safe_query||'%' or gp.normalized_admin_name2 % safe_query)
    group by gp.country_code,gp.admin_name1,gp.admin_name2,gp.normalized_admin_name2
  ), admin1_matches as (
    select gp.country_code,null::text as postal_code,gp.admin_name1 as place_name,gp.admin_name1,null::text as admin_name2,
      avg(gp.latitude)::numeric(10,7) as latitude,avg(gp.longitude)::numeric(10,7) as longitude,
      case when gp.normalized_admin_name1=safe_query then 93 when gp.normalized_admin_name1 like safe_query||'%' then 83 else greatest(similarity(gp.normalized_admin_name1,safe_query),0)*66 end as rank_score
    from geographic_places gp
    where safe_query<>'' and gp.admin_name1 is not null
      and (safe_country='' or gp.country_code=safe_country)
      and (gp.normalized_admin_name1 like safe_query||'%' or gp.normalized_admin_name1 % safe_query)
    group by gp.country_code,gp.admin_name1,gp.normalized_admin_name1
  ), matched as (
    select * from primary_matches
    union all select * from admin2_matches
    union all select * from admin1_matches
  ), deduplicated as (
    select distinct on(country_code,coalesce(postal_code,''),place_name,coalesce(admin_name1,''))
      country_code,postal_code,place_name,admin_name1,admin_name2,latitude,longitude,rank_score
    from matched
    order by country_code,coalesce(postal_code,''),place_name,coalesce(admin_name1,''),rank_score desc
  )
  select coalesce(jsonb_agg(to_jsonb(ranked) order by rank_score desc,place_name,postal_code),'[]'::jsonb)
  into result
  from (select * from deduplicated order by rank_score desc,place_name,postal_code limit safe_limit) ranked;

  return coalesce(result,'[]'::jsonb);
end;
$$;

revoke all on function search_places(text,text,integer) from public;
grant execute on function search_places(text,text,integer) to anon,authenticated;

commit;
