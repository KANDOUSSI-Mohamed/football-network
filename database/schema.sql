-- Football Network - Initial Supabase/PostgreSQL schema

create extension if not exists "uuid-ossp";

create table countries (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  iso2 text,
  iso3 text,
  fifa_code text,
  continent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table confederations (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  acronym text not null,
  website_url text
);

create table federations (
  id uuid primary key default uuid_generate_v4(),
  country_id uuid references countries(id),
  confederation_id uuid references confederations(id),
  name text not null,
  acronym text,
  website_url text,
  logo_url text,
  source_url text,
  verification_status text not null default 'unverified',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  profile_type text not null,
  display_name text not null,
  slug text unique,
  avatar_url text,
  cover_url text,
  bio text,
  country_id uuid references countries(id),
  city text,
  visibility text not null default 'public',
  verification_status text not null default 'unverified',
  claim_status text not null default 'unclaimed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table competitions (
  id uuid primary key default uuid_generate_v4(),
  country_id uuid references countries(id),
  federation_id uuid references federations(id),
  name text not null,
  level integer,
  gender text not null default 'men',
  category text not null default 'senior',
  competition_type text not null default 'league',
  website_url text,
  source_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table seasons (
  id uuid primary key default uuid_generate_v4(),
  competition_id uuid references competitions(id),
  name text not null,
  start_date date,
  end_date date,
  status text not null default 'planned'
);

create table stadiums (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  country_id uuid references countries(id),
  city text,
  address text,
  capacity integer,
  latitude numeric,
  longitude numeric,
  source_url text
);

create table clubs (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid references profiles(id),
  country_id uuid references countries(id),
  federation_id uuid references federations(id),
  official_name text not null,
  short_name text,
  slug text unique,
  city text,
  region text,
  founded_year integer,
  stadium_id uuid references stadiums(id),
  website_url text,
  logo_url text,
  colors text,
  club_status text not null default 'unknown',
  source_url text,
  data_quality text not null default 'draft',
  claim_status text not null default 'unclaimed',
  verification_status text not null default 'unverified',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table teams (
  id uuid primary key default uuid_generate_v4(),
  club_id uuid references clubs(id),
  name text not null,
  category text not null default 'senior',
  gender text not null default 'men',
  competition_id uuid references competitions(id),
  season_id uuid references seasons(id),
  level text,
  active boolean not null default true
);

create table player_profiles (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references profiles(id),
  date_of_birth date,
  birth_place text,
  nationality_country_id uuid references countries(id),
  second_nationality_country_id uuid references countries(id),
  sporting_country_id uuid references countries(id),
  current_club_id uuid references clubs(id),
  current_team_id uuid references teams(id),
  primary_position text,
  secondary_positions text[],
  preferred_foot text,
  height_cm integer,
  weight_kg integer,
  contract_status text not null default 'unknown',
  contract_end_date date,
  availability_status text not null default 'unknown',
  looking_for_project boolean not null default false,
  represented_by_agent boolean not null default false,
  agent_profile_id uuid references profiles(id),
  mobility text,
  languages text[],
  profile_completion_score integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table player_career_entries (
  id uuid primary key default uuid_generate_v4(),
  player_profile_id uuid not null references player_profiles(id),
  club_id uuid references clubs(id),
  team_id uuid references teams(id),
  season_id uuid references seasons(id),
  country_id uuid references countries(id),
  competition_id uuid references competitions(id),
  start_date date,
  end_date date,
  category text,
  division_label text,
  coach_name text,
  notes text,
  source_url text,
  verification_status text not null default 'declared'
);

create table player_statistics (
  id uuid primary key default uuid_generate_v4(),
  player_profile_id uuid not null references player_profiles(id),
  career_entry_id uuid references player_career_entries(id),
  season_id uuid references seasons(id),
  competition_id uuid references competitions(id),
  appearances integer default 0,
  starts integer default 0,
  minutes_played integer default 0,
  goals integer default 0,
  assists integer default 0,
  yellow_cards integer default 0,
  red_cards integer default 0,
  clean_sheets integer default 0,
  goals_conceded integer default 0,
  saves integer default 0,
  penalties_saved integer default 0,
  tackles integer default 0,
  interceptions integer default 0,
  duels_won integer default 0,
  passes_completed integer default 0,
  key_passes integer default 0,
  shots integer default 0,
  shots_on_target integer default 0,
  source_type text not null default 'declared',
  source_url text,
  verification_status text not null default 'unverified'
);

create table media_assets (
  id uuid primary key default uuid_generate_v4(),
  owner_profile_id uuid not null references profiles(id),
  media_type text not null,
  title text,
  description text,
  url text not null,
  thumbnail_url text,
  visibility text not null default 'public',
  source text,
  created_at timestamptz not null default now()
);

create table documents (
  id uuid primary key default uuid_generate_v4(),
  owner_profile_id uuid not null references profiles(id),
  document_type text not null,
  title text not null,
  file_url text not null,
  visibility text not null default 'private',
  verification_status text not null default 'unverified',
  uploaded_at timestamptz not null default now()
);

create table opportunities (
  id uuid primary key default uuid_generate_v4(),
  organization_profile_id uuid not null references profiles(id),
  opportunity_type text not null,
  title text not null,
  description text,
  country_id uuid references countries(id),
  city text,
  competition_id uuid references competitions(id),
  level text,
  position text,
  age_min integer,
  age_max integer,
  contract_type text,
  start_date date,
  deadline date,
  visibility text not null default 'public',
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table applications (
  id uuid primary key default uuid_generate_v4(),
  opportunity_id uuid not null references opportunities(id),
  applicant_profile_id uuid not null references profiles(id),
  status text not null default 'submitted',
  message text,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table connections (
  id uuid primary key default uuid_generate_v4(),
  requester_profile_id uuid not null references profiles(id),
  receiver_profile_id uuid not null references profiles(id),
  status text not null default 'pending',
  connection_type text not null default 'professional',
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

create table conversations (
  id uuid primary key default uuid_generate_v4(),
  created_by_profile_id uuid references profiles(id),
  conversation_type text not null default 'direct',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table conversation_participants (
  id uuid primary key default uuid_generate_v4(),
  conversation_id uuid not null references conversations(id),
  profile_id uuid not null references profiles(id),
  role text not null default 'member',
  last_read_at timestamptz
);

create table messages (
  id uuid primary key default uuid_generate_v4(),
  conversation_id uuid not null references conversations(id),
  sender_profile_id uuid not null references profiles(id),
  body text,
  attachment_id uuid references media_assets(id),
  message_type text not null default 'text',
  created_at timestamptz not null default now(),
  read_at timestamptz,
  deleted_at timestamptz
);

create table claims (
  id uuid primary key default uuid_generate_v4(),
  claimant_user_id uuid,
  target_profile_id uuid not null references profiles(id),
  claim_type text not null,
  status text not null default 'submitted',
  message text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by_user_id uuid
);

create table subscriptions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid,
  plan text not null,
  status text not null default 'active',
  started_at timestamptz not null default now(),
  ends_at timestamptz,
  provider text,
  provider_subscription_id text
);

create index idx_profiles_type on profiles(profile_type);
create index idx_profiles_country on profiles(country_id);
create index idx_clubs_country on clubs(country_id);
create index idx_player_profiles_position on player_profiles(primary_position);
create index idx_player_profiles_availability on player_profiles(availability_status);
create index idx_opportunities_type on opportunities(opportunity_type);
create index idx_connections_receiver on connections(receiver_profile_id);
create index idx_messages_conversation on messages(conversation_id);

