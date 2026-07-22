import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { unzipSync } from "fflate";

const PROJECT_REF = process.env.SUPABASE_PROJECT_REF || "baawmjlqabktngalbobf";
const SUPABASE_URL = process.env.SUPABASE_URL || `https://${PROJECT_REF}.supabase.co`;
const MANAGEMENT_URL = "https://api.supabase.com/v1";
const DEFAULT_COUNTRIES = ["FR", "MA"];
const BATCH_SIZE = 500;

function parseArguments(argv) {
  const options = {
    countries: [],
    dataDir: path.resolve(process.cwd(), ".data", "geonames"),
    forceDownload: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--data-dir") {
      options.dataDir = path.resolve(argv[index + 1]);
      index += 1;
    } else if (argument === "--force-download") {
      options.forceDownload = true;
    } else if (!argument.startsWith("--")) {
      options.countries.push(argument.toUpperCase());
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }

  options.countries = options.countries.length ? options.countries : DEFAULT_COUNTRIES;
  for (const country of options.countries) {
    if (!/^[A-Z]{2}$/.test(country)) throw new Error(`Invalid ISO country code: ${country}`);
  }
  return options;
}

async function fetchWithRetry(url, options = {}, attempts = 5) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(url, options);
      if (response.ok) return response;
      const body = await response.text();
      lastError = new Error(`${response.status} ${response.statusText}: ${body.slice(0, 500)}`);
      if (response.status < 500 && response.status !== 429) throw lastError;
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, Math.min(1000 * 2 ** (attempt - 1), 10000)));
  }
  throw lastError;
}

