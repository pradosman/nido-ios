CREATE TABLE IF NOT EXISTS `entries` (
	`id` text PRIMARY KEY NOT NULL,
	`kind` text NOT NULL,
	`title` text NOT NULL,
	`detail` text DEFAULT '' NOT NULL,
	`occurred_at` integer NOT NULL,
	`duration_minutes` integer,
	`amount_ml` integer,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS `profiles` (
	`id` integer PRIMARY KEY DEFAULT 1 NOT NULL,
	`caregiver_name` text NOT NULL,
	`baby_name` text NOT NULL,
	`birth_date` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
