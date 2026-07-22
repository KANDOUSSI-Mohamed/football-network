import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const projectRef = process.env.SUPABASE_PROJECT_REF || "baawmjlqabktngalbobf";
const accessToken = process.env.SUPABASE_ACCESS_TOKEN;
const migrationPath = process.argv[2];

if (!accessToken) throw new Error("SUPABASE_ACCESS_TOKEN is required.");
if (!migrationPath) throw new Error("Usage: node scripts/apply-supabase-migration.mjs <migration.sql>");

const absolutePath = path.resolve(process.cwd(), migrationPath);
const query = await readFile(absolutePath, "utf8");
const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/database/query`, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${accessToken}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({ query }),
});

const body = await response.text();
if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${body}`);
console.log(JSON.stringify({ applied: path.basename(absolutePath), projectRef, response: body ? JSON.parse(body) : null }, null, 2));
