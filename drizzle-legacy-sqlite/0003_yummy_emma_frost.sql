CREATE TABLE IF NOT EXISTS `caregiver_tokens` (
	`caregiver_id` text PRIMARY KEY NOT NULL,
	`token_hash` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS `caregiver_tokens_token_hash_unique` ON `caregiver_tokens` (`token_hash`);
