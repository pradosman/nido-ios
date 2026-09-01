import { sql } from "drizzle-orm";
import {
  bigint,
  check,
  foreignKey,
  index,
  integer,
  pgEnum,
  pgTable,
  primaryKey,
  text,
  timestamp,
  unique,
} from "drizzle-orm/pg-core";

const timestamps = {
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
};

export const entryKind = pgEnum("entry_kind", ["sleep", "feed", "diaper", "health"]);
export const caregiverRole = pgEnum("caregiver_role", ["owner", "caregiver"]);
export const caregiverStatus = pgEnum("caregiver_status", ["pending", "active", "removed"]);

export const households = pgTable("households", {
  id: text("id").primaryKey(),
  ...timestamps,
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const users = pgTable("users", {
  id: text("id").primaryKey(),
  appleSubject: text("apple_subject").notNull(),
  ...timestamps,
}, table => [unique("users_apple_subject_unique").on(table.appleSubject)]);

export const profiles = pgTable("profiles", {
  householdId: text("household_id").primaryKey().references(() => households.id, { onDelete: "cascade" }),
  caregiverName: text("caregiver_name").notNull(),
  babyName: text("baby_name").notNull(),
  birthDate: text("birth_date").notNull(),
  ...timestamps,
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
}, table => [
  check("profiles_birth_date_check", sql`${table.birthDate} ~ '^\\d{4}-\\d{2}-\\d{2}$'`),
]);

export const entries = pgTable("entries", {
  id: text("id").primaryKey(),
  householdId: text("household_id").notNull().references(() => households.id, { onDelete: "cascade" }),
  kind: entryKind("kind").notNull(),
  title: text("title").notNull(),
  detail: text("detail").notNull().default(""),
  occurredAt: bigint("occurred_at", { mode: "number" }).notNull(),
  durationMinutes: integer("duration_minutes"),
  amountMl: integer("amount_ml"),
  ...timestamps,
}, table => [
  unique("uq_entries_household_id").on(table.householdId, table.id),
  index("idx_entries_household_occurred_at_id").on(table.householdId, table.occurredAt, table.id),
  check("entries_duration_minutes_check", sql`${table.durationMinutes} is null or ${table.durationMinutes} between 1 and 1440`),
  check("entries_amount_ml_check", sql`${table.amountMl} is null or ${table.amountMl} between 1 and 5000`),
]);

export const caregivers = pgTable("caregivers", {
  id: text("id").primaryKey(),
  householdId: text("household_id").notNull().references(() => households.id, { onDelete: "cascade" }),
  userId: text("user_id").references(() => users.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  role: caregiverRole("role").notNull().default("caregiver"),
  status: caregiverStatus("status").notNull().default("pending"),
  ...timestamps,
  joinedAt: timestamp("joined_at", { withTimezone: true }),
}, table => [
  unique("caregivers_user_id_unique").on(table.userId),
  unique("uq_caregivers_household_id").on(table.householdId, table.id),
  index("idx_caregivers_household_status").on(table.householdId, table.status),
  check("caregivers_membership_state_check", sql`(${table.status} = 'pending' and ${table.userId} is null and ${table.joinedAt} is null) or (${table.status} = 'active' and ${table.userId} is not null and ${table.joinedAt} is not null) or ${table.status} = 'removed'`),
]);

export const authChallenges = pgTable("auth_challenges", {
  id: text("id").primaryKey(),
  nonceHash: text("nonce_hash").notNull(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  consumedAt: timestamp("consumed_at", { withTimezone: true }),
  ...timestamps,
}, table => [index("idx_auth_challenges_expires").on(table.expiresAt)]);

export const authSessions = pgTable("auth_sessions", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  challengeId: text("challenge_id").references(() => authChallenges.id, { onDelete: "set null" }),
  tokenHash: text("token_hash").notNull(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  revokedAt: timestamp("revoked_at", { withTimezone: true }),
  ...timestamps,
}, table => [
  unique("auth_sessions_challenge_id_unique").on(table.challengeId),
  unique("auth_sessions_token_hash_unique").on(table.tokenHash),
  index("idx_auth_sessions_user_active").on(table.userId, table.revokedAt, table.expiresAt),
  check("auth_sessions_expiry_check", sql`${table.expiresAt} > ${table.createdAt}`),
]);

export const invitations = pgTable("invitations", {
  id: text("id").primaryKey(),
  caregiverId: text("caregiver_id").notNull().references(() => caregivers.id, { onDelete: "cascade" }),
  codeHash: text("code_hash").notNull(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  consumedAt: timestamp("consumed_at", { withTimezone: true }),
  failedAttempts: integer("failed_attempts").notNull().default(0),
  ...timestamps,
}, table => [
  unique("invitations_caregiver_id_unique").on(table.caregiverId),
  unique("invitations_code_hash_unique").on(table.codeHash),
  index("idx_invitations_expires").on(table.expiresAt),
  check("invitations_failed_attempts_check", sql`${table.failedAttempts} between 0 and 5`),
  check("invitations_expiry_check", sql`${table.expiresAt} > ${table.createdAt}`),
]);

export const invitationClaims = pgTable("invitation_claims", {
  invitationId: text("invitation_id").primaryKey().references(() => invitations.id, { onDelete: "cascade" }),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  claimedAt: timestamp("claimed_at", { withTimezone: true }).notNull().defaultNow(),
}, table => [unique("invitation_claims_user_id_unique").on(table.userId)]);

export const authRateLimits = pgTable("auth_rate_limits", {
  key: text("key").primaryKey(),
  windowStartedAt: timestamp("window_started_at", { withTimezone: true }).notNull(),
  attempts: integer("attempts").notNull(),
}, table => [
  check("auth_rate_limits_attempts_check", sql`${table.attempts} > 0`),
]);

export const entryAuthors = pgTable("entry_authors", {
  entryId: text("entry_id").notNull(),
  householdId: text("household_id").notNull().references(() => households.id, { onDelete: "cascade" }),
  caregiverId: text("caregiver_id").notNull(),
  caregiverName: text("caregiver_name").notNull(),
}, table => [
  primaryKey({ columns: [table.entryId] }),
  index("idx_entry_authors_household_caregiver").on(table.householdId, table.caregiverId),
  foreignKey({
    columns: [table.householdId, table.entryId],
    foreignColumns: [entries.householdId, entries.id],
    name: "entry_authors_household_entry_fk",
  }).onDelete("cascade"),
]);
