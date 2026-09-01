DROP INDEX `idx_entries_household_occurred_at`;--> statement-breakpoint
CREATE INDEX `idx_entries_household_occurred_at_id` ON `entries` (`household_id`,`occurred_at`,`id`);
