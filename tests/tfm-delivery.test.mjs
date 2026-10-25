import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
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

// SHA-256 of the VPS IP, provider hostname and VPS identifier, so the
// identifiers themselves never appear in the public repository.
const forbiddenServerTokenHashes = new Set([
  "4a5c6631763c3f1c848d4dd3514c195630a2528047fa17d7f6440904a535f686",
  "5b81c6996aa8091cb34add923a202074f4aee7caeac026c6b2e859f4a70b9889",
  "faeb2897d4b2627030da170ebf2174dd29ab39f7a84ea02f1eaffc114642e1c5",
]);

function serverIdentifiersIn(root, paths) {
  const files = execFileSync("git", ["ls-files", "-z", "--", ...paths], { cwd: root, encoding: "utf8" }).split("\0").filter(Boolean);
  const found = [];
  for (const file of files) {
    const content = readFileSync(new URL(file, root));
    if (content.includes(0)) continue;
    for (const token of content.toString("utf8").match(/[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]/g) ?? []) {
      const candidates = [token, ...token.split(/[.-]/)];
      if (candidates.some((candidate) => forbiddenServerTokenHashes.has(createHash("sha256").update(candidate).digest("hex")))) {
        found.push(file);
        break;
      }
    }
  }
  return found;
}

test("public repository files do not disclose the VPS address or provider host", () => {
  const root = new URL(process.env.NIDO_TFM_SCAN_ROOT ? `file://${process.env.NIDO_TFM_SCAN_ROOT}/` : "../", import.meta.url);
  assert.deepEqual(serverIdentifiersIn(root, ["docs", "README.md", "tests"]), []);
});

test("README links the published TFM video", () => {
  const videoURL = "https://youtu.be/oEe47ZCtwVQ";
  assert.match(readme, /^\| Vídeo \| .*https:\/\/youtu\.be\/oEe47ZCtwVQ/m, "delivery table does not link the video");
  const videoSection = readme.split(/^## Vídeo$/m)[1]?.split(/^## /m)[0] ?? "";
  assert.ok(videoSection.includes(videoURL), "video section does not link the video");
  assert.doesNotMatch(videoSection, /pendiente de publicar/i);
});
