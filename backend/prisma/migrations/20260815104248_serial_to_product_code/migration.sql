-- Switch module_registration / module_status / module_action_logs /
-- society_members from referencing devices by serialNumber to productCode.
-- esp_registrations itself is untouched (it's the source of truth for the
-- serialNumber <-> productCode mapping used to transform the data below).

-- ── module_registration ─────────────────────────────────────────────
ALTER TABLE "module_registration" RENAME COLUMN "serialNumber" TO "productCode";
UPDATE "module_registration" t
SET "productCode" = esp."productCode"
FROM "esp_registrations" esp
WHERE t."productCode" = esp."serialNumber";
ALTER INDEX "module_registration_serialNumber_idx" RENAME TO "module_registration_productCode_idx";

-- ── module_status ───────────────────────────────────────────────────
ALTER TABLE "module_status" RENAME COLUMN "serialNumber" TO "productCode";
UPDATE "module_status" t
SET "productCode" = esp."productCode"
FROM "esp_registrations" esp
WHERE t."productCode" = esp."serialNumber";
ALTER INDEX "module_status_serialNumber_idx" RENAME TO "module_status_productCode_idx";
ALTER INDEX "module_status_serialNumber_key" RENAME TO "module_status_productCode_key";

-- ── module_action_logs ──────────────────────────────────────────────
ALTER TABLE "module_action_logs" RENAME COLUMN "serialNumber" TO "productCode";
UPDATE "module_action_logs" t
SET "productCode" = esp."productCode"
FROM "esp_registrations" esp
WHERE t."productCode" = esp."serialNumber";
ALTER INDEX "module_action_logs_serialNumber_idx" RENAME TO "module_action_logs_productCode_idx";

-- ── society_members ─────────────────────────────────────────────────
ALTER TABLE "society_members" RENAME COLUMN "serialNumber" TO "productCode";
UPDATE "society_members" t
SET "productCode" = esp."productCode"
FROM "esp_registrations" esp
WHERE t."productCode" = esp."serialNumber";
-- nullable column, no index existed on it before, none added now.
