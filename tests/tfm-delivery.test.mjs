import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const readme = readFileSync(new URL("../README.md", import.meta.url), "utf8");

const requiredSections = [
  "Descripción general",
  "Stack tecnológico",
  "Instalación y ejecución",
  "Estructura del proyecto",
  "Funcionalidades principales",
  "Usuario y contraseña de prueba",
  "Despliegue",
  "Presentación",
  "Vídeo",
];

test("README covers every section required by the TFM delivery", () => {
  for (const section of requiredSections) {
    assert.match(readme, new RegExp(`^##+ .*${section}`, "m"), `missing section: ${section}`);
  }
});

test("README links the public repository and the deployed API", () => {
  assert.match(readme, /https:\/\/github\.com\/pradosman\/nido-ios/);
  assert.match(readme, /https:\/\/nido\.momentumia\.com\/api\/nido\/status/);
});

test("TFM slides and video script are stored with the code and linked from the README", () => {
  for (const path of ["docs/tfm/presentacion-nido.pptx", "docs/tfm/presentacion-nido.pdf", "docs/tfm/guion-video.md"]) {
    assert.ok(existsSync(new URL(`../${path}`, import.meta.url)), `missing file: ${path}`);
    assert.ok(readme.includes(`(${path})`), `README does not link ${path}`);
  }
});

test("public documentation does not disclose the VPS address or provider host", async () => {
  const { execFileSync } = await import("node:child_process");
  const pattern = "148\\.230\\.108\\.174|srv943574|hstgr\\.cloud|VPS (Hostinger )?`?943574";
  let matches = "";
  try {
    matches = execFileSync("git", ["grep", "-nIE", pattern, "--", "docs", "README.md"], { encoding: "utf8" });
  } catch (error) {
    if (error.status !== 1) throw error;
  }
  assert.equal(matches, "", `server identifiers found:\n${matches}`);
});
