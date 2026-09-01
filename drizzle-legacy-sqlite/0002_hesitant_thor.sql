CREATE TABLE IF NOT EXISTS `caregivers` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`role` text DEFAULT 'caregiver' NOT NULL,
	`status` text DEFAULT 'pending' NOT NULL,
	`invite_code` text,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`joined_at` text
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS `caregivers_invite_code_unique` ON `caregivers` (`invite_code`);--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `idx_caregivers_status` ON `caregivers` (`status`);--> statement-breakpoint
CREATE TABLE IF NOT EXISTS `entry_authors` (
	`entry_id` text PRIMARY KEY NOT NULL,
	`caregiver_id` text NOT NULL,
	`caregiver_name` text NOT NULL
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS `idx_entry_authors_caregiver` ON `entry_authors` (`caregiver_id`);
