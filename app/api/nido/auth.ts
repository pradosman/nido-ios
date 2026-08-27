import { and, eq } from "drizzle-orm";
import { getDb } from "../../../db";
import { caregivers, caregiverTokens } from "../../../db/schema";

export type AuthenticatedCaregiver = {
  id: string;
  name: string;
  role: "owner" | "caregiver";
};

export function createAccessToken() {
  return `${crypto.randomUUID()}${crypto.randomUUID().replaceAll("-", "")}`;
}

export async function hashAccessToken(token: string) {
  const bytes = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
}

export async function requireCaregiver(request: Request, ownerOnly = false): Promise<
  { caregiver: AuthenticatedCaregiver; response?: never } | { caregiver?: never; response: Response }
> {
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
  if (!token) {
    return { response: Response.json({ error: "Este iPhone no tiene acceso al nido" }, { status: 401 }) };
  }

  const tokenHash = await hashAccessToken(token);
  const [caregiver] = await getDb().select({
    id: caregivers.id,
    name: caregivers.name,
    role: caregivers.role,
  }).from(caregivers).innerJoin(caregiverTokens, eq(caregivers.id, caregiverTokens.caregiverId)).where(and(
    eq(caregiverTokens.tokenHash, tokenHash),
    eq(caregivers.status, "active"),
  )).limit(1);

  if (!caregiver) {
    return { response: Response.json({ error: "El acceso ha caducado o ya no es válido" }, { status: 401 }) };
  }
  if (ownerOnly && caregiver.role !== "owner") {
    return { response: Response.json({ error: "Solo el cuidador principal puede hacer este cambio" }, { status: 403 }) };
  }
  return { caregiver };
}

export const publicCaregiverFields = {
  id: caregivers.id,
  name: caregivers.name,
  role: caregivers.role,
  status: caregivers.status,
  inviteCode: caregivers.inviteCode,
  createdAt: caregivers.createdAt,
  joinedAt: caregivers.joinedAt,
};
