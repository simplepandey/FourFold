-- 1. Sequence backing product codes. First-ever value is 100 -> "FF00100".
--    A DB sequence (not a count-and-increment in app code) so concurrent
--    registrations (e.g. a factory batch booting at once) never collide.
CREATE SEQUENCE "product_code_seq" START 100;

-- 2. Add the column nullable for now — backfilled below before it's required.
ALTER TABLE "esp_registrations" ADD COLUMN "productCode" TEXT;

-- 3. Backfill existing rows in creation order, assigning FF00100, FF00101, ...
WITH ordered AS (
  SELECT "id", ROW_NUMBER() OVER (ORDER BY "createdAt" ASC) - 1 AS rn
  FROM "esp_registrations"
)
UPDATE "esp_registrations" e
SET "productCode" = 'FF' || LPAD((100 + ordered.rn)::text, 5, '0')
FROM ordered
WHERE e."id" = ordered.id;

-- Advance the sequence past whatever was just manually assigned above, so the
-- next real registration continues the numbering instead of colliding with
-- it. Correct even for an empty table (COUNT=0 -> setval(99) -> next is 100).
SELECT setval('product_code_seq', 100 + (SELECT COUNT(*) FROM "esp_registrations") - 1, true);

-- 4. Every row now has one — safe to require and enforce uniqueness.
ALTER TABLE "esp_registrations" ALTER COLUMN "productCode" SET NOT NULL;
ALTER TABLE "esp_registrations" ADD CONSTRAINT "esp_registrations_productCode_key" UNIQUE ("productCode");
