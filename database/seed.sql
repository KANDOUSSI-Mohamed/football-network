-- Initial seed data for France and Morocco.
-- This seed is intentionally small. It validates the structure before larger imports.

insert into confederations (name, acronym, website_url)
values
  ('Federation Internationale de Football Association', 'FIFA', 'https://www.fifa.com'),
  ('Union of European Football Associations', 'UEFA', 'https://www.uefa.com'),
  ('Confederation Africaine de Football', 'CAF', 'https://www.cafonline.com');

insert into countries (name, iso2, iso3, fifa_code, continent)
values
  ('France', 'FR', 'FRA', 'FRA', 'Europe'),
  ('Morocco', 'MA', 'MAR', 'MAR', 'Africa');

insert into federations (country_id, confederation_id, name, acronym, website_url, verification_status)
select c.id, cf.id, 'Federation Francaise de Football', 'FFF', 'https://www.fff.fr', 'public_import'
from countries c, confederations cf
where c.iso2 = 'FR' and cf.acronym = 'UEFA';

insert into federations (country_id, confederation_id, name, acronym, website_url, verification_status)
select c.id, cf.id, 'Federation Royale Marocaine de Football', 'FRMF', 'https://frmf.ma', 'public_import'
from countries c, confederations cf
where c.iso2 = 'MA' and cf.acronym = 'CAF';

insert into competitions (country_id, federation_id, name, level, gender, category, competition_type, active)
select c.id, f.id, x.name, x.level, 'men', 'senior', 'league', true
from countries c
join federations f on f.country_id = c.id
cross join (
  values
    ('Ligue 1', 1),
    ('Ligue 2', 2),
    ('National', 3),
    ('National 2', 4),
    ('National 3', 5)
) as x(name, level)
where c.iso2 = 'FR';

insert into competitions (country_id, federation_id, name, level, gender, category, competition_type, active)
select c.id, f.id, x.name, x.level, 'men', 'senior', 'league', true
from countries c
join federations f on f.country_id = c.id
cross join (
  values
    ('Botola Pro 1', 1),
    ('Botola Pro 2', 2)
) as x(name, level)
where c.iso2 = 'MA';

