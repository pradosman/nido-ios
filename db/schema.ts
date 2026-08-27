import { sql } from "drizzle-orm";
import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const profiles = sqliteTable("profiles", {
  id: integer("id").primaryKey().default(1),
  caregiverName: text("caregiver_name").notNull(),
  babyName: text("baby_name").notNull(),
  birthDate: text("birth_date").notNull(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const entries = sqliteTable("entries", {
  id: text("id").primaryKey(),
  kind: text("kind", { enum: ["sleep", "feed", "diaper", "health"] }).notNull(),
  title: text("title").notNull(),
  detail: text("detail").notNull().default(""),
  occurredAt: integer("occurred_at").notNull(),
  durationMinutes: integer("duration_minutes"),
  amountMl: integer("amount_ml"),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
}, (table) => [index("idx_entries_occurred_at").on(table.occurredAt)]);

export const caregivers = sqliteTable("caregivers", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  role: text("role", { enum: ["owner", "caregiver"] }).notNull().default("caregiver"),
  status: text("status", { enum: ["pending", "active"] }).notNull().default("pending"),
  inviteCode: text("invite_code").unique(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  joinedAt: text("joined_at"),
}, (table) => [index("idx_caregivers_status").on(table.status)]);

export const caregiverTokens = sqliteTable("caregiver_tokens", {
  caregiverId: text("caregiver_id").primaryKey(),
  tokenHash: text("token_hash").notNull().unique(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const entryAuthors = sqliteTable("entry_authors", {
  entryId: text("entry_id").primaryKey(),
  caregiverId: text("caregiver_id").notNull(),
  caregiverName: text("caregiver_name").notNull(),
}, (table) => [index("idx_entry_authors_caregiver").on(table.caregiverId)]);
