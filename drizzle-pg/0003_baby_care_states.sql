CREATE TABLE "baby_care_states" (
	"household_id" text PRIMARY KEY NOT NULL,
	"revision" integer DEFAULT 1 NOT NULL,
	"time_zone_id" text NOT NULL,
	"goal_versions" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"measurements" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "baby_care_states_revision_check" CHECK ("baby_care_states"."revision" >= 1)
);
--> statement-breakpoint
ALTER TABLE "baby_care_states" ADD CONSTRAINT "baby_care_states_household_id_households_id_fk" FOREIGN KEY ("household_id") REFERENCES "public"."households"("id") ON DELETE cascade ON UPDATE no action;
