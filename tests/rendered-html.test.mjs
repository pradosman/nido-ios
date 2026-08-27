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

test("server-renders the Nido daily care experience", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /Nido/);
  assert.match(html, /Buenos días, Marcos/);
  assert.match(html, /Siesta en 42 min/);
  assert.match(html, /¿Qué acaba de pasar\?/);
  assert.match(html, /Historial/);
  assert.match(html, /Tendencias/);
  assert.doesNotMatch(html, /Your site is taking shape|codex-preview|Building your site/);
});

test("ships product metadata, local persistence, and a bespoke social card", async () => {
  const [page, app, layout, packageJson, image] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/NidoApp.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    stat(new URL("../public/og.png", import.meta.url)),
  ]);

  assert.match(page, /generateMetadata/);
  assert.match(page, /\/og\.png/);
  assert.match(layout, /lang="es"/);
  assert.match(app, /localStorage\.setItem\("nido-entries"/);
  assert.match(app, /nido-active-sleep/);
  assert.match(app, /no una recomendación médica/);
  assert.match(packageJson, /"lucide-react"/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.ok(image.size > 100_000, "social card should be a real raster asset");

  await assert.rejects(access(new URL("../app/_sites-preview/SkeletonPreview.tsx", import.meta.url)));
});
