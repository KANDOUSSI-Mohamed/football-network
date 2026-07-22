import { copyFile, mkdir } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const dist = new URL("../dist/", import.meta.url);
await mkdir(new URL("server/", dist), { recursive: true });
await mkdir(new URL(".openai/", dist), { recursive: true });
await copyFile(new URL("sites/football-network-worker.js", root), new URL("server/index.js", dist));
await copyFile(new URL(".openai/hosting.json", root), new URL(".openai/hosting.json", dist));
console.log("Football Network Sites bundle created in dist/.");
