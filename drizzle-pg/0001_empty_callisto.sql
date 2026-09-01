CREATE TYPE "public"."caregiver_role" AS ENUM('owner', 'caregiver');--> statement-breakpoint
CREATE TYPE "public"."caregiver_status" AS ENUM('pending', 'active', 'removed');--> statement-breakpoint
CREATE TYPE "public"."entry_kind" AS ENUM('sleep', 'feed', 'diaper', 'health');--> statement-breakpoint
ALTER TABLE "caregivers" DROP CONSTRAINT "caregivers_role_check";--> statement-breakpoint
ALTER TABLE "caregivers" DROP CONSTRAINT "caregivers_status_check";--> statement-breakpoint
ALTER TABLE "caregivers" DROP CONSTRAINT "caregivers_membership_state_check";--> statement-breakpoint
ALTER TABLE "entries" DROP CONSTRAINT "entries_kind_check";--> statement-breakpoint
ALTER TABLE "caregivers" ALTER COLUMN "role" SET DEFAULT 'caregiver'::"public"."caregiver_role";--> statement-breakpoint
ALTER TABLE "caregivers" ALTER COLUMN "role" SET DATA TYPE "public"."caregiver_role" USING "role"::"public"."caregiver_role";--> statement-breakpoint
ALTER TABLE "caregivers" ALTER COLUMN "status" SET DEFAULT 'pending'::"public"."caregiver_status";--> statement-breakpoint
ALTER TABLE "caregivers" ALTER COLUMN "status" SET DATA TYPE "public"."caregiver_status" USING "status"::"public"."caregiver_status";--> statement-breakpoint
ALTER TABLE "entries" ALTER COLUMN "kind" SET DATA TYPE "public"."entry_kind" USING "kind"::"public"."entry_kind";--> statement-breakpoint
ALTER TABLE "caregivers" ADD CONSTRAINT "caregivers_membership_state_check" CHECK (("status" = 'pending' AND "user_id" IS NULL AND "joined_at" IS NULL) OR ("status" = 'active' AND "user_id" IS NOT NULL AND "joined_at" IS NOT NULL) OR "status" = 'removed');
