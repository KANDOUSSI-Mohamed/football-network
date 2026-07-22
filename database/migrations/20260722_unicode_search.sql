-- Football Network: Unicode-safe search normalization for the worldwide catalogue.

begin;

create or replace function normalize_search_text(value text)
returns text
language sql
stable
parallel safe
set search_path=public,extensions
as $$
  select trim(regexp_replace(lower(unaccent(coalesce(value,''))),'[^[:alnum:]]+',' ','g'));
$$;

update clubs set
  normalized_name=normalize_search_text(concat_ws(' ',official_name,short_name)),
  normalized_city=normalize_search_text(city),
  canonical_key=normalize_search_text(concat_ws(' ',official_name,city,postal_code)),
  search_vector=to_tsvector('simple',concat_ws(' ',official_name,short_name,city,region,postal_code))
where normalized_name='' or normalized_name is null;

commit;
