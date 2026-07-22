import { readFile } from "node:fs/promises";
import process from "node:process";

function parseEnv(content) {
  return Object.fromEntries(content.split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#") && line.includes("="))
    .map((line) => {
      const index = line.indexOf("=");
      return [line.slice(0, index), line.slice(index + 1).replace(/^['"]|['"]$/g, "")];
    }));
}

let localEnv = {};
try { localEnv = parseEnv(await readFile(".env.local", "utf8")); } catch {}
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || localEnv.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || localEnv.NEXT_PUBLIC_SUPABASE_ANON_KEY;
if (!supabaseUrl || !anonKey) throw new Error("Supabase public configuration is missing.");

async function rpc(name, body) {
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let data = text;
  try { data = text ? JSON.parse(text) : null; } catch {}
  return { ok: response.ok, status: response.status, data };
}

const countries = await rpc("get_club_directory_countries", {});
const search = await rpc("search_clubs_v2", {
  p_query: "Amicale sportive muretaine",
  p_country: "FR",
  p_city: "",
  p_postal_code: "",
  p_club_type: "",
  p_claim_status: "",
  p_followed_only: false,
  p_limit: 5,
  p_offset: 0,
});
const importedClub = search.data?.results?.[0];
const detail = importedClub ? await rpc("get_club_detail", { target_slug: importedClub.slug }) : { ok: false, data: null };
const protectedImport = await rpc("import_club_records", {
  p_job_id: "00000000-0000-0000-0000-000000000000",
  p_source_slug: "wikidata",
  p_country_code: "FR",
  p_country_name: "France",
  p_records: [],
});

const checks = {
  countriesPublic: countries.ok && Array.isArray(countries.data) && countries.data.some((item) => item.code === "FR"),
  importedClubSearchable: search.ok && Number(search.data?.total || 0) >= 1,
  sparseDetailPublic: detail.ok && detail.data?.official_name === "Amicale sportive muretaine",
  sourceVisible: detail.ok && detail.data?.source_attributions?.some((item) => item.name === "Wikidata" && item.license_name === "CC0 1.0"),
  importServiceOnly: !protectedImport.ok,
};

console.log(JSON.stringify({ checks, countryCounts: countries.data, statuses: {
  countries: countries.status,
  search: search.status,
  detail: detail.status,
  protectedImport: protectedImport.status,
} }, null, 2));
if (Object.values(checks).some((value) => !value)) process.exitCode = 1;
