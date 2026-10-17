import assert from "node:assert/strict";
import test from "node:test";

import { requestLegalPage } from "./support/legal-page-request.mjs";

const originalEnvironment = {
  controller: process.env.NIDO_PRIVACY_CONTROLLER,
  email: process.env.NIDO_SUPPORT_EMAIL,
};

function setEnvironment({ controller, email }) {
  if (controller === undefined) delete process.env.NIDO_PRIVACY_CONTROLLER;
  else process.env.NIDO_PRIVACY_CONTROLLER = controller;
  if (email === undefined) delete process.env.NIDO_SUPPORT_EMAIL;
  else process.env.NIDO_SUPPORT_EMAIL = email;
}

test.after(() => {
  setEnvironment(originalEnvironment);
});

test("privacy page is unavailable until real controller and support email are configured", async () => {
  setEnvironment({});
  const response = await requestLegalPage("/api/nido/legal/privacy");
  assert.equal(response.status, 503);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html; charset=utf-8$/);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.doesNotMatch(await response.text(), /NIDO_PRIVACY_CONTROLLER|NIDO_SUPPORT_EMAIL|example\.com/i);
});

test("privacy page publishes the declared data practices and safely encodes contact links", async () => {
  setEnvironment({ controller: "Nido <Responsable & familia>", email: "ayuda+privacidad?tema&filtro@nido.es" });
  const response = await requestLegalPage("/api/nido/legal/privacy");
  const html = await response.text();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html; charset=utf-8$/);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.match(html, /Nido &lt;Responsable &amp; familia&gt;/);
  assert.doesNotMatch(html, /<Responsable/);
  assert.match(html, /mailto:ayuda%2Bprivacidad%3Ftema%26filtro@nido\.es/);
  assert.match(html, /Apple/);
  assert.match(html, /fecha de nacimiento/);
  assert.match(html, /notas de salud/);
  assert.match(html, /no incluye publicidad ni seguimiento publicitario/);
  assert.match(html, /persona propietaria elimina su cuenta, se elimina el hogar/i);
  assert.match(html, /sin atribuirse a esa persona/i);
  assert.match(html, /exportación de datos se inicia/i);
  assert.doesNotMatch(html, /<script\b|onerror\s*=|onload\s*=/i);
});

test("support page is public, safely links to the configured contact, and reflects no auth data", async () => {
  setEnvironment({ controller: "Responsable Nido", email: "soporte+nido@nido.es" });
  const request = new Request("https://nido.test/api/nido/legal/support", {
    headers: { authorization: "Bearer must-not-be-reflected", cookie: "session=must-not-be-reflected" },
  });
  const response = await requestLegalPage("/api/nido/legal/support", request);
  const html = await response.text();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html; charset=utf-8$/);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.match(html, /mailto:soporte%2Bnido@nido\.es/);
  assert.match(html, /emergencias médicas/i);
  assert.doesNotMatch(html, /must-not-be-reflected/);
  assert.doesNotMatch(html, /<script\b|onerror\s*=|onload\s*=/i);
});

test("legal pages fail closed for invalid contact configuration", async () => {
  setEnvironment({ controller: "Nombre del responsable (pendiente)", email: "not-an-email" });
  assert.equal((await requestLegalPage("/api/nido/legal/privacy")).status, 503);
  assert.equal((await requestLegalPage("/api/nido/legal/support")).status, 503);
});

test("legal pages do not publish reserved example addresses or placeholder identities", async () => {
  setEnvironment({ controller: "Nido <Equipo>", email: "support@example.com" });
  assert.equal((await requestLegalPage("/api/nido/legal/privacy")).status, 503);
  setEnvironment({ controller: "Nombre de la empresa", email: "soporte@nido.es" });
  assert.equal((await requestLegalPage("/api/nido/legal/support")).status, 503);
  setEnvironment({ controller: "Responsable\nNido", email: "soporte@nido.es" });
  assert.equal((await requestLegalPage("/api/nido/legal/privacy")).status, 503);
});
