import assert from "node:assert/strict";
import { createServer } from "node:http";
import test from "node:test";

const paths = ["privacy", "support"];
const original = [process.env.NIDO_PRIVACY_CONTROLLER, process.env.NIDO_SUPPORT_EMAIL];
const server = createServer(async (request, response) => {
  const kind = paths.find(value => request.url === `/api/nido/legal/${value}`);
  if (!kind) { response.writeHead(404); response.end(); return; }
  try {
    const route = await import(`../app/api/nido/legal/${kind}/route.ts`);
    const result = route.GET();
    response.writeHead(result.status, Object.fromEntries(result.headers));
    response.end(await result.text());
  } catch (error) {
    if (error.code !== "ERR_MODULE_NOT_FOUND") throw error;
    response.writeHead(404); response.end();
  }
});
await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
const base = `http://127.0.0.1:${server.address().port}`;
test.after(async () => {
  await new Promise(resolve => server.close(resolve));
  for (const [index, key] of ["NIDO_PRIVACY_CONTROLLER", "NIDO_SUPPORT_EMAIL"].entries()) {
    if (original[index] === undefined) delete process.env[key]; else process.env[key] = original[index];
  }
});

for (const kind of paths) {
  test(`public ${kind} HTTP endpoint uses approved contact without environment overrides`, async () => {
    delete process.env.NIDO_PRIVACY_CONTROLLER;
    delete process.env.NIDO_SUPPORT_EMAIL;
    const response = await fetch(`${base}/api/nido/legal/${kind}`, { headers: { authorization: "Bearer never-reflect", cookie: "secret=never-reflect" } });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-type"), "text/html; charset=utf-8");
    assert.equal(response.headers.get("cache-control"), "no-store");
    const html = await response.text();
    assert.match(html, /David Prados Mancilla/);
    assert.match(html, /mailto:pradosman%40gmail\.com|mailto:pradosman@gmail\.com/);
    assert.doesNotMatch(html, /never-reflect|NIDO_APPLE_PRIVATE_KEY|<script\b/i);
  });
}
test("invalid explicit contact override remains unavailable", async () => {
  process.env.NIDO_PRIVACY_CONTROLLER = "Nombre del responsable (pendiente)";
  process.env.NIDO_SUPPORT_EMAIL = "not-an-email";
  for (const kind of paths) assert.equal((await fetch(`${base}/api/nido/legal/${kind}`)).status, 503);
});
test("public contact overrides are HTML-escaped", async () => {
  process.env.NIDO_PRIVACY_CONTROLLER = "Nido <Responsable & familia>";
  process.env.NIDO_SUPPORT_EMAIL = "ayuda+privacidad?tema&filtro@nido.es";
  const response = await fetch(`${base}/api/nido/legal/privacy`);
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Nido &lt;Responsable &amp; familia&gt;/);
  assert.match(html, /mailto:ayuda%2Bprivacidad%3Ftema%26filtro@nido\.es/);
  assert.doesNotMatch(html, /<Responsable/);
});

test("privacy accurately discloses retained shared records and author data on the production baseline", async () => {
  delete process.env.NIDO_PRIVACY_CONTROLLER;
  delete process.env.NIDO_SUPPORT_EMAIL;
  const response = await fetch(`${base}/api/nido/legal/privacy`);
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Los registros de cuidados compartidos y sus datos de autoría pueden permanecer en el hogar\./);
  assert.doesNotMatch(html, /sin atribuirse a esa persona|se anonimizan|se elimina(?:n)? (?:los )?datos de autoría/i);
});
