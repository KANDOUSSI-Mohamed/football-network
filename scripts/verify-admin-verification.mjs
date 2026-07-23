import { readFile } from "node:fs/promises";
import process from "node:process";
import worker from "../sites/football-network-worker.js";

function parseEnv(content) {
  return Object.fromEntries(content.split(/\r?\n/).filter((line) => line.includes("=")).map((line) => {
    const index = line.indexOf("=");
    return [line.slice(0, index).trim(), line.slice(index + 1).trim()];
  }));
}

const env = parseEnv(await readFile(".env.local", "utf8"));
const locales = ["fr", "en", "es", "it", "pt", "de", "nl", "ar", "tr"];
const pages = [];

for (const locale of locales) {
  const response = await worker.fetch(new Request(`https://football-network.test/${locale}/admin`), env);
  const html = await response.text();
  const script = html.match(/<script>([\s\S]*)<\/script>/)?.[1];
  const checks = {
    status: response.status === 200,
    noStore: response.headers.get("cache-control") === "private, no-store",
    console: html.includes("data-admin-console") && html.includes("data-admin-workspace"),
    identityReview: html.includes("review_identity_verification"),
    clubReview: html.includes("review_club_claim"),
    queue: html.includes("/rest/v1/rpc/get_admin_review_queue"),
    audit: html.includes("/rest/v1/rpc/get_admin_review_audit"),
    privateDocument: html.includes("/storage/v1/object/sign/identity-verification/"),
    staffNavigation: html.includes("/rest/v1/rpc/is_platform_staff") && html.includes("staff-admin-link"),
    fixedLayout: html.includes("grid-template-columns:260px minmax(590px,1fr) 300px"),
    localized: locale !== "fr" || html.includes("Administration des vérifications"),
    rtl: locale !== "ar" || html.includes('dir="rtl"'),
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

const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const anonymousSecurity = {};

if (supabaseUrl && anonKey) {
  const headers = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    "Content-Type": "application/json",
  };
  const calls = {
    dashboard: ["get_admin_verification_dashboard", {}],
    queue: ["get_admin_review_queue", { p_kind: "identity" }],
    audit: ["get_admin_review_audit", { p_entity_type: "identity", p_entity_id: "00000000-0000-0000-0000-000000000000" }],
    identityDecision: ["review_identity_verification", { target_request: "00000000-0000-0000-0000-000000000000", decision: "approve" }],
    clubDecision: ["review_club_claim", { target_claim: "00000000-0000-0000-0000-000000000000", decision: "approve" }],
  };
  for (const [name, [rpc, body]] of Object.entries(calls)) {
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${rpc}`, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    });
    anonymousSecurity[`${name}RejectsAnonymous`] = !response.ok;
  }
}

const databaseSecurity = {};
if (env.SUPABASE_ACCESS_TOKEN) {
  const query = `
    select
      to_regclass('public.platform_staff') is not null as staff_table,
      to_regclass('public.verification_audit_log') is not null as audit_table,
      to_regclass('public.organization_memberships') is not null as memberships_table,
      coalesce((select relrowsecurity from pg_class where oid='public.platform_staff'::regclass),false) as staff_rls,
      coalesce((select relrowsecurity from pg_class where oid='public.verification_audit_log'::regclass),false) as audit_rls,
      has_function_privilege('authenticated','public.get_admin_review_queue(text,text,text,text,integer,integer)','EXECUTE') as authenticated_queue,
      not has_function_privilege('anon','public.get_admin_review_queue(text,text,text,text,integer,integer)','EXECUTE') as anon_no_queue,
      not has_table_privilege('authenticated','public.verification_audit_log','INSERT') as audit_no_direct_insert,
      exists (
        select 1 from pg_policies
        where schemaname='storage' and tablename='objects'
          and policyname='Staff read verification documents'
      ) as private_document_policy;
  `;
  const response = await fetch("https://api.supabase.com/v1/projects/baawmjlqabktngalbobf/database/query", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SUPABASE_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query }),
  });
  if (!response.ok) throw new Error(`Database security query failed: ${response.status}`);
  Object.assign(databaseSecurity, (await response.json())[0] || {});
}

const result = { pages, anonymousSecurity, databaseSecurity };
console.log(JSON.stringify(result, null, 2));

const pageFailure = pages.some((page) => Object.values(page.checks).some((value) => value === false));
const anonymousFailure = Object.values(anonymousSecurity).some((value) => value === false);
const databaseFailure = Object.values(databaseSecurity).some((value) => value === false);
if (pageFailure || anonymousFailure || databaseFailure) process.exitCode = 1;
