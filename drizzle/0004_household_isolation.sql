PRAGMA defer_foreign_keys = on;

CREATE TABLE `households` (
  `id` text PRIMARY KEY NOT NULL,
  `created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  `updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);

INSERT INTO `households` (`id`)
SELECT '00000000-0000-4000-8000-000000000001'
WHERE EXISTS (SELECT 1 FROM `profiles`)
   OR EXISTS (SELECT 1 FROM `caregivers`)
   OR EXISTS (SELECT 1 FROM `entries`)
   OR EXISTS (SELECT 1 FROM `caregiver_tokens`)
   OR EXISTS (SELECT 1 FROM `entry_authors`);

CREATE TABLE `profiles_new` (
  `household_id` text PRIMARY KEY NOT NULL,
  `caregiver_name` text NOT NULL,
  `baby_name` text NOT NULL,
  `birth_date` text NOT NULL,
  `created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  `updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households` (`id`) ON UPDATE no action ON DELETE cascade
);
INSERT INTO `profiles_new`
SELECT '00000000-0000-4000-8000-000000000001', `caregiver_name`, `baby_name`, `birth_date`, `created_at`, `updated_at`
FROM `profiles`;

CREATE TABLE `caregivers_new` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `name` text NOT NULL,
  `role` text DEFAULT 'caregiver' NOT NULL,
  `status` text DEFAULT 'pending' NOT NULL,
  `invite_code` text UNIQUE,
  `created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  `joined_at` text,
  FOREIGN KEY (`household_id`) REFERENCES `households` (`id`) ON UPDATE no action ON DELETE cascade
);
INSERT INTO `caregivers_new`
SELECT `id`, '00000000-0000-4000-8000-000000000001', `name`, `role`, `status`, `invite_code`, `created_at`, `joined_at`
FROM `caregivers`;
CREATE UNIQUE INDEX `uq_caregivers_household_id` ON `caregivers_new` (`household_id`, `id`);

CREATE TABLE `entries_new` (
  `id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `kind` text NOT NULL,
  `title` text NOT NULL,
  `detail` text DEFAULT '' NOT NULL,
  `occurred_at` integer NOT NULL,
  `duration_minutes` integer,
  `amount_ml` integer,
  `created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households` (`id`) ON UPDATE no action ON DELETE cascade
);
INSERT INTO `entries_new`
SELECT `id`, '00000000-0000-4000-8000-000000000001', `kind`, `title`, `detail`, `occurred_at`, `duration_minutes`, `amount_ml`, `created_at`
FROM `entries`;
CREATE UNIQUE INDEX `uq_entries_household_id` ON `entries_new` (`household_id`, `id`);

CREATE TABLE `caregiver_tokens_new` (
  `caregiver_id` text PRIMARY KEY NOT NULL,
  `token_hash` text UNIQUE NOT NULL,
  `created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
  FOREIGN KEY (`caregiver_id`) REFERENCES `caregivers_new` (`id`) ON UPDATE no action ON DELETE cascade
);
INSERT INTO `caregiver_tokens_new` SELECT `caregiver_id`, `token_hash`, `created_at` FROM `caregiver_tokens`;

CREATE TABLE `entry_authors_new` (
  `entry_id` text PRIMARY KEY NOT NULL,
  `household_id` text NOT NULL,
  `caregiver_id` text NOT NULL,
  `caregiver_name` text NOT NULL,
  FOREIGN KEY (`household_id`) REFERENCES `households` (`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`household_id`, `entry_id`) REFERENCES `entries_new` (`household_id`, `id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`household_id`, `caregiver_id`) REFERENCES `caregivers_new` (`household_id`, `id`) ON UPDATE no action ON DELETE no action
);
INSERT INTO `entry_authors_new`
SELECT `entry_id`, '00000000-0000-4000-8000-000000000001', `caregiver_id`, `caregiver_name`
FROM `entry_authors`;

DROP TABLE `caregiver_tokens`;
DROP TABLE `entry_authors`;
DROP TABLE `profiles`;
DROP TABLE `entries`;
DROP TABLE `caregivers`;

ALTER TABLE `profiles_new` RENAME TO `profiles`;
ALTER TABLE `caregivers_new` RENAME TO `caregivers`;
ALTER TABLE `entries_new` RENAME TO `entries`;
ALTER TABLE `caregiver_tokens_new` RENAME TO `caregiver_tokens`;
ALTER TABLE `entry_authors_new` RENAME TO `entry_authors`;

CREATE INDEX `idx_caregivers_household_status` ON `caregivers` (`household_id`, `status`);
CREATE INDEX `idx_entries_household_occurred_at` ON `entries` (`household_id`, `occurred_at`);
CREATE INDEX `idx_entry_authors_household_caregiver` ON `entry_authors` (`household_id`, `caregiver_id`);

PRAGMA defer_foreign_keys = off;
