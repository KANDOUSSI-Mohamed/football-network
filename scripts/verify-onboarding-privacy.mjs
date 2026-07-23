import { readFile } from "node:fs/promises";
import worker from "../sites/football-network-worker.js";

function parseEnv(content) {
  return Object.fromEntries(content.split(/\r?\n/).filter((line) => line.includes("=")).map((line) => {
    const index = line.indexOf("=");
    return [line.slice(0, index).trim(), line.slice(index + 1).trim()];
  }));
}

const env = parseEnv(await readFile(".env.local", "utf8"));
const locales = ["fr", "en", "es", "it", "pt", "de", "nl", "ar", "tr"];
const results = [];

for (const locale of locales) {
  const response = await worker.fetch(new Request(`https://football-network.test/${locale}/account`), env);
  const html = await response.text();
  const script = html.match(/<script>([\s\S]*)<\/script>/)?.[1];
  const checks = {
    status: response.status === 200,
    completeOnboarding: html.includes("/rest/v1/rpc/complete_member_onboarding"),
    legalIdentity: html.includes('name="legalFirstName"') && html.includes('name="legalLastName"') && html.includes('name="dateOfBirth"'),
    consent: html.includes('name="acceptTerms"') && html.includes('name="acceptPrivacy"'),
    privacyControls: html.includes("/rest/v1/rpc/save_profile_privacy") && html.includes('data-editor-panel="privacy"'),
    privateIdentity: html.includes("/rest/v1/rpc/save_private_identity"),
    verification: html.includes("/rest/v1/rpc/request_identity_verification") && html.includes("identity-verification"),
    verificationHistory: html.includes("/rest/v1/rpc/cancel_identity_verification"),
    messagingPrivacy: html.includes("message_permission"),
    fixedLayout: html.includes("grid-template-columns:260px minmax(590px,1fr) 300px"),
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
  results.push({ locale, checks });
}

const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const protectedChecks = {};

if (supabaseUrl && anonKey) {
  const headers = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    "Content-Type": "application/json",
  };
  const privateRead = await fetch(`${supabaseUrl}/rest/v1/member_private_profiles?select=profile_id&limit=1`, { headers });
  const verificationRead = await fetch(`${supabaseUrl}/rest/v1/identity_verification_requests?select=id&limit=1`, { headers });
  const onboardingRpc = await fetch(`${supabaseUrl}/rest/v1/rpc/complete_member_onboarding`, {
    method: "POST",
    headers,
    body: JSON.stringify({ payload: {} }),
  });
  const privateBody = privateRead.ok ? await privateRead.json() : null;
  const verificationBody = verificationRead.ok ? await verificationRead.json() : null;
  protectedChecks.privateIdentityRejectsAnonymous = !privateRead.ok || (Array.isArray(privateBody) && privateBody.length === 0);
  protectedChecks.verificationQueueRejectsAnonymous = !verificationRead.ok || (Array.isArray(verificationBody) && verificationBody.length === 0);
  protectedChecks.onboardingRejectsAnonymous = !onboardingRpc.ok;
}

console.log(JSON.stringify({ locales: results, protectedChecks }, null, 2));
const localeFailure = results.some((result) => Object.values(result.checks).some((value) => value === false));
const securityFailure = Object.values(protectedChecks).some((value) => value === false);
if (localeFailure || securityFailure) process.exitCode = 1;
