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
