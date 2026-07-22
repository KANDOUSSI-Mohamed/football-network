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
