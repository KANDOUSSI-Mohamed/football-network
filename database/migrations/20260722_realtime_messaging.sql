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
