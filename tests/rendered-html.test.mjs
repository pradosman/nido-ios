import assert from "node:assert/strict";
import { access, readFile, stat } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("https://nido.example/", { headers: { accept: "text/html", host: "nido.example", "x-forwarded-proto": "https" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("server-renders the private Nido loading state without demo data", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /Nido/);
  assert.match(html, /Preparando vuestro espacio/);
  assert.doesNotMatch(html, /Buenos días, Marcos|Siesta en 42 min|Leo · 4 meses/);
  assert.doesNotMatch(html, /Your site is taking shape|codex-preview|Building your site|sampleEntries/);
});

test("ships private persistence, onboarding, and a bespoke social card", async () => {
  const [page, app, layout, styles, packageJson, hosting, schema, image] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/NidoApp.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    stat(new URL("../public/og.png", import.meta.url)),
  ]);

  assert.match(page, /generateMetadata/);
  assert.match(page, /\/og\.png/);
  assert.match(layout, /lang="es"/);
  assert.match(app, /Un espacio para vuestro día a día/);
  assert.match(app, /fetch\("\/api\/nido"/);
  assert.match(app, /nido-active-sleep/);
  assert.match(app, /nunca recomendaciones médicas/);
  assert.match(app, /aria-current=\{active \? "page"/);
  assert.match(app, /className="mobile-chrome"/);
  assert.match(app, /className="mobile-greeting"/);
  assert.match(app, /from "reicon-react"/);
  assert.match(app, /weight=\{active \? "Filled" : "Outline"\}/);
  assert.doesNotMatch(app, /from "lucide-react"/);
  assert.doesNotMatch(app, /sampleEntries|weekSleep = \[12/);
  assert.match(styles, /-apple-system/);
  assert.match(styles, /@media \(hover: hover\) and \(pointer: fine\)/);
  assert.match(styles, /prefers-reduced-transparency/);
  assert.match(styles, /prefers-contrast: more/);
  assert.match(styles, /\.bottom-nav \{ position: fixed;[^}]*width: 100%/);
  assert.match(styles, /\.summary-list \{ grid-template-columns: repeat\(3, 1fr\)/);
  assert.match(styles, /transform: scale\(\.97\)/);
  assert.doesNotMatch(styles, /transition:\s*all\b/);
  assert.match(hosting, /"d1": "DB"/);
  assert.match(schema, /idx_entries_occurred_at/);
  assert.match(packageJson, /"lucide-react"/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.ok(image.size > 100_000, "social card should be a real raster asset");

  await assert.rejects(access(new URL("../app/_sites-preview/SkeletonPreview.tsx", import.meta.url)));
});

test("ships a persistent and private VPS deployment path", async () => {
  const [dockerfile, compose, dockerignore, wrangler, entrypoint, schema, caddy, readme] = await Promise.all([
    readFile(new URL("../Dockerfile", import.meta.url), "utf8"),
    readFile(new URL("../compose.vps.yml", import.meta.url), "utf8"),
    readFile(new URL("../.dockerignore", import.meta.url), "utf8"),
    readFile(new URL("../wrangler.vps.jsonc", import.meta.url), "utf8"),
    readFile(new URL("../deploy/entrypoint.sh", import.meta.url), "utf8"),
    readFile(new URL("../deploy/schema.sql", import.meta.url), "utf8"),
    readFile(new URL("../deploy/Caddyfile.example", import.meta.url), "utf8"),
    readFile(new URL("../README.md", import.meta.url), "utf8"),
  ]);

  assert.match(dockerfile, /VOLUME \["\/data"\]/);
  assert.match(compose, /expose:\s+- "3000"/);
  assert.doesNotMatch(compose, /ports:/);
  assert.match(compose, /nido-data:\/data/);
  assert.match(dockerignore, /^ios$/m);
  assert.match(wrangler, /"migrations_dir": "drizzle"/);
  assert.match(entrypoint, /d1 execute DB/);
  assert.match(entrypoint, /--persist-to "\$data_dir"/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS `entries`/);
  assert.match(schema, /CREATE INDEX IF NOT EXISTS `idx_entries_occurred_at`/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS `caregiver_tokens`/);
  assert.match(caddy, /nido\.momentumia\.com/);
  assert.doesNotMatch(caddy, /basic_auth/);
  assert.match(compose, /\/api\/nido\/status/);
  assert.match(readme, /app nativa para iPhone/);
  assert.match(readme, /Dokploy conecta Traefik al puerto interno `3000`/);
  assert.match(readme, /\| Path \| `\/api` \|/);
});
