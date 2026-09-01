CREATE TABLE "auth_challenges" (
	"id" text PRIMARY KEY NOT NULL,
	"nonce_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"consumed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "auth_rate_limits" (
	"key" text PRIMARY KEY NOT NULL,
	"window_started_at" timestamp with time zone NOT NULL,
	"attempts" integer NOT NULL,
	CONSTRAINT "auth_rate_limits_attempts_check" CHECK ("auth_rate_limits"."attempts" > 0)
);
--> statement-breakpoint
CREATE TABLE "auth_sessions" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"challenge_id" text,
	"token_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "auth_sessions_challenge_id_unique" UNIQUE("challenge_id"),
	CONSTRAINT "auth_sessions_token_hash_unique" UNIQUE("token_hash"),
	CONSTRAINT "auth_sessions_expiry_check" CHECK ("auth_sessions"."expires_at" > "auth_sessions"."created_at")
);
--> statement-breakpoint
CREATE TABLE "caregivers" (
	"id" text PRIMARY KEY NOT NULL,
	"household_id" text NOT NULL,
	"user_id" text,
	"name" text NOT NULL,
	"role" text DEFAULT 'caregiver' NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"joined_at" timestamp with time zone,
	CONSTRAINT "caregivers_user_id_unique" UNIQUE("user_id"),
	CONSTRAINT "uq_caregivers_household_id" UNIQUE("household_id","id"),
	CONSTRAINT "caregivers_role_check" CHECK ("caregivers"."role" in ('owner', 'caregiver')),
	CONSTRAINT "caregivers_status_check" CHECK ("caregivers"."status" in ('pending', 'active', 'removed')),
	CONSTRAINT "caregivers_membership_state_check" CHECK (("caregivers"."status" = 'pending' and "caregivers"."user_id" is null and "caregivers"."joined_at" is null) or ("caregivers"."status" = 'active' and "caregivers"."user_id" is not null and "caregivers"."joined_at" is not null) or "caregivers"."status" = 'removed')
);
--> statement-breakpoint
CREATE TABLE "entries" (
	"id" text PRIMARY KEY NOT NULL,
	"household_id" text NOT NULL,
	"kind" text NOT NULL,
	"title" text NOT NULL,
	"detail" text DEFAULT '' NOT NULL,
	"occurred_at" bigint NOT NULL,
	"duration_minutes" integer,
	"amount_ml" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "uq_entries_household_id" UNIQUE("household_id","id"),
	CONSTRAINT "entries_kind_check" CHECK ("entries"."kind" in ('sleep', 'feed', 'diaper', 'health')),
	CONSTRAINT "entries_duration_minutes_check" CHECK ("entries"."duration_minutes" is null or "entries"."duration_minutes" between 1 and 1440),
	CONSTRAINT "entries_amount_ml_check" CHECK ("entries"."amount_ml" is null or "entries"."amount_ml" between 1 and 5000)
);
--> statement-breakpoint
CREATE TABLE "entry_authors" (
	"entry_id" text NOT NULL,
	"household_id" text NOT NULL,
	"caregiver_id" text NOT NULL,
	"caregiver_name" text NOT NULL,
	CONSTRAINT "entry_authors_entry_id_pk" PRIMARY KEY("entry_id")
);
--> statement-breakpoint
CREATE TABLE "households" (
	"id" text PRIMARY KEY NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "invitation_claims" (
	"invitation_id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"claimed_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "invitation_claims_user_id_unique" UNIQUE("user_id")
);
--> statement-breakpoint
CREATE TABLE "invitations" (
	"id" text PRIMARY KEY NOT NULL,
	"caregiver_id" text NOT NULL,
	"code_hash" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"consumed_at" timestamp with time zone,
	"failed_attempts" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "invitations_caregiver_id_unique" UNIQUE("caregiver_id"),
	CONSTRAINT "invitations_code_hash_unique" UNIQUE("code_hash"),
	CONSTRAINT "invitations_failed_attempts_check" CHECK ("invitations"."failed_attempts" between 0 and 5),
	CONSTRAINT "invitations_expiry_check" CHECK ("invitations"."expires_at" > "invitations"."created_at")
);
--> statement-breakpoint
CREATE TABLE "profiles" (
	"household_id" text PRIMARY KEY NOT NULL,
	"caregiver_name" text NOT NULL,
	"baby_name" text NOT NULL,
	"birth_date" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "profiles_birth_date_check" CHECK ("profiles"."birth_date" ~ '^\d{4}-\d{2}-\d{2}$')
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" text PRIMARY KEY NOT NULL,
	"apple_subject" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_apple_subject_unique" UNIQUE("apple_subject")
);
--> statement-breakpoint
ALTER TABLE "auth_sessions" ADD CONSTRAINT "auth_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "auth_sessions" ADD CONSTRAINT "auth_sessions_challenge_id_auth_challenges_id_fk" FOREIGN KEY ("challenge_id") REFERENCES "public"."auth_challenges"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "caregivers" ADD CONSTRAINT "caregivers_household_id_households_id_fk" FOREIGN KEY ("household_id") REFERENCES "public"."households"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "caregivers" ADD CONSTRAINT "caregivers_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entries" ADD CONSTRAINT "entries_household_id_households_id_fk" FOREIGN KEY ("household_id") REFERENCES "public"."households"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_authors" ADD CONSTRAINT "entry_authors_household_id_households_id_fk" FOREIGN KEY ("household_id") REFERENCES "public"."households"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_authors" ADD CONSTRAINT "entry_authors_household_entry_fk" FOREIGN KEY ("household_id","entry_id") REFERENCES "public"."entries"("household_id","id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invitation_claims" ADD CONSTRAINT "invitation_claims_invitation_id_invitations_id_fk" FOREIGN KEY ("invitation_id") REFERENCES "public"."invitations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invitation_claims" ADD CONSTRAINT "invitation_claims_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_caregiver_id_caregivers_id_fk" FOREIGN KEY ("caregiver_id") REFERENCES "public"."caregivers"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_household_id_households_id_fk" FOREIGN KEY ("household_id") REFERENCES "public"."households"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_auth_challenges_expires" ON "auth_challenges" USING btree ("expires_at");--> statement-breakpoint
CREATE INDEX "idx_auth_sessions_user_active" ON "auth_sessions" USING btree ("user_id","revoked_at","expires_at");--> statement-breakpoint
CREATE INDEX "idx_caregivers_household_status" ON "caregivers" USING btree ("household_id","status");--> statement-breakpoint
CREATE INDEX "idx_entries_household_occurred_at_id" ON "entries" USING btree ("household_id","occurred_at","id");--> statement-breakpoint
CREATE INDEX "idx_entry_authors_household_caregiver" ON "entry_authors" USING btree ("household_id","caregiver_id");--> statement-breakpoint
CREATE INDEX "idx_invitations_expires" ON "invitations" USING btree ("expires_at");
--> statement-breakpoint
CREATE FUNCTION enforce_consumed_auth_challenge() RETURNS trigger AS $$
BEGIN
	IF NEW.challenge_id IS NOT NULL AND NOT EXISTS (
		SELECT 1 FROM auth_challenges
		WHERE id = NEW.challenge_id
			AND consumed_at = NEW.created_at
			AND expires_at >= NEW.created_at
	) THEN
		RAISE EXCEPTION 'invalid auth challenge consumption';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
--> statement-breakpoint
CREATE TRIGGER auth_session_requires_consumed_challenge
BEFORE INSERT ON auth_sessions
FOR EACH ROW EXECUTE FUNCTION enforce_consumed_auth_challenge();
