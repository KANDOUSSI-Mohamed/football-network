-- Football Network: traceable worldwide club catalogue imports.
-- Run after 20260722_global_data_backbone.sql.

begin;

create unique index if not exists idx_club_staging_job_external
  on club_import_staging(import_job_id,source_id,external_id)
  where external_id is not null;

create or replace function import_club_records(
  p_job_id uuid,
  p_source_slug text,
  p_country_code text,
  p_country_name text,
  p_records jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions
as $$
declare
  source_record data_sources%rowtype;
  country_record countries%rowtype;
  job_record data_import_jobs%rowtype;
  raw_record jsonb;
  staging_record club_import_staging%rowtype;
  matched_club uuid;
  candidate_club uuid;
  candidate_score numeric(5,4);
  safe_country text:=upper(left(trim(coalesce(p_country_code,'')),2));
  safe_country_name text:=left(trim(coalesce(p_country_name,'')),120);
  external_key text;
  club_name text;
  safe_short_name text;
  normalized_club_name text;
  club_city text;
  normalized_club_city text;
  club_region text;
  club_website text;
  record_source_url text;
  club_slug text;
  founded integer;
  latitude_value numeric(10,7);
  longitude_value numeric(10,7);
  aliases jsonb;
  alias_value jsonb;
  alias_name text;
  total_count integer:=0;
  created_count integer:=0;
  matched_count integer:=0;
  review_count integer:=0;
  rejected_count integer:=0;
begin
  if coalesce(auth.role(),'')<>'service_role' then
    raise exception 'service_role_required';
  end if;
  if safe_country!~'^[A-Z]{2}$' then raise exception 'invalid_country_code'; end if;
  if coalesce(jsonb_typeof(p_records),'')<>'array' then raise exception 'records_must_be_an_array'; end if;
  if jsonb_array_length(p_records)>250 then raise exception 'batch_too_large'; end if;

  select * into source_record from data_sources where slug=left(trim(coalesce(p_source_slug,'')),80) and enabled=true;
  if source_record.id is null then raise exception 'data_source_not_found'; end if;
  select * into job_record from data_import_jobs where id=p_job_id and source_id=source_record.id and status='running';
  if job_record.id is null then raise exception 'active_import_job_not_found'; end if;

  select * into country_record from countries where upper(iso2)=safe_country order by created_at limit 1;
  if country_record.id is null then
    insert into countries(name,iso2,created_at,updated_at)
    values(coalesce(nullif(safe_country_name,''),safe_country),safe_country,now(),now())
    returning * into country_record;
  elsif safe_country_name<>'' and country_record.name=safe_country then
    update countries set name=safe_country_name,updated_at=now() where id=country_record.id returning * into country_record;
  end if;

  for raw_record in select value from jsonb_array_elements(p_records)
  loop
    total_count:=total_count+1;
    external_key:=upper(left(trim(coalesce(raw_record->>'external_id','')),80));
    club_name:=left(trim(coalesce(raw_record->>'name','')),240);
    safe_short_name:=nullif(left(trim(coalesce(raw_record->>'short_name','')),80),'');
    normalized_club_name:=normalize_search_text(club_name);
    club_city:=nullif(left(trim(coalesce(raw_record->>'city','')),160),'');
    normalized_club_city:=normalize_search_text(club_city);
    club_region:=nullif(left(trim(coalesce(raw_record->>'region','')),160),'');
    club_website:=nullif(left(trim(coalesce(raw_record->>'website_url','')),500),'');
    record_source_url:=nullif(left(trim(coalesce(raw_record->>'source_url','')),500),'');
    aliases:=case when jsonb_typeof(raw_record->'aliases')='array' then raw_record->'aliases' else '[]'::jsonb end;
    founded:=case when coalesce(raw_record->>'founded_year','')~'^[0-9]{4}$' then (raw_record->>'founded_year')::integer else null end;
    latitude_value:=case when coalesce(raw_record->>'latitude','')~'^[-+]?[0-9]+([.][0-9]+)?$' then (raw_record->>'latitude')::numeric else null end;
    longitude_value:=case when coalesce(raw_record->>'longitude','')~'^[-+]?[0-9]+([.][0-9]+)?$' then (raw_record->>'longitude')::numeric else null end;
    if club_website is not null and club_website!~*'^https?://' then club_website:=null; end if;
    if record_source_url is null and external_key~'^Q[0-9]+$' then
      record_source_url:='https://www.wikidata.org/wiki/'||external_key;
    end if;
    if latitude_value is not null and (latitude_value < -90 or latitude_value > 90) then latitude_value:=null; end if;
    if longitude_value is not null and (longitude_value < -180 or longitude_value > 180) then longitude_value:=null; end if;

    if external_key!~'^Q[0-9]+$' or char_length(normalized_club_name)<2 then
      insert into club_import_staging(
        import_job_id,source_id,external_id,raw_name,normalized_name,country_code,city,normalized_city,
        website_url,source_url,raw_data,status,rejection_reason,updated_at
      ) values(
        p_job_id,source_record.id,nullif(external_key,''),coalesce(nullif(club_name,''),'Unnamed club'),normalized_club_name,
        safe_country,club_city,normalized_club_city,club_website,record_source_url,raw_record,'rejected','invalid_external_id_or_name',now()
      );
      rejected_count:=rejected_count+1;
      continue;
    end if;

    insert into club_import_staging(
      import_job_id,source_id,external_id,raw_name,normalized_name,country_code,city,normalized_city,
      latitude,longitude,website_url,source_url,raw_data,status,updated_at
    ) values(
      p_job_id,source_record.id,external_key,club_name,normalized_club_name,safe_country,club_city,normalized_club_city,
      latitude_value,longitude_value,club_website,record_source_url,raw_record,'pending',now()
    )
    on conflict(import_job_id,source_id,external_id) where external_id is not null
    do update set
      raw_name=excluded.raw_name,normalized_name=excluded.normalized_name,city=excluded.city,
      normalized_city=excluded.normalized_city,latitude=excluded.latitude,longitude=excluded.longitude,
      website_url=excluded.website_url,source_url=excluded.source_url,raw_data=excluded.raw_data,
      status='pending',matched_club_id=null,rejection_reason=null,updated_at=now()
    returning * into staging_record;

    matched_club:=null;
    candidate_club:=null;
    candidate_score:=null;

    select cei.club_id into matched_club
    from club_external_ids cei
    where cei.source_id=source_record.id and cei.external_id=external_key;

    if matched_club is null then
      select c.id into matched_club
      from clubs c
      where c.country_id=country_record.id
        and (
          normalize_search_text(c.official_name)=normalized_club_name
          or normalize_search_text(coalesce(c.short_name,''))=normalized_club_name
          or exists(select 1 from club_aliases ca where ca.club_id=c.id and ca.normalized_alias=normalized_club_name)
        )
        and (normalized_club_city='' or c.normalized_city='' or c.normalized_city=normalized_club_city)
      order by
        (normalize_search_text(c.official_name)=normalized_club_name) desc,
        (c.normalized_city=normalized_club_city) desc,
        c.source_priority asc,
        c.created_at asc
      limit 1;
    end if;

    if matched_club is null then
      select c.id,similarity(normalize_search_text(c.official_name),normalized_club_name)
      into candidate_club,candidate_score
      from clubs c
      where c.country_id=country_record.id
        and normalized_club_city<>''
        and c.normalized_city=normalized_club_city
        and similarity(normalize_search_text(c.official_name),normalized_club_name)>=0.90
      order by similarity(normalize_search_text(c.official_name),normalized_club_name) desc,c.created_at asc
      limit 1;
    end if;

    if matched_club is null and candidate_club is not null then
      update club_import_staging set status='review',rejection_reason='possible_duplicate',updated_at=now()
      where id=staging_record.id;
      insert into club_merge_candidates(staging_id,candidate_club_id,match_score,match_reasons)
      values(staging_record.id,candidate_club,candidate_score,jsonb_build_array('same_country','same_city','similar_name'))
      on conflict(staging_id,candidate_club_id) do update set
        match_score=excluded.match_score,match_reasons=excluded.match_reasons,status='pending',reviewed_by=null,reviewed_at=null;
      review_count:=review_count+1;
      continue;
    end if;

    if matched_club is null then
      club_slug:=left(coalesce(nullif(replace(normalized_club_name,' ','-'),''),'club')||'-'||lower(external_key),160);
      insert into clubs(
        country_id,official_name,short_name,slug,city,region,founded_year,website_url,source_url,
        club_status,club_type,data_quality,claim_status,verification_status,source_locale,
        latitude,longitude,source_priority,last_synced_at
      ) values(
        country_record.id,club_name,safe_short_name,club_slug,club_city,club_region,founded,club_website,record_source_url,
        'unknown','other','wikidata_import','unclaimed','public_import','fr',
        latitude_value,longitude_value,60,now()
      ) returning id into matched_club;
      created_count:=created_count+1;
      update club_import_staging set status='created',matched_club_id=matched_club,updated_at=now()
      where id=staging_record.id;
    else
      update clubs set
        short_name=coalesce(nullif(clubs.short_name,''),safe_short_name),
        city=coalesce(nullif(clubs.city,''),club_city),
        region=coalesce(nullif(clubs.region,''),club_region),
        founded_year=coalesce(clubs.founded_year,founded),
        website_url=coalesce(nullif(clubs.website_url,''),club_website),
        source_url=coalesce(nullif(clubs.source_url,''),record_source_url),
        latitude=coalesce(clubs.latitude,latitude_value),
        longitude=coalesce(clubs.longitude,longitude_value),
        last_synced_at=now(),updated_at=now()
      where id=matched_club;
      matched_count:=matched_count+1;
      update club_import_staging set status='matched',matched_club_id=matched_club,updated_at=now()
      where id=staging_record.id;
    end if;

    insert into club_external_ids(club_id,source_id,external_id,source_url,raw_hash,last_seen_at)
    values(matched_club,source_record.id,external_key,record_source_url,md5(raw_record::text),now())
    on conflict(source_id,external_id) do update set
      club_id=excluded.club_id,source_url=excluded.source_url,raw_hash=excluded.raw_hash,last_seen_at=now();

    if safe_short_name is not null then
      insert into club_aliases(club_id,alias_name,locale,source_id)
      values(matched_club,safe_short_name,null,source_record.id)
      on conflict(club_id,normalized_alias) do nothing;
    end if;
    for alias_value in select value from jsonb_array_elements(aliases)
    loop
      alias_name:=nullif(left(trim(alias_value#>>'{}'),240),'');
      if alias_name is not null and char_length(normalize_search_text(alias_name))>=2 then
        insert into club_aliases(club_id,alias_name,locale,source_id)
        values(matched_club,alias_name,null,source_record.id)
        on conflict(club_id,normalized_alias) do nothing;
      end if;
    end loop;
  end loop;

  return jsonb_build_object(
    'read',total_count,'created',created_count,'matched',matched_count,
    'review',review_count,'rejected',rejected_count
  );
end;
$$;

create or replace function get_club_directory_countries()
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'code',ranked.iso2,'name',ranked.name,'club_count',ranked.club_count
  ) order by ranked.club_count desc,ranked.name),'[]'::jsonb)
  from (
    select upper(co.iso2) iso2,co.name,count(c.id)::integer club_count
    from countries co join clubs c on c.country_id=co.id
    where co.iso2 is not null and char_length(trim(co.iso2))=2
    group by upper(co.iso2),co.name
  ) ranked;
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
    'city',c.city,'region',c.region,'postal_code',c.postal_code,'founded_year',c.founded_year,
    'website_url',c.website_url,'logo_url',c.logo_url,'colors',c.colors,'club_status',c.club_status,
    'club_type',c.club_type,'description',c.description,'address',coalesce(c.address,c.address_line),
    'latitude',c.latitude,'longitude',c.longitude,
    'public_email',case when c.claim_status='claimed' then c.public_email else null end,
    'public_phone',case when c.claim_status='claimed' then c.public_phone else null end,
    'linkedin_url',c.linkedin_url,'instagram_url',c.instagram_url,'x_url',c.x_url,'data_quality',c.data_quality,
    'claim_status',c.claim_status,'verification_status',c.verification_status,'followers_count',c.followers_count,
    'country_name',co.name,'country_code',co.iso2,'avatar_url',p.avatar_url,'cover_url',p.cover_url,
    'followed',exists(select 1 from club_follows f where f.club_id=c.id and f.profile_id=viewer),
    'source_attributions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'name',sources.name,'website_url',sources.website_url,'license_name',sources.license_name,
        'license_url',sources.license_url,'source_url',sources.source_url,'attribution_text',sources.attribution_text
      ) order by sources.name)
      from (
        select distinct ds.name,ds.website_url,ds.license_name,ds.license_url,cei.source_url,ds.attribution_text
        from club_external_ids cei join data_sources ds on ds.id=cei.source_id
        where cei.club_id=c.id
      ) sources
    ),'[]'::jsonb),
    'open_opportunities',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',o.id,'title',o.title,'opportunity_type',o.opportunity_type,'role_code',o.role_code,
        'city',o.city,'location_text',o.location_text,'contract_type',o.contract_type,'deadline',o.deadline
      ) order by o.published_at desc)
      from opportunities o
      where c.profile_id is not null and o.organization_profile_id=c.profile_id and o.status='open'
        and o.visibility='public' and (o.deadline is null or o.deadline>=current_date)
    ),'[]'::jsonb)
  ) into result
  from clubs c left join profiles p on p.id=c.profile_id left join countries co on co.id=c.country_id
  where c.slug=left(trim(coalesce(target_slug,'')),160) and (p.id is null or p.visibility='public');
  if result is null then raise exception 'club_not_found'; end if;
  return result;
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
  lazy_profile uuid;
  safe_role text:=left(trim(coalesce(payload->>'organization_role','')),100);
  safe_email text:=lower(left(trim(coalesce(payload->>'contact_email','')),180));
  safe_message text:=left(trim(coalesce(payload->>'message','')),2500);
  proof_url text:=left(trim(coalesce(payload->>'proof_url','')),500);
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if member is null then raise exception 'profile_required'; end if;
  select * into target from clubs where id=target_club for update;
  if target.id is null then raise exception 'club_not_found'; end if;
  if target.claim_status='claimed' then raise exception 'club_already_claimed'; end if;
  if char_length(safe_role)<2 then raise exception 'organization_role_required'; end if;
  if safe_email!~*'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then raise exception 'valid_contact_email_required'; end if;
  if char_length(safe_message)<20 then raise exception 'claim_message_too_short'; end if;
  if proof_url<>'' and proof_url!~*'^https?://' then raise exception 'invalid_proof_url'; end if;

  if target.profile_id is null then
    select p.id into lazy_profile
    from profiles p
    where p.slug=target.slug and p.profile_type='club'
      and not exists(select 1 from clubs linked where linked.profile_id=p.id and linked.id<>target.id)
    limit 1;
    if lazy_profile is null then
      insert into profiles(
        profile_type,display_name,slug,country_id,city,visibility,verification_status,claim_status,
        preferred_locale,source_locale,location_text
      ) values(
        'club',target.official_name,target.slug,target.country_id,target.city,'public','public_import','unclaimed',
        coalesce(nullif(target.source_locale,''),'fr'),coalesce(nullif(target.source_locale,''),'fr'),
        concat_ws(', ',target.city,(select name from countries where id=target.country_id))
      ) returning id into lazy_profile;
    end if;
    update clubs set profile_id=lazy_profile,updated_at=now() where id=target.id;
    target.profile_id:=lazy_profile;
  end if;

  insert into claims(
    claimant_user_id,claimant_profile_id,target_profile_id,claim_type,status,message,
    organization_role,contact_email,evidence,submitted_at,updated_at
  ) values(
    auth.uid(),member,target.profile_id,'club_ownership','submitted',safe_message,
    safe_role,safe_email,jsonb_build_object('proof_url',nullif(proof_url,'')),now(),now()
  ) returning * into created;
  update clubs set claim_status='pending',updated_at=now() where id=target.id and claim_status='unclaimed';
  update profiles set claim_status='pending',updated_at=now() where id=target.profile_id and claim_status='unclaimed';
  return jsonb_build_object('submitted',true,'id',created.id,'status',created.status);
exception when unique_violation then
  raise exception 'claim_already_submitted';
end;
$$;

revoke all on function import_club_records(uuid,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function get_club_directory_countries() from public;
revoke all on function get_club_detail(text) from public;
revoke all on function submit_club_claim(uuid,jsonb) from public;
grant execute on function import_club_records(uuid,text,text,text,jsonb) to service_role;
grant execute on function get_club_directory_countries() to anon,authenticated;
grant execute on function get_club_detail(text) to anon,authenticated;
grant execute on function submit_club_claim(uuid,jsonb) to authenticated;

commit;
