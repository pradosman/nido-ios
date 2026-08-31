import { sql } from "drizzle-orm";
import { foreignKey, index, integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

export const households = sqliteTable("households", {
  id: text("id").primaryKey(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
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
  name: text("name").notNull(),
  role: text("role", { enum: ["owner", "caregiver"] }).notNull().default("caregiver"),
  status: text("status", { enum: ["pending", "active", "removed"] }).notNull().default("pending"),
  inviteCode: text("invite_code").unique(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  joinedAt: text("joined_at"),
}, (table) => [
  index("idx_caregivers_household_status").on(table.householdId, table.status),
  uniqueIndex("uq_caregivers_household_id").on(table.householdId, table.id),
]);

export const caregiverTokens = sqliteTable("caregiver_tokens", {
  caregiverId: text("caregiver_id").primaryKey().references(() => caregivers.id, { onDelete: "cascade" }),
  tokenHash: text("token_hash").notNull().unique(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
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
  foreignKey({
    columns: [table.householdId, table.caregiverId],
    foreignColumns: [caregivers.householdId, caregivers.id],
  }),
]);
