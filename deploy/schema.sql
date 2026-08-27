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

CREATE TABLE IF NOT EXISTS `profiles` (
  `id` integer PRIMARY KEY DEFAULT 1 NOT NULL,
  `caregiver_name` text NOT NULL,
  `baby_name` text NOT NULL,
  `birth_date` text NOT NULL,
  `created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  `updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS `idx_entries_occurred_at` ON `entries` (`occurred_at`);

CREATE TABLE IF NOT EXISTS `caregivers` (
  `id` text PRIMARY KEY NOT NULL,
  `name` text NOT NULL,
  `role` text DEFAULT 'caregiver' NOT NULL,
  `status` text DEFAULT 'pending' NOT NULL,
  `invite_code` text UNIQUE,
  `created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  `joined_at` text
);

CREATE TABLE IF NOT EXISTS `entry_authors` (
  `entry_id` text PRIMARY KEY NOT NULL,
  `caregiver_id` text NOT NULL,
  `caregiver_name` text NOT NULL
);

CREATE INDEX IF NOT EXISTS `idx_caregivers_status` ON `caregivers` (`status`);
CREATE INDEX IF NOT EXISTS `idx_entry_authors_caregiver` ON `entry_authors` (`caregiver_id`);

CREATE TABLE IF NOT EXISTS `caregiver_tokens` (
  `caregiver_id` text PRIMARY KEY NOT NULL,
  `token_hash` text UNIQUE NOT NULL,
  `created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
