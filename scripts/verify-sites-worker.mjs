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
  const response = await worker.fetch(new Request(`https://football-network.test/${locale}/organizations`), env);
  const html = await response.text();
  const script = html.match(/<script>([\s\S]*)<\/script>/)?.[1];
  const checks = {
    status: response.status === 200,
    cityFilter: html.includes('name="city"') && html.includes('data-club-city-options'),
    postalFilter: html.includes('name="postal_code"'),
    globalSearchRpc: html.includes('/rest/v1/rpc/search_clubs_v2'),
    placeSearchRpc: html.includes('/rest/v1/rpc/search_places'),
    fixedLayout: html.includes('grid-template-columns:260px minmax(590px,1fr) 300px'),
    encoding: !html.includes("�"),
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

console.log(JSON.stringify(results, null, 2));
if (results.some((result) => Object.values(result.checks).some((value) => value === false))) process.exitCode = 1;
