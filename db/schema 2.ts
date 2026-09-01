import { sql } from "drizzle-orm";
import { foreignKey, index, integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

export const households = sqliteTable("households", {
  id: text("id").primaryKey(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const users = sqliteTable("users", {
  id: text("id").primaryKey(),
  appleSubject: text("apple_subject").notNull().unique(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const profiles = sqliteTable("profiles", {
  householdId: text("household_id").primaryKey().references(() => households.id, { onDelete: "cascade" }),
  caregiverName: text("caregiver_name").notNull(),
  babyName: text("baby_name").notNull(),
  birthDate: text("birth_date").notNull(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const entries = sqliteTable("entries", {
  id: text("id").primaryKey(),
  householdId: text("household_id").notNull().references(() => households.id, { onDelete: "cascade" }),
  kind: text("kind", { enum: ["sleep", "feed", "diaper", "health"] }).notNull(),
  title: text("title").notNull(),
  detail: text("detail").notNull().default(""),
  occurredAt: integer("occurred_at").notNull(),
  durationMinutes: integer("duration_minutes"),
  amountMl: integer("amount_ml"),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
}, (table) => [
  index("idx_entries_household_occurred_at_id").on(table.householdId, table.occurredAt, table.id),
  uniqueIndex("uq_entries_household_id").on(table.householdId, table.id),
]);

export const caregivers = sqliteTable("caregivers", {
  id: text("id").primaryKey(),
  householdId: text("household_id").notNull().references(() => households.id, { onDelete: "cascade" }),
  userId: text("user_id").unique().references(() => users.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  role: text("role", { enum: ["owner", "caregiver"] }).notNull().default("caregiver"),
  status: text("status", { enum: ["pending", "active", "removed"] }).notNull().default("pending"),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  joinedAt: text("joined_at"),
}, (table) => [
  index("idx_caregivers_household_status").on(table.householdId, table.status),
  uniqueIndex("uq_caregivers_household_id").on(table.householdId, table.id),
]);

export const authChallenges = sqliteTable("auth_challenges", {
  id: text("id").primaryKey(),
  nonceHash: text("nonce_hash").notNull(),
  expiresAt: integer("expires_at").notNull(),
  consumedAt: integer("consumed_at"),
  createdAt: integer("created_at").notNull(),
}, (table) => [
  index("idx_auth_challenges_expires").on(table.expiresAt),
]);

export const authSessions = sqliteTable("auth_sessions", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  challengeId: text("challenge_id").unique().references(() => authChallenges.id, { onDelete: "set null" }),
  tokenHash: text("token_hash").notNull().unique(),
  expiresAt: integer("expires_at").notNull(),
  revokedAt: integer("revoked_at"),
  createdAt: integer("created_at").notNull(),
}, (table) => [
  index("idx_auth_sessions_user_active").on(table.userId, table.revokedAt, table.expiresAt),
]);

export const invitations = sqliteTable("invitations", {
  id: text("id").primaryKey(),
  caregiverId: text("caregiver_id").notNull().unique().references(() => caregivers.id, { onDelete: "cascade" }),
  codeHash: text("code_hash").notNull().unique(),
  expiresAt: integer("expires_at").notNull(),
  consumedAt: integer("consumed_at"),
  failedAttempts: integer("failed_attempts").notNull().default(0),
  createdAt: integer("created_at").notNull(),
}, (table) => [
  index("idx_invitations_expires").on(table.expiresAt),
]);

export const invitationClaims = sqliteTable("invitation_claims", {
  invitationId: text("invitation_id").primaryKey().references(() => invitations.id, { onDelete: "cascade" }),
  userId: text("user_id").notNull().unique().references(() => users.id, { onDelete: "cascade" }),
  claimedAt: integer("claimed_at").notNull(),
});

export const authRateLimits = sqliteTable("auth_rate_limits", {
  key: text("key").primaryKey(),
  windowStartedAt: integer("window_started_at").notNull(),
  attempts: integer("attempts").notNull(),
});

export const entryAuthors = sqliteTable("entry_authors", {
  entryId: text("entry_id").primaryKey(),
  householdId: text("household_id").notNull().references(() => households.id, { onDelete: "cascade" }),
  caregiverId: text("caregiver_id").notNull(),
  caregiverName: text("caregiver_name").notNull(),
}, (table) => [
  index("idx_entry_authors_household_caregiver").on(table.householdId, table.caregiverId),
  foreignKey({
    columns: [table.householdId, table.entryId],
    foreignColumns: [entries.householdId, entries.id],
  }).onDelete("cascade"),
]);
