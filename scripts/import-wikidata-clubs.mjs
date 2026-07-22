import process from "node:process";

const PROJECT_REF = process.env.SUPABASE_PROJECT_REF || "baawmjlqabktngalbobf";
const SUPABASE_URL = process.env.SUPABASE_URL || `https://${PROJECT_REF}.supabase.co`;
const MANAGEMENT_URL = "https://api.supabase.com/v1";
const WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql";
const USER_AGENT = "FootballNetworkBot/0.1 (+https://football-network.kandoussi.chatgpt.site)";
const DEFAULT_COUNTRIES = ["FR", "MA"];
const DEFAULT_PAGE_SIZE = 100;
const IMPORT_BATCH_SIZE = 100;

function parseArguments(argv) {
  const options = { countries: [], dryRun: false, limit: Infinity, pageSize: DEFAULT_PAGE_SIZE };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--dry-run") {
      options.dryRun = true;
    } else if (argument === "--limit") {
      options.limit = Number.parseInt(argv[index + 1], 10);
      index += 1;
    } else if (argument === "--page-size") {
      options.pageSize = Number.parseInt(argv[index + 1], 10);
      index += 1;
    } else if (!argument.startsWith("--")) {
      options.countries.push(argument.toUpperCase());
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  options.countries = options.countries.length ? [...new Set(options.countries)] : DEFAULT_COUNTRIES;
  if (!Number.isFinite(options.limit) && options.limit !== Infinity) throw new Error("--limit must be an integer.");
  if (options.limit !== Infinity && options.limit < 1) throw new Error("--limit must be greater than zero.");
  if (!Number.isInteger(options.pageSize) || options.pageSize < 10 || options.pageSize > 250) {
    throw new Error("--page-size must be between 10 and 250.");
  }
  for (const country of options.countries) {
    if (!/^[A-Z]{2}$/.test(country)) throw new Error(`Invalid ISO country code: ${country}`);
  }
  return options;
}

async function fetchWithRetry(url, options = {}, attempts = 6) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(url, options);
      if (response.ok) return response;
      const body = await response.text();
      lastError = new Error(`${response.status} ${response.statusText}: ${body.slice(0, 500)}`);
      if (response.status < 500 && response.status !== 429) throw lastError;
      const retryAfter = Number.parseInt(response.headers.get("retry-after") || "0", 10);
      if (retryAfter > 0) await new Promise((resolve) => setTimeout(resolve, retryAfter * 1000));
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, Math.min(1500 * 2 ** (attempt - 1), 20000)));
  }
  throw lastError;
}

function clubIdsQuery(countryEntityId, limit, offset) {
  return `
SELECT ?club WHERE {
  ?club wdt:P31 wd:Q476028;
        wdt:P17 wd:${countryEntityId}.
}
ORDER BY ?club
LIMIT ${limit}
OFFSET ${offset}`;
}

async function queryWikidata(query) {
  const response = await fetchWithRetry(WIKIDATA_ENDPOINT, {
    method: "POST",
    headers: {
      Accept: "application/sparql-results+json",
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
      "User-Agent": USER_AGENT,
    },
    body: new URLSearchParams({ query, format: "json" }),
  });
  return response.json();
}

async function getCountryName(countryCode) {
  return new Intl.DisplayNames(["fr"], { type: "region" }).of(countryCode) || countryCode;
}

async function resolveCountryEntityId(countryCode) {
  const known = { FR: "Q142", MA: "Q1028" };
  if (known[countryCode]) return known[countryCode];
  const data = await queryWikidata(`SELECT ?country WHERE { ?country wdt:P297 "${countryCode}". } LIMIT 1`);
  const id = value(data.results?.bindings?.[0], "country").match(/Q[0-9]+$/)?.[0];
  if (!id) throw new Error(`Wikidata country not found: ${countryCode}`);
  return id;
}

function value(binding, key) {
  return String(binding?.[key]?.value || "").trim();
}

async function fetchEntities(entityIds) {
  const entities = {};
  for (let offset = 0; offset < entityIds.length; offset += 50) {
    const batch = entityIds.slice(offset, offset + 50);
    const params = new URLSearchParams({
      action: "wbgetentities",
      ids: batch.join("|"),
      props: "labels|aliases|claims",
      languages: "fr|en|ar|es|pt|de|it|nl|tr",
      languagefallback: "1",
      format: "json",
      origin: "*",
    });
    const response = await fetchWithRetry(`https://www.wikidata.org/w/api.php?${params}`, {
      headers: { Accept: "application/json", "User-Agent": USER_AGENT },
    });
    const data = await response.json();
    if (data.error) throw new Error(`Wikidata entity API: ${data.error.info || data.error.code}`);
    Object.assign(entities, data.entities || {});
  }
  return entities;
}

function claimValues(entity, property) {
  return (entity?.claims?.[property] || [])
    .map((claim) => claim?.mainsnak?.datavalue?.value)
    .filter((item) => item !== null && item !== undefined);
}

