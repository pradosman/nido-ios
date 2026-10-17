import { spawn } from "node:child_process";
import { realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

const SIGNAL_EXIT_CODES = Object.freeze({
  SIGHUP: 129,
  SIGINT: 130,
  SIGQUIT: 131,
  SIGKILL: 137,
  SIGTERM: 143,
});

export function runCommandWithTimeout(command, args = [], timeoutMs = 180_000) {
  if (typeof command !== "string" || command.length === 0) {
    throw new TypeError("command must be a non-empty string");
  }
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    throw new RangeError("timeoutMs must be a positive number");
  }

  return new Promise(resolve => {
    const detached = process.platform !== "win32";
    const child = spawn(command, args, { detached, stdio: "inherit" });
    let timedOut = false;
    let settled = false;
    let escalationTimer;
    const timeoutTimer = setTimeout(() => {
      timedOut = true;
      try {
        if (detached) process.kill(-child.pid, "SIGTERM");
        else child.kill("SIGTERM");
      } catch {
        try { child.kill("SIGTERM"); } catch {}
      }
      escalationTimer = setTimeout(() => {
        try {
          if (detached) process.kill(-child.pid, "SIGKILL");
          else child.kill("SIGKILL");
        } catch {}
      }, 5_000);
      escalationTimer.unref();
    }, timeoutMs);

    const finish = exitCode => {
      if (settled) return;
      settled = true;
      clearTimeout(timeoutTimer);
      if (escalationTimer) clearTimeout(escalationTimer);
      resolve(timedOut ? 124 : exitCode);
    };

    child.once("error", () => finish(127));
    child.once("close", (code, signal) => finish(code ?? SIGNAL_EXIT_CODES[signal] ?? 1));
  });
}

if (process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))) {
  const [timeoutArgument, command, ...args] = process.argv.slice(2);
  const timeoutMs = Number(timeoutArgument);
  if (!command || !Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    process.stderr.write("Usage: node run-command-with-timeout.mjs TIMEOUT_MS COMMAND [ARG ...]\n");
    process.exitCode = 2;
  } else {
    process.exitCode = await runCommandWithTimeout(command, args, timeoutMs);
  }
}
