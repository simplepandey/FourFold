-- Add a user-facing device name to module_registration, collected during
-- the Add Device flow going forward. Nullable at first so existing rows
-- don't break, backfilled with their productCode as a placeholder (the only
-- sensible default with no real name on file), then made required.
ALTER TABLE "module_registration" ADD COLUMN "name" TEXT;
UPDATE "module_registration" SET "name" = "productCode" WHERE "name" IS NULL;
ALTER TABLE "module_registration" ALTER COLUMN "name" SET NOT NULL;
