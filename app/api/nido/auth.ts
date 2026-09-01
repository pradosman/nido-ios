import { and, eq, gt, isNull, sql } from "drizzle-orm";
import { getDb } from "../../../db/index.ts";
import { authSessions, caregivers } from "../../../db/schema.ts";
import { randomSecret, sha256 } from "./crypto.ts";

export type AuthenticatedSession = {
  id: string;
  userId: string;
  expiresAt: Date;
};

export type AuthenticatedCaregiver = {
  id: string;
  userId: string;
  householdId: string;
  name: string;
  role: "owner" | "caregiver";
};

export function createSessionToken() {
  return randomSecret(32);
}

export const hashAccessToken = sha256;

function bearerToken(request: Request) {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return null;
  const token = authorization.slice(7).trim();
  return token.length >= 32 && token.length <= 256 ? token : null;
}

export async function requireSession(request: Request): Promise<
  { session: AuthenticatedSession; response?: never } | { session?: never; response: Response }
> {
  const token = bearerToken(request);
  if (!token) {
    return { response: Response.json({ error: "Authentication is required" }, { status: 401 }) };
  }
  const tokenHash = await hashAccessToken(token);
  const [session] = await getDb().select({
    id: authSessions.id,
    userId: authSessions.userId,
    expiresAt: authSessions.expiresAt,
  }).from(authSessions).where(and(
    eq(authSessions.tokenHash, tokenHash),
    isNull(authSessions.revokedAt),
    gt(authSessions.expiresAt, sql`transaction_timestamp()`),
  )).limit(1);
  if (!session) {
    return { response: Response.json({ error: "The session is expired or revoked" }, { status: 401 }) };
  }
  return { session };
}

export async function requireMembership(request: Request, ownerOnly = false): Promise<
  { session: AuthenticatedSession; caregiver: AuthenticatedCaregiver; response?: never }
  | { session?: never; caregiver?: never; response: Response }
> {
  const authorization = await requireSession(request);
  if (authorization.response) return authorization;
  const [caregiver] = await getDb().select({
    id: caregivers.id,
    userId: caregivers.userId,
    householdId: caregivers.householdId,
    name: caregivers.name,
    role: caregivers.role,
  }).from(caregivers).where(and(
    eq(caregivers.userId, authorization.session.userId),
    eq(caregivers.status, "active"),
  )).limit(1);
  if (!caregiver || !caregiver.userId) {
    return { response: Response.json({ error: "An active household membership is required" }, { status: 403 }) };
  }
  if (ownerOnly && caregiver.role !== "owner") {
    return { response: Response.json({ error: "Only the household owner can make this change" }, { status: 403 }) };
  }
  return { session: authorization.session, caregiver: { ...caregiver, userId: caregiver.userId } };
}

export const requireCaregiver = requireMembership;

export const publicCaregiverFields = {
  id: caregivers.id,
  name: caregivers.name,
  role: caregivers.role,
  status: caregivers.status,
  createdAt: caregivers.createdAt,
  joinedAt: caregivers.joinedAt,
};
