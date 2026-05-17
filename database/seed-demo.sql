-- Demo data for the MVP screens.
-- Run after schema.sql and seed.sql.

insert into profiles (profile_type, display_name, slug, country_id, city, verification_status, claim_status)
select 'club', 'Olympique Lyonnais', 'olympique-lyonnais', c.id, 'Lyon', 'public_import', 'unclaimed'
from countries c
where c.iso2 = 'FR'
on conflict (slug) do nothing;

insert into profiles (profile_type, display_name, slug, country_id, city, verification_status, claim_status)
select 'club', 'CODM Meknes', 'codm-meknes', c.id, 'Meknes', 'public_import', 'unclaimed'
from countries c
where c.iso2 = 'MA'
on conflict (slug) do nothing;

insert into profiles (profile_type, display_name, slug, country_id, city, verification_status, claim_status)
select 'club', 'FC Nantes', 'fc-nantes', c.id, 'Nantes', 'public_import', 'unclaimed'
from countries c
where c.iso2 = 'FR'
on conflict (slug) do nothing;

insert into clubs (
  profile_id,
  country_id,
  federation_id,
  official_name,
  short_name,
  slug,
  city,
  club_status,
  data_quality,
  claim_status,
  verification_status
)
select p.id, c.id, f.id, p.display_name, p.display_name, p.slug, p.city, 'professional', 'public_import', 'unclaimed', 'public_import'
from profiles p
join countries c on c.id = p.country_id
join federations f on f.country_id = c.id
where p.slug in ('olympique-lyonnais', 'codm-meknes', 'fc-nantes')
on conflict (slug) do nothing;

insert into profiles (profile_type, display_name, slug, country_id, city, verification_status, claim_status)
select 'player', 'Yanis Benali', 'yanis-benali', c.id, 'Lyon', 'declared', 'claimed'
from countries c
where c.iso2 = 'FR'
on conflict (slug) do nothing;

insert into profiles (profile_type, display_name, slug, country_id, city, verification_status, claim_status)
select 'player', 'Adam El Mansouri', 'adam-el-mansouri', c.id, 'Casablanca', 'declared', 'claimed'
from countries c
where c.iso2 = 'MA'
on conflict (slug) do nothing;

insert into profiles (profile_type, display_name, slug, country_id, city, verification_status, claim_status)
select 'player', 'Noah Morel', 'noah-morel', c.id, 'Nantes', 'declared', 'claimed'
from countries c
where c.iso2 = 'FR'
on conflict (slug) do nothing;

insert into player_profiles (
  profile_id,
  nationality_country_id,
  sporting_country_id,
  current_club_id,
  primary_position,
  preferred_foot,
  height_cm,
  contract_status,
  availability_status,
  looking_for_project,
  languages,
  profile_completion_score
)
select p.id, c.id, c.id, null, 'Avant-centre', 'Droit', 184, 'free', 'available_now', true, array['francais'], 78
from profiles p
join countries c on c.iso2 = 'FR'
where p.slug = 'yanis-benali'
and not exists (select 1 from player_profiles pp where pp.profile_id = p.id);

insert into player_profiles (
  profile_id,
  nationality_country_id,
  sporting_country_id,
  current_club_id,
  primary_position,
  preferred_foot,
  height_cm,
  contract_status,
  availability_status,
  looking_for_project,
  languages,
  profile_completion_score
)
select p.id, c.id, c.id, cl.id, 'Milieu relayeur', 'Droit', 178, 'amateur', 'open_to_opportunities', true, array['francais', 'arabe'], 84
from profiles p
join countries c on c.iso2 = 'MA'
left join clubs cl on cl.slug = 'codm-meknes'
where p.slug = 'adam-el-mansouri'
and not exists (select 1 from player_profiles pp where pp.profile_id = p.id);

insert into player_profiles (
  profile_id,
  nationality_country_id,
  sporting_country_id,
  current_club_id,
  primary_position,
  preferred_foot,
  height_cm,
  contract_status,
  availability_status,
  looking_for_project,
  languages,
  profile_completion_score
)
select p.id, c.id, c.id, cl.id, 'Gardien', 'Gauche', 191, 'under_contract', 'available_end_of_season', true, array['francais'], 71
from profiles p
join countries c on c.iso2 = 'FR'
left join clubs cl on cl.slug = 'fc-nantes'
where p.slug = 'noah-morel'
and not exists (select 1 from player_profiles pp where pp.profile_id = p.id);

insert into player_statistics (player_profile_id, appearances, starts, minutes_played, goals, assists, source_type, verification_status)
select pp.id, 24, 20, 1810, 14, 5, 'declared', 'unverified'
from player_profiles pp
join profiles p on p.id = pp.profile_id
where p.slug = 'yanis-benali'
and not exists (select 1 from player_statistics ps where ps.player_profile_id = pp.id);

insert into player_statistics (player_profile_id, appearances, starts, minutes_played, goals, assists, source_type, verification_status)
select pp.id, 29, 24, 2100, 6, 11, 'declared', 'unverified'
from player_profiles pp
join profiles p on p.id = pp.profile_id
where p.slug = 'adam-el-mansouri'
and not exists (select 1 from player_statistics ps where ps.player_profile_id = pp.id);

insert into player_statistics (player_profile_id, appearances, starts, minutes_played, goals, assists, clean_sheets, source_type, verification_status)
select pp.id, 21, 21, 1890, 0, 1, 8, 'declared', 'unverified'
from player_profiles pp
join profiles p on p.id = pp.profile_id
where p.slug = 'noah-morel'
and not exists (select 1 from player_statistics ps where ps.player_profile_id = pp.id);

insert into opportunities (
  organization_profile_id,
  opportunity_type,
  title,
  description,
  country_id,
  city,
  level,
  position,
  age_min,
  age_max,
  contract_type,
  deadline,
  status
)
select p.id, 'player_recruitment', 'Recherche attaquant U23 disponible', 'Besoin prioritaire pour renforcer le secteur offensif.', c.id, 'Meknes', 'Botola Pro', 'Avant-centre', 18, 23, 'A definir', '2026-06-30', 'open'
from profiles p
join countries c on c.iso2 = 'MA'
where p.slug = 'codm-meknes'
and not exists (select 1 from opportunities o where o.title = 'Recherche attaquant U23 disponible');

insert into opportunities (
  organization_profile_id,
  opportunity_type,
  title,
  description,
  country_id,
  city,
  level,
  position,
  age_min,
  age_max,
  contract_type,
  deadline,
  status
)
select p.id, 'trial', 'Essai gardien senior', 'Session d evaluation pour gardien disponible fin de saison.', c.id, 'Nantes', 'National 3', 'Gardien', 18, 26, 'Essai', '2026-07-15', 'open'
from profiles p
join countries c on c.iso2 = 'FR'
where p.slug = 'fc-nantes'
and not exists (select 1 from opportunities o where o.title = 'Essai gardien senior');

