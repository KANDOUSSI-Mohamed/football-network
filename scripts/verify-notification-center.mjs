import { readFile } from "node:fs/promises";
import process from "node:process";
import worker from "../sites/football-network-worker.js";

function parseEnv(content) {
  return Object.fromEntries(
    content
      .split(/\r?\n/)
      .filter((line) => line.includes("="))
      .map((line) => {
        const index = line.indexOf("=");
        return [line.slice(0, index).trim(), line.slice(index + 1).trim()];
      }),
  );
}

const env = parseEnv(await readFile(".env.local", "utf8"));
const locales = ["fr", "en", "es", "it", "pt", "de", "nl", "ar", "tr"];
const pages = [];

for (const locale of locales) {
  const response = await worker.fetch(
    new Request(`https://football-network.test/${locale}/notifications`),
    env,
  );
  const html = await response.text();
  const script = html.match(/<script>([\s\S]*)<\/script>/)?.[1];
  const checks = {
    status: response.status === 200,
    route: html.includes('data-notification-hub'),
    filters:
      html.includes('data-notification-filter="all"') &&
      html.includes('data-notification-filter="unread"'),
    individualRead: html.includes(
      "/rest/v1/rpc/mark_member_notification_read",
    ),
    inboxRpc: html.includes(
      "/rest/v1/rpc/get_member_notifications_v2",
    ),
    noOpenAutoRead:
      html.includes('popover.classList.toggle("hidden")') &&
      !html.includes(
        'popover.classList.toggle("hidden");markAll()',
      ),
    polling: html.includes("15000"),
    fixedLayout: html.includes(
      "grid-template-columns:260px minmax(590px,1fr) 300px",
    ),
    localized:
      locale !== "fr" ||
      html.includes(
        "Suivez les messages, relations, candidatures et validations",
      ),
    rtl: locale !== "ar" || html.includes('dir="rtl"'),
    encoding: !html.includes("ï¿½"),
    clientSyntax: Boolean(script),
  };

  if (script) {
    try {
      Function(script);
    } catch (error) {
      checks.clientSyntax = false;
      checks.clientError = error.message;
    }
  }

  pages.push({ locale, checks });
}

const anonymousSecurity = {};
if (env.NEXT_PUBLIC_SUPABASE_URL && env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
  const headers = {
    apikey: env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    Authorization: `Bearer ${env.NEXT_PUBLIC_SUPABASE_ANON_KEY}`,
    "Content-Type": "application/json",
  };
  const calls = {
    inbox: [
      "get_member_notifications_v2",
      { member_filter: "all", member_limit: 10, member_offset: 0 },
    ],
    singleRead: [
      "mark_member_notification_read",
      { target_notification: "00000000-0000-0000-0000-000000000000" },
    ],
    allRead: ["mark_member_notifications_read", {}],
  };

  for (const [name, [rpc, body]] of Object.entries(calls)) {
    const response = await fetch(
      `${env.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/rpc/${rpc}`,
      {
        method: "POST",
        headers,
        body: JSON.stringify(body),
      },
    );
    anonymousSecurity[`${name}RejectsAnonymous`] = !response.ok;
  }
}

const databaseSecurity = {};
let functionalTransaction = false;