function firstEntityId(entity, property) {
  return claimValues(entity, property).find((item) => typeof item === "object" && /^Q[0-9]+$/.test(item.id || ""))?.id || null;
}

function firstText(entity, property) {
  for (const item of claimValues(entity, property)) {
    if (typeof item === "string" && item.trim()) return item.trim();
    if (typeof item === "object" && typeof item.text === "string" && item.text.trim()) return item.text.trim();
  }
  return null;
}

function entityLabel(entity) {
  for (const locale of ["fr", "en", "ar", "es", "pt", "de", "it", "nl", "tr"]) {
    if (entity?.labels?.[locale]?.value) return entity.labels[locale].value;
  }
  return null;
}

function entityAliases(entity) {
  return [...new Set(["fr", "en", "ar", "es", "pt", "de", "it", "nl", "tr"]
    .flatMap((locale) => entity?.aliases?.[locale] || [])
    .map((item) => String(item?.value || "").trim())
    .filter(Boolean))];
}

function entityFoundedYear(entity) {
  const time = claimValues(entity, "P571").find((item) => typeof item === "object" && typeof item.time === "string")?.time || "";
  return time.match(/^\+?([0-9]{4})-/)?.[1] || null;
}

function entityCoordinates(entity) {
  const coordinate = claimValues(entity, "P625").find((item) => typeof item === "object" && Number.isFinite(item.latitude) && Number.isFinite(item.longitude));
  return coordinate ? { latitude: coordinate.latitude, longitude: coordinate.longitude } : { latitude: null, longitude: null };
}

async function loadClubRecords(entityIds) {
  const clubEntities = await fetchEntities(entityIds);
  const placeIds = [...new Set(entityIds.map((id) => {
    const entity = clubEntities[id];
    return firstEntityId(entity, "P131") || firstEntityId(entity, "P159");
  }).filter(Boolean))];
  const placeEntities = await fetchEntities(placeIds);
  const regionIds = [...new Set(placeIds.map((id) => firstEntityId(placeEntities[id], "P131")).filter(Boolean))];
  const regionEntities = await fetchEntities(regionIds);

  return entityIds.map((requestedId) => {
    const entity = clubEntities[requestedId];
    if (!entity || entity.missing !== undefined) return null;
    const externalId = entity.id || requestedId;
    const placeId = firstEntityId(entity, "P131") || firstEntityId(entity, "P159");
    const regionId = placeId ? firstEntityId(placeEntities[placeId], "P131") : null;
    return {
      external_id: externalId,
      name: entityLabel(entity),
      short_name: firstText(entity, "P1813"),
      aliases: entityAliases(entity),
      city: placeId ? entityLabel(placeEntities[placeId]) : null,
      region: regionId ? entityLabel(regionEntities[regionId]) : null,
      founded_year: entityFoundedYear(entity),
      website_url: firstText(entity, "P856"),
      source_url: `https://www.wikidata.org/wiki/${externalId}`,
      ...entityCoordinates(entity),
    };
  }).filter((record) => record?.external_id && record?.name);
}

async function fetchCountryClubs(countryCode, options) {
  const records = new Map();
  const countryEntityId = await resolveCountryEntityId(countryCode);
  let offset = 0;
  while (records.size < options.limit) {
    const requested = Math.min(options.pageSize, options.limit - records.size);
    const idData = await queryWikidata(clubIdsQuery(countryEntityId, requested, offset));
    const entityIds = (idData.results?.bindings || [])
      .map((binding) => value(binding, "club").match(/Q[0-9]+$/)?.[0])
      .filter(Boolean);
    if (!entityIds.length) break;
    const pageRecords = await loadClubRecords(entityIds);
    for (const record of pageRecords) records.set(record.external_id, record);
    process.stdout.write(`\r  ${countryCode}: ${records.size} clubs read`);
    offset += entityIds.length;
    if (entityIds.length < requested) break;
  }
  process.stdout.write("\n");
  return [...records.values()].slice(0, options.limit);
}

