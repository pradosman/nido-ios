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
