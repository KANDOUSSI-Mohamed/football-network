import { readFile } from "node:fs/promises";
import process from "node:process";

function parseEnv(content) {
  return Object.fromEntries(
    content.split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith("#") && line.includes("="))
      .map((line) => {
        const index = line.indexOf("=");
        return [line.slice(0, index), line.slice(index + 1).replace(/^['"]|['"]$/g, "")];
      })
  );
}

let localEnv = {};
try {
  localEnv = parseEnv(await readFile(".env.local", "utf8"));
} catch {
  localEnv = {};
}

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || localEnv.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || localEnv.NEXT_PUBLIC_SUPABASE_ANON_KEY;
if (!supabaseUrl || !anonKey) throw new Error("Supabase public configuration is missing.");

async function request(path, body) {
  const response = await fetch(`${supabaseUrl}${path}`, {
    method: body ? "POST" : "GET",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let data = text;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: response.status, ok: response.ok, data };
}

const places = await request("/rest/v1/rpc/search_places", { p_query: "Meknes", p_country: "MA", p_limit: 5 });
const clubs = await request("/rest/v1/rpc/search_clubs_v2", {
  p_query: "CODM",
  p_country: "MA",
  p_city: "Meknes",
  p_postal_code: "",
  p_club_type: "",
  p_claim_status: "",
  p_followed_only: false,
  p_limit: 10,
  p_offset: 0,
});
const rawTable = await request("/rest/v1/geographic_places?select=id&limit=1");
const attributions = await request("/rest/v1/rpc/get_data_attributions", {});

const checks = {
  placesPublic: places.ok && Array.isArray(places.data) && places.data.some((item) => String(item.place_name).toLowerCase() === "meknes"),
  clubsPublic: clubs.ok && clubs.data?.total === 1 && clubs.data?.results?.[0]?.slug === "codm-meknes",
  rawTableProtected: !rawTable.ok,
  attributionsPublic: attributions.ok && Array.isArray(attributions.data) && attributions.data.some((item) => item.slug === "geonames"),
};

console.log(JSON.stringify({ checks, statuses: {
  places: places.status,
  clubs: clubs.status,
  rawTable: rawTable.status,
  attributions: attributions.status,
} }, null, 2));

if (Object.values(checks).some((value) => !value)) process.exitCode = 1;