async function resolveServiceRoleKey() {
  if (process.env.SUPABASE_SERVICE_ROLE_KEY) return process.env.SUPABASE_SERVICE_ROLE_KEY;
  const accessToken = process.env.SUPABASE_ACCESS_TOKEN;
  if (!accessToken) throw new Error("Set SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ACCESS_TOKEN before running the importer.");
  const response = await fetchWithRetry(`${MANAGEMENT_URL}/projects/${PROJECT_REF}/api-keys`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const keys = await response.json();
  const serviceKey = keys.find((entry) => String(entry.name || entry.type || "").toLowerCase().includes("service_role"));
  const value = serviceKey?.api_key || serviceKey?.key || serviceKey?.value;
  if (!value) throw new Error("The Supabase service-role key could not be resolved.");
  return value;
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
  const response = await fetchWithRetry(`${SUPABASE_URL}/rest/v1/data_sources?slug=eq.geonames&select=id&limit=1`, {
    headers: postgrestHeaders(serviceRoleKey),
  });
  const rows = await response.json();
  if (!rows[0]?.id) throw new Error("GeoNames is missing from data_sources. Apply the backbone migration first.");
  return rows[0].id;
}

async function countCountryRows(serviceRoleKey, sourceId, countryCode) {
  const response = await fetchWithRetry(
    `${SUPABASE_URL}/rest/v1/geographic_places?source_id=eq.${sourceId}&country_code=eq.${countryCode}&select=id`,
    { method: "HEAD", headers: postgrestHeaders(serviceRoleKey, { Prefer: "count=exact", Range: "0-0" }) }
  );
  const contentRange = response.headers.get("content-range") || "*/0";
  return Number(contentRange.split("/")[1]) || 0;
}

async function createImportJob(serviceRoleKey, sourceId, countryCode, metadata) {
  const response = await fetchWithRetry(`${SUPABASE_URL}/rest/v1/data_import_jobs`, {
    method: "POST",
    headers: postgrestHeaders(serviceRoleKey, { Prefer: "return=representation" }),
    body: JSON.stringify({
      source_id: sourceId,
      import_type: "postal_places",
      country_code: countryCode,
      status: "running",
      started_at: new Date().toISOString(),
      metadata,
    }),
  });
  const rows = await response.json();
  return rows[0].id;
}

async function updateImportJob(serviceRoleKey, jobId, patch) {
  await fetchWithRetry(`${SUPABASE_URL}/rest/v1/data_import_jobs?id=eq.${jobId}`, {
    method: "PATCH",
    headers: postgrestHeaders(serviceRoleKey, { Prefer: "return=minimal" }),
    body: JSON.stringify(patch),
  });
}

async function loadCountryArchive(countryCode, dataDir, forceDownload) {
  await mkdir(dataDir, { recursive: true });
  const archivePath = path.join(dataDir, `${countryCode}.zip`);
  let bytes;
  if (!forceDownload) {
    try {
      bytes = await readFile(archivePath);
    } catch {
      bytes = null;
    }
  }
  if (!bytes) {
    const sourceUrl = `https://download.geonames.org/export/zip/${countryCode}.zip`;
    const response = await fetchWithRetry(sourceUrl);
    bytes = Buffer.from(await response.arrayBuffer());
    await writeFile(archivePath, bytes);
  }
  const files = unzipSync(new Uint8Array(bytes));
  const entryName = Object.keys(files).find((name) => name.toUpperCase().endsWith(`${countryCode}.TXT`));
  if (!entryName) throw new Error(`${countryCode}.txt is missing from ${archivePath}`);
  return {
    sourceUrl: `https://download.geonames.org/export/zip/${countryCode}.zip`,
    archivePath,
    content: Buffer.from(files[entryName]).toString("utf8"),
  };
}

function nullable(value) {
  const trimmed = String(value || "").trim();
  return trimmed || null;
}

function numeric(value) {
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseGeoNames(content, countryCode, sourceId) {
  const records = new Map();
  let rowsRead = 0;
  let rowsRejected = 0;
  for (const line of content.split(/\r?\n/)) {
    if (!line.trim()) continue;
    rowsRead += 1;
    const fields = line.split("\t");
    if (fields.length < 11 || fields[0].toUpperCase() !== countryCode || !fields[2]?.trim()) {
      rowsRejected += 1;
      continue;
    }
    const stableIdentity = [countryCode, fields[1], fields[2], fields[4], fields[6], fields[8]]
      .map((value) => String(value || "").trim())
      .join("\t");
    const sourceKey = createHash("sha256").update(stableIdentity).digest("hex");
    records.set(sourceKey, {
      source_id: sourceId,
      source_key: sourceKey,
      country_code: countryCode,
      postal_code: nullable(fields[1]),
      place_name: fields[2].trim(),
      admin_name1: nullable(fields[3]),
      admin_code1: nullable(fields[4]),
      admin_name2: nullable(fields[5]),
      admin_code2: nullable(fields[6]),
      admin_name3: nullable(fields[7]),
      admin_code3: nullable(fields[8]),
      latitude: numeric(fields[9]),
      longitude: numeric(fields[10]),
      accuracy: numeric(fields[11]),
    });
  }
  return { records: [...records.values()], rowsRead, rowsRejected };
}

async function upsertBatches(serviceRoleKey, records) {
  for (let offset = 0; offset < records.length; offset += BATCH_SIZE) {
    const batch = records.slice(offset, offset + BATCH_SIZE);
    await fetchWithRetry(`${SUPABASE_URL}/rest/v1/geographic_places?on_conflict=source_id,source_key`, {
      method: "POST",
      headers: postgrestHeaders(serviceRoleKey, { Prefer: "resolution=merge-duplicates,return=minimal" }),
      body: JSON.stringify(batch),
    });
    process.stdout.write(`\r  ${Math.min(offset + BATCH_SIZE, records.length)}/${records.length}`);
  }
  process.stdout.write("\n");
}

async function importCountry(serviceRoleKey, sourceId, countryCode, options) {
  const archive = await loadCountryArchive(countryCode, options.dataDir, options.forceDownload);
  const parsed = parseGeoNames(archive.content, countryCode, sourceId);
  const before = await countCountryRows(serviceRoleKey, sourceId, countryCode);
  const jobId = await createImportJob(serviceRoleKey, sourceId, countryCode, {
    source_url: archive.sourceUrl,
    archive_name: path.basename(archive.archivePath),
    license: "CC BY 4.0",
  });
  try {
    console.log(`${countryCode}: importing ${parsed.records.length} unique postal places`);
    await upsertBatches(serviceRoleKey, parsed.records);
    const after = await countCountryRows(serviceRoleKey, sourceId, countryCode);
    const inserted = Math.max(0, after - before);
    const updated = Math.max(0, parsed.records.length - inserted);
    await updateImportJob(serviceRoleKey, jobId, {
      status: "completed",
      rows_read: parsed.rowsRead,
      rows_inserted: inserted,
      rows_updated: updated,
      rows_rejected: parsed.rowsRejected,
      finished_at: new Date().toISOString(),
    });
    return { countryCode, before, after, inserted, updated, rejected: parsed.rowsRejected };
  } catch (error) {
    await updateImportJob(serviceRoleKey, jobId, {
      status: "failed",
      rows_read: parsed.rowsRead,
      rows_rejected: parsed.rowsRejected,
      error_message: String(error.message || error).slice(0, 2000),
      finished_at: new Date().toISOString(),
    });
    throw error;
  }
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const serviceRoleKey = await resolveServiceRoleKey();
  const sourceId = await getDataSourceId(serviceRoleKey);
  const results = [];
  for (const countryCode of options.countries) {
    results.push(await importCountry(serviceRoleKey, sourceId, countryCode, options));
  }
  console.log(JSON.stringify({ projectRef: PROJECT_REF, results }, null, 2));
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