if (env.SUPABASE_ACCESS_TOKEN) {
  const structureQuery = `
    select
      to_regprocedure('public.get_member_notifications_v2(text,integer,integer)') is not null as inbox_function,
      to_regprocedure('public.mark_member_notification_read(uuid)') is not null as single_read_function,
      has_function_privilege('authenticated','public.get_member_notifications_v2(text,integer,integer)','EXECUTE') as authenticated_inbox,
      not has_function_privilege('anon','public.get_member_notifications_v2(text,integer,integer)','EXECUTE') as anon_no_inbox,
      not has_function_privilege('anon','public.mark_member_notification_read(uuid)','EXECUTE') as anon_no_single_read,
      coalesce((select relrowsecurity from pg_class where oid='public.notifications'::regclass),false) as notification_rls,
      exists (
        select 1 from pg_trigger
        where tgrelid='public.identity_verification_requests'::regclass
          and tgname='identity_verification_notification_trigger'
          and not tgisinternal
      ) as identity_trigger,
      exists (
        select 1 from pg_trigger
        where tgrelid='public.claims'::regclass
          and tgname='club_claim_notification_trigger'
          and not tgisinternal
      ) as club_claim_trigger,
      exists (
        select 1 from pg_trigger
        where tgrelid='public.connections'::regclass
          and tgname='connection_notification_trigger'
          and not tgisinternal
      ) as connection_trigger,
      exists (
        select 1 from pg_trigger
        where tgrelid='public.messages'::regclass
          and tgname='direct_message_notification_trigger'
          and not tgisinternal
      ) as message_trigger,
      exists (
        select 1 from pg_publication_tables
        where pubname='supabase_realtime'
          and schemaname='public'
          and tablename='notifications'
      ) as realtime_enabled;
  `;

  const managementHeaders = {
    Authorization: `Bearer ${env.SUPABASE_ACCESS_TOKEN}`,
    "Content-Type": "application/json",
  };
  const endpoint =
    "https://api.supabase.com/v1/projects/baawmjlqabktngalbobf/database/query";
  const structureResponse = await fetch(endpoint, {
    method: "POST",
    headers: managementHeaders,
    body: JSON.stringify({ query: structureQuery }),
  });
  if (!structureResponse.ok) {
    throw new Error(
      `Database structure query failed: ${structureResponse.status}`,
    );
  }
  Object.assign(databaseSecurity, (await structureResponse.json())[0] || {});

  const functionalQuery = `
    begin;
    do $test$
    declare
      recipient_profile uuid;
      recipient_user uuid;
      actor_profile uuid := uuid_generate_v4();
      organization_profile uuid := uuid_generate_v4();
      connection_id uuid;
      conversation_id uuid := uuid_generate_v4();
      verification_id uuid;
      claim_id uuid;
      notification_id uuid;
      inbox jsonb;
      suffix text := replace(uuid_generate_v4()::text, '-', '');
    begin
      select p.id, p.user_id
      into recipient_profile, recipient_user
      from platform_staff staff
      join profiles p
        on p.user_id=staff.user_id
       and p.profile_type='person'
      where staff.is_active
        and staff.staff_role in ('super_admin','verifier')
      order by p.created_at
      limit 1;

      if recipient_profile is null or recipient_user is null then
        raise exception 'notification_test_requires_active_staff_profile';
      end if;

      insert into profiles(id,profile_type,display_name,slug)
      values
        (actor_profile,'person','Notification test member','notification-test-member-'||suffix),
        (organization_profile,'organization','Notification test club','notification-test-club-'||suffix);

      insert into connections(
        requester_profile_id,receiver_profile_id,status,connection_type
      )
      values(actor_profile,recipient_profile,'pending','professional')
      returning id into connection_id;

      insert into conversations(
        id,created_by_profile_id,conversation_type,direct_key
      )
      values(
        conversation_id,
        actor_profile,
        'direct',
        'notification-test-'||suffix
      );

      insert into conversation_participants(
        conversation_id,profile_id,role
      )
      values
        (conversation_id,actor_profile,'member'),
        (conversation_id,recipient_profile,'member');

      insert into messages(
        conversation_id,sender_profile_id,body,message_type
      )
      values(
        conversation_id,
        actor_profile,
        'Transactional notification test',
        'text'
      );

      insert into identity_verification_requests(
        profile_id,
        verification_type,
        legal_first_name,
        legal_last_name,
        country_code,
        document_type,
        document_path,
        status
      )
      values(
        actor_profile,
        'identity',
        'Notification',
        'Test',
        'FR',
        'passport',
        'notification-tests/'||suffix||'/passport.pdf',
        'submitted'
      )
      returning id into verification_id;

      insert into claims(
        claimant_profile_id,
        target_profile_id,
        claim_type,
        status,
        message,
        organization_role,
        contact_email
      )
      values(
        actor_profile,
        organization_profile,
        'club_ownership',
        'submitted',
        'Transactional notification test for a club claim.',
        'President',
        'notification-test@example.invalid'
      )
      returning id into claim_id;

      if not exists (
        select 1
        from notifications
        where recipient_profile_id=recipient_profile
          and notification_type='connection_request'
          and entity_id=connection_id
      ) then raise exception 'missing_connection_request_notification';
      end if;

      if not exists (
        select 1
        from notifications
        where recipient_profile_id=recipient_profile
          and notification_type='direct_message'
          and entity_id=conversation_id
      ) then raise exception 'missing_message_notification';
      end if;

      if not exists (
        select 1
        from notifications
        where recipient_profile_id=recipient_profile
          and notification_type='verification_submitted'
          and entity_id=verification_id
      ) then raise exception 'missing_verification_staff_notification';
      end if;

      if not exists (
        select 1
        from notifications
        where recipient_profile_id=recipient_profile
          and notification_type='club_claim_submitted'
          and entity_id=claim_id
      ) then raise exception 'missing_club_claim_staff_notification';
      end if;

      update connections
      set status='accepted',accepted_at=now()
      where id=connection_id;

      update identity_verification_requests
      set status='needs_information',
          reviewer_notes='Please provide a clearer document.',
          reviewed_by=recipient_user,
          reviewed_at=now()
      where id=verification_id;

      update claims
      set status='reviewing',
          reviewer_notes='Review in progress.',
          reviewed_by_user_id=recipient_user,
          reviewed_at=now()
      where id=claim_id;

      if (
        select count(*)
        from notifications
        where recipient_profile_id=actor_profile
          and notification_type in (
            'connection_status',
            'verification_status',
            'club_claim_status'
          )
      ) <> 3 then raise exception 'missing_member_status_notifications';
      end if;

      perform set_config(
        'request.jwt.claim.sub',
        recipient_user::text,
        true
      );
      inbox := get_member_notifications_v2('unread',30,0);
      if coalesce((inbox->>'unread')::integer,0) < 4 then
        raise exception 'inbox_unread_count_is_incorrect';
      end if;

      select id
      into notification_id
      from notifications
      where recipient_profile_id=recipient_profile
        and read_at is null
      order by created_at desc
      limit 1;

      perform mark_member_notification_read(notification_id);
      if not exists (
        select 1 from notifications
        where id=notification_id and read_at is not null
      ) then raise exception 'single_notification_was_not_marked_read';
      end if;

      perform mark_member_notifications_read();
      if exists (
        select 1 from notifications
        where recipient_profile_id=recipient_profile
          and read_at is null
      ) then raise exception 'mark_all_did_not_clear_unread_notifications';
      end if;
    end
    $test$;
    rollback;
  `;

  const functionalResponse = await fetch(endpoint, {
    method: "POST",
    headers: managementHeaders,
    body: JSON.stringify({ query: functionalQuery }),
  });
  if (!functionalResponse.ok) {
    const detail = await functionalResponse.text();
    throw new Error(
      `Functional notification transaction failed: ${functionalResponse.status} ${detail}`,
    );
  }
  functionalTransaction = true;
}

const result = {
  pages,
  anonymousSecurity,
  databaseSecurity,
  functionalTransaction,
};
console.log(JSON.stringify(result, null, 2));

const pageFailure = pages.some((page) =>
  Object.values(page.checks).some((value) => value === false),
);
const anonymousFailure = Object.values(anonymousSecurity).some(
  (value) => value === false,
);
const databaseFailure = Object.values(databaseSecurity).some(
  (value) => value === false,
);
if (
  pageFailure ||
  anonymousFailure ||
  databaseFailure ||
  !functionalTransaction
) {
  process.exitCode = 1;
}
