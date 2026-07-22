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
