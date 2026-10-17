import { readFile, writeFile } from "node:fs/promises";
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

export function sanitizeLogText(text, secrets = []) {
  let sanitized = String(text);
  for (const secret of secrets) {
    if (typeof secret === "string" && secret.length > 0) {
      sanitized = sanitized.replaceAll(secret, "[REDACTED]");
    }
  }
  sanitized = sanitized
    .replace(/(\bBearer\s+)[A-Za-z0-9._~+/-]+/gi, "$1[REDACTED]")
    .replace(/(TEST_RUNNER_NIDO_UI_TEST_[A-Z_]*TOKEN\s*=\s*['"]?)[^'"\s]+/g, "$1[REDACTED]");
  return sanitized;
}

async function readSecrets(path) {
  if (!path) return [];
  let contents;
  try {
    contents = await readFile(path, "utf8");
  } catch {
    return [];
  }
  return contents.split(/\r?\n/).map(line => {
    const separator = line.indexOf("=");
    const value = separator >= 0 ? line.slice(separator + 1) : line;
    return value.replace(/^['"]|['"]$/g, "");
  }).filter(Boolean);
}

if (process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))) {
  const [, , source, destination, ...secretFiles] = process.argv;
  if (!source || !destination) {
    process.stderr.write("Usage: node sanitize-ui-test-log.mjs SOURCE DESTINATION [SECRET_FILE ...]\n");
    process.exitCode = 2;
  } else {
    const [contents, ...secrets] = await Promise.all([
      readFile(source, "utf8"),
      ...secretFiles.map(readSecrets),
    ]);
    await writeFile(destination, sanitizeLogText(contents, secrets.flat()), { mode: 0o600 });
  }
}
