export class BodyTooLargeError extends Error {}

async function discardBody(body: ReadableStream<Uint8Array> | null) {
  if (!body) return;
  const reader = body.getReader();
  while (!(await reader.read()).done) {
    // Drain without retaining bytes so the runtime can safely reuse the worker.
  }
}

export async function readJsonObject(request: Request, maximumBytes: number): Promise<Record<string, unknown> | null> {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    await discardBody(request.body);
    throw new BodyTooLargeError();
  }
  if (!request.body) return {};

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maximumBytes) {
      while (!(await reader.read()).done) {
        // Drain the remainder without retaining it.
      }
      throw new BodyTooLargeError();
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    const value = JSON.parse(new TextDecoder().decode(bytes));
    return value !== null && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

export function bodyErrorResponse(error: unknown) {
  return error instanceof BodyTooLargeError
    ? Response.json({ error: "Request body is too large" }, { status: 413 })
    : null;
}

export function boundedString(value: unknown, maximumLength: number) {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 && normalized.length <= maximumLength ? normalized : null;
}

export function isoDate(value: unknown) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value ? null : value;
}

export function boundedOptionalString(value: unknown, maximumLength: number) {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length <= maximumLength ? normalized : null;
}

export function boundedInteger(value: unknown, minimum: number, maximum: number, nullable = false) {
  if (nullable && (value === undefined || value === null)) return null;
  return typeof value === "number" && Number.isInteger(value) && value >= minimum && value <= maximum
    ? value
    : undefined;
}

export function recentBirthDate(value: unknown, now = Date.now()) {
  const date = isoDate(value);
  if (!date) return null;
  const today = new Date(now).toISOString().slice(0, 10);
  const earliest = new Date(now - 10 * 365.25 * 24 * 60 * 60 * 1_000).toISOString().slice(0, 10);
  return date >= earliest && date <= today ? date : null;
}