async function resolveServiceRoleKey() {
  if (process.env.SUPABASE_SERVICE_ROLE_KEY) return process.env.SUPABASE_SERVICE_ROLE_KEY;
  const accessToken = process.env.SUPABASE_ACCESS_TOKEN;
  if (!accessToken) throw new Error("Set SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ACCESS_TOKEN before importing.");
  const response = await fetchWithRetry(`${MANAGEMENT_URL}/projects/${PROJECT_REF}/api-keys`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const keys = await response.json();
  const serviceKey = keys.find((entry) => String(entry.name || entry.type || "").toLowerCase().includes("service_role"));
  const result = serviceKey?.api_key || serviceKey?.key || serviceKey?.value;
  if (!result) throw new Error("The Supabase service-role key could not be resolved.");
  return result;
}

function postgrestHeaders(serviceRoleKey, extra = {}) {
  return {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

async function getDataSourceId(serviceRoleKey) {
  const response = await fetchWithRetry(`${SUPABASE_URL}/rest/v1/data_sources?slug=eq.wikidata&select=id&limit=1`, {
    headers: postgrestHeaders(serviceRoleKey),
  });
  const rows = await response.json();
  if (!rows[0]?.id) throw new Error("Wikidata is missing from data_sources. Apply the catalogue migration first.");
  return rows[0].id;
}

async function createImportJob(serviceRoleKey, sourceId, countryCode, metadata) {
  const response = await fetchWithRetry(`${SUPABASE_URL}/rest/v1/data_import_jobs`, {
    method: "POST",
    headers: postgrestHeaders(serviceRoleKey, { Prefer: "return=representation" }),
    body: JSON.stringify({
      source_id: sourceId,
      import_type: "football_clubs",
      country_code: countryCode,
      status: "running",
      started_at: new Date().toISOString(),
      metadata,
    }),
  });
  const rows = await response.json();
  if (!rows[0]?.id) throw new Error("The import job could not be created.");
  return rows[0].id;
}

async function updateImportJob(serviceRoleKey, jobId, patch) {
  await fetchWithRetry(`${SUPABASE_URL}/rest/v1/data_import_jobs?id=eq.${jobId}`, {
    method: "PATCH",
    headers: postgrestHeaders(serviceRoleKey, { Prefer: "return=minimal" }),
    body: JSON.stringify(patch),
  });
}

async function importBatch(serviceRoleKey, jobId, countryCode, countryName, records) {
  const response = await fetchWithRetry(`${SUPABASE_URL}/rest/v1/rpc/import_club_records`, {
    method: "POST",
    headers: postgrestHeaders(serviceRoleKey),
    body: JSON.stringify({
      p_job_id: jobId,
      p_source_slug: "wikidata",
      p_country_code: countryCode,
      p_country_name: countryName,
      p_records: records,
    }),
  });
  return response.json();
}

async function importCountry(serviceRoleKey, sourceId, countryCode, countryName, records) {
  const jobId = await createImportJob(serviceRoleKey, sourceId, countryCode, {
    endpoint: WIKIDATA_ENDPOINT,
    source: "Wikidata Query Service",
    license: "CC0 1.0",
    requested_records: records.length,
  });
  const totals = { read: 0, created: 0, matched: 0, review: 0, rejected: 0 };
  try {
    for (let offset = 0; offset < records.length; offset += IMPORT_BATCH_SIZE) {
      const batch = records.slice(offset, offset + IMPORT_BATCH_SIZE);
      const result = await importBatch(serviceRoleKey, jobId, countryCode, countryName, batch);
      for (const key of Object.keys(totals)) totals[key] += Number(result[key] || 0);
      process.stdout.write(`\r  ${countryCode}: ${Math.min(offset + IMPORT_BATCH_SIZE, records.length)}/${records.length} imported`);
    }
    process.stdout.write("\n");
    await updateImportJob(serviceRoleKey, jobId, {
      status: "completed",
      rows_read: totals.read,
      rows_inserted: totals.created,
      rows_updated: totals.matched,
      rows_rejected: totals.rejected,
      metadata: {
        endpoint: WIKIDATA_ENDPOINT,
        source: "Wikidata Query Service",
        license: "CC0 1.0",
        requested_records: records.length,
        review_count: totals.review,
      },
      finished_at: new Date().toISOString(),
    });
    return { countryCode, countryName, jobId, ...totals };
  } catch (error) {
    await updateImportJob(serviceRoleKey, jobId, {
      status: "failed",
      rows_read: totals.read,
      rows_inserted: totals.created,
      rows_updated: totals.matched,
      rows_rejected: totals.rejected,
      error_message: String(error.message || error).slice(0, 2000),
      metadata: { endpoint: WIKIDATA_ENDPOINT, license: "CC0 1.0", review_count: totals.review },
      finished_at: new Date().toISOString(),
    });
    throw error;
  }
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const extracted = [];
  for (const countryCode of options.countries) {
    const countryName = await getCountryName(countryCode);
    const records = await fetchCountryClubs(countryCode, options);
    extracted.push({ countryCode, countryName, records });
  }

  if (options.dryRun) {
    console.log(JSON.stringify({
      dryRun: true,
      countries: extracted.map(({ countryCode, countryName, records }) => ({
        countryCode,
        countryName,
        count: records.length,
        sample: records.slice(0, 3),
      })),
    }, null, 2));
    return;
  }

  const serviceRoleKey = await resolveServiceRoleKey();
  const sourceId = await getDataSourceId(serviceRoleKey);
  const results = [];
  for (const country of extracted) {
    results.push(await importCountry(
      serviceRoleKey,
      sourceId,
      country.countryCode,
      country.countryName,
      country.records
    ));
  }
  console.log(JSON.stringify({ projectRef: PROJECT_REF, results }, null, 2));
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
