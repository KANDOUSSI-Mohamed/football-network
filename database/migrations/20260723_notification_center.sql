-- Football Network: unified member notification center.
-- Notifications are generated server-side for every important network event.

begin;

alter table notifications
  drop constraint if exists notifications_notification_type_check;

alter table notifications
  add constraint notifications_notification_type_check
  check (notification_type in (
    'post_reaction',
    'post_comment',
    'opportunity_match',
    'application_received',
    'application_status',
    'verification_submitted',
    'verification_status',
    'club_claim_submitted',
    'club_claim_status',
    'connection_request',
    'connection_status',
    'direct_message'
  ));

create index if not exists idx_notifications_member_inbox
  on notifications(recipient_profile_id, read_at, created_at desc);

create or replace function notify_identity_verification_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  reviewer_profile uuid;
begin
  if tg_op = 'INSERT' then
    insert into notifications (
      recipient_profile_id,
      actor_profile_id,
      notification_type,
      entity_type,
      entity_id,
      payload
    )
    select
      staff_profile.id,
      new.profile_id,
      'verification_submitted',
      'identity_verification',
      new.id,
      jsonb_build_object(
        'verification_type', new.verification_type,
        'status', new.status
      )
    from platform_staff staff
    join profiles staff_profile
      on staff_profile.user_id = staff.user_id
      and staff_profile.profile_type = 'person'
    where staff.is_active
      and staff.staff_role in ('super_admin', 'verifier')
      and staff_profile.id <> new.profile_id
    on conflict (recipient_profile_id, actor_profile_id, notification_type, entity_id)
      do update set
        payload = excluded.payload,
        read_at = null,
        created_at = now();
    return new;
  end if;

  if new.status is distinct from old.status then
    select p.id
    into reviewer_profile
    from profiles p
    where p.user_id = new.reviewed_by
      and p.profile_type = 'person'
    order by p.created_at
    limit 1;

    delete from notifications
    where recipient_profile_id = new.profile_id
      and notification_type = 'verification_status'
      and entity_id = new.id;

    insert into notifications (
      recipient_profile_id,
      actor_profile_id,
      notification_type,
      entity_type,
      entity_id,
      payload
    )
    values (
      new.profile_id,
      reviewer_profile,
      'verification_status',
      'identity_verification',
      new.id,
      jsonb_build_object(
        'verification_type', new.verification_type,
        'status', new.status,
        'reviewer_notes', new.reviewer_notes
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists identity_verification_notification_trigger
  on identity_verification_requests;
create trigger identity_verification_notification_trigger
after insert or update of status on identity_verification_requests
for each row execute function notify_identity_verification_event();

create or replace function notify_club_claim_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  reviewer_profile uuid;
begin
  if new.claim_type <> 'club_ownership' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    insert into notifications (
      recipient_profile_id,
      actor_profile_id,
      notification_type,
      entity_type,
      entity_id,
      payload
    )
    select
      staff_profile.id,
      new.claimant_profile_id,
      'club_claim_submitted',
      'club_claim',
      new.id,
      jsonb_build_object(
        'status', new.status,
        'target_profile_id', new.target_profile_id,
        'organization_role', new.organization_role
      )
    from platform_staff staff
    join profiles staff_profile
      on staff_profile.user_id = staff.user_id
      and staff_profile.profile_type = 'person'
    where staff.is_active
      and staff.staff_role in ('super_admin', 'verifier', 'moderator')
      and staff_profile.id <> new.claimant_profile_id
    on conflict (recipient_profile_id, actor_profile_id, notification_type, entity_id)
      do update set
        payload = excluded.payload,
        read_at = null,
        created_at = now();
    return new;
  end if;

  if new.status is distinct from old.status
    and new.claimant_profile_id is not null then
    select p.id
    into reviewer_profile
    from profiles p
    where p.user_id = new.reviewed_by_user_id
      and p.profile_type = 'person'
    order by p.created_at
    limit 1;

    delete from notifications
    where recipient_profile_id = new.claimant_profile_id
      and notification_type = 'club_claim_status'
      and entity_id = new.id;

    insert into notifications (
      recipient_profile_id,
      actor_profile_id,
      notification_type,
      entity_type,
      entity_id,
      payload
    )
    values (
      new.claimant_profile_id,
      reviewer_profile,
      'club_claim_status',
      'club_claim',
      new.id,
      jsonb_build_object(
        'status', new.status,
        'target_profile_id', new.target_profile_id,
        'reviewer_notes', new.reviewer_notes
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists club_claim_notification_trigger on claims;
create trigger club_claim_notification_trigger
after insert or update of status on claims
for each row execute function notify_club_claim_event();

create or replace function notify_connection_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into notifications (
      recipient_profile_id,
      actor_profile_id,
      notification_type,
      entity_type,
      entity_id,
      payload
    )
    values (
      new.receiver_profile_id,
      new.requester_profile_id,
      'connection_request',
      'connection',
      new.id,
      jsonb_build_object(
        'status', new.status,
        'connection_type', new.connection_type
      )
    )
    on conflict (recipient_profile_id, actor_profile_id, notification_type, entity_id)
      do update set
        payload = excluded.payload,
        read_at = null,
        created_at = now();
    return new;
  end if;

  if new.status is distinct from old.status
    and new.status in ('accepted', 'rejected') then
    insert into notifications (
      recipient_profile_id,
      actor_profile_id,
      notification_type,
      entity_type,
      entity_id,
      payload
    )
    values (
      new.requester_profile_id,
      new.receiver_profile_id,
      'connection_status',
      'connection',
      new.id,
      jsonb_build_object(
        'status', new.status,
        'connection_type', new.connection_type
      )
    )
    on conflict (recipient_profile_id, actor_profile_id, notification_type, entity_id)
      do update set
        payload = excluded.payload,
        read_at = null,
        created_at = now();
  end if;

  return new;
end;
$$;

drop trigger if exists connection_notification_trigger on connections;
create trigger connection_notification_trigger
after insert or update of status on connections
for each row execute function notify_connection_event();

create or replace function notify_direct_message_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.deleted_at is not null then
    return new;
  end if;

  insert into notifications (
    recipient_profile_id,
    actor_profile_id,
    notification_type,
    entity_type,
    entity_id,
    payload
  )
  select
    participant.profile_id,
    new.sender_profile_id,
    'direct_message',
    'conversation',
    new.conversation_id,
    jsonb_build_object(
      'message_id', new.id,
      'conversation_id', new.conversation_id,
      'preview', left(coalesce(new.body, ''), 180)
    )
  from conversation_participants participant
  where participant.conversation_id = new.conversation_id
    and participant.profile_id <> new.sender_profile_id
  on conflict (recipient_profile_id, actor_profile_id, notification_type, entity_id)
    do update set
      payload = excluded.payload,
      read_at = null,
      created_at = now();

  return new;
end;
$$;

drop trigger if exists direct_message_notification_trigger on messages;
create trigger direct_message_notification_trigger
after insert on messages
for each row execute function notify_direct_message_event();

create or replace function get_member_notifications_v2(
  member_filter text default 'all',
  member_limit integer default 30,
  member_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  member_profile uuid := current_member_profile_id();
  safe_filter text := case when member_filter = 'unread' then 'unread' else 'all' end;
  safe_limit integer := least(greatest(coalesce(member_limit, 30), 1), 50);
  safe_offset integer := greatest(coalesce(member_offset, 0), 0);
  result_items jsonb;
  total_count integer;
  unread_count integer;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if member_profile is null then
    raise exception 'profile_required';
  end if;

  select count(*)
  into unread_count
  from notifications n
  where n.recipient_profile_id = member_profile
    and n.read_at is null;

  select count(*)
  into total_count
  from notifications n
  where n.recipient_profile_id = member_profile
    and (safe_filter = 'all' or n.read_at is null);

  select coalesce(jsonb_agg(row_data.item order by row_data.created_at desc), '[]'::jsonb)
  into result_items
  from (
    select
      n.created_at,
      jsonb_build_object(
        'id', n.id,
        'notification_type', n.notification_type,
        'entity_type', n.entity_type,
        'entity_id', n.entity_id,
        'payload', n.payload,
        'read', n.read_at is not null,
        'read_at', n.read_at,
        'created_at', n.created_at,
        'actor', case
          when actor.id is null then null
          else jsonb_build_object(
            'id', actor.id,
            'display_name', actor.display_name,
            'slug', actor.slug,
            'primary_role_code', actor.primary_role_code,
            'avatar_url', actor.avatar_url
          )
        end
      ) as item
    from notifications n
    left join profiles actor on actor.id = n.actor_profile_id
    where n.recipient_profile_id = member_profile
      and (safe_filter = 'all' or n.read_at is null)
    order by n.created_at desc
    limit safe_limit
    offset safe_offset
  ) row_data;

  return jsonb_build_object(
    'items', result_items,
    'total', total_count,
    'unread', unread_count,
    'limit', safe_limit,
    'offset', safe_offset
  );
end;
$$;

create or replace function mark_member_notification_read(target_notification uuid)
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
  set read_at = coalesce(read_at, now())
  where id = target_notification
    and recipient_profile_id = member_profile;

  get diagnostics affected = row_count;
  return jsonb_build_object('updated', affected = 1);
end;
$$;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table notifications;
  end if;
end
$$;

revoke all on function notify_identity_verification_event() from public, anon, authenticated;
revoke all on function notify_club_claim_event() from public, anon, authenticated;
revoke all on function notify_connection_event() from public, anon, authenticated;
revoke all on function notify_direct_message_event() from public, anon, authenticated;
revoke all on function get_member_notifications_v2(text, integer, integer) from public, anon;
revoke all on function mark_member_notification_read(uuid) from public, anon;

grant execute on function get_member_notifications_v2(text, integer, integer) to authenticated;
grant execute on function mark_member_notification_read(uuid) to authenticated;

commit;
