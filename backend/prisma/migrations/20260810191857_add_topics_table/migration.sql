-- 1. Create the new topics table
CREATE TABLE "topics" (
    "id" TEXT NOT NULL,
    "commandTopic" TEXT NOT NULL,
    "telemetryTopic" TEXT NOT NULL,
    "alertTopic" TEXT NOT NULL,
    "heartbeatTopic" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "topics_pkey" PRIMARY KEY ("id")
);

-- 2. Add the FK column nullable for now — it can't be NOT NULL until every
--    existing row has been backfilled below.
ALTER TABLE "esp_registrations" ADD COLUMN "topicsId" TEXT;

-- 3. Backfill: one topics row per existing esp_registrations row, reusing the
--    esp_registrations row's own id as the topics row's id — a simple,
--    collision-free way to carry the 1:1 correlation without extra columns.
INSERT INTO "topics" ("id", "commandTopic", "telemetryTopic", "alertTopic", "heartbeatTopic", "createdAt")
SELECT "id", "commandTopic", "telemetryTopic", "alertTopic", "heartbeatTopic", "createdAt"
FROM "esp_registrations";

UPDATE "esp_registrations" SET "topicsId" = "id";

-- 4. Every row now has a topicsId — safe to require it going forward.
ALTER TABLE "esp_registrations" ALTER COLUMN "topicsId" SET NOT NULL;

-- 5. Data has moved to topics — drop the old flat columns.
ALTER TABLE "esp_registrations"
  DROP COLUMN "commandTopic",
  DROP COLUMN "telemetryTopic",
  DROP COLUMN "alertTopic",
  DROP COLUMN "heartbeatTopic";

-- 6. Enforce the 1:1 relationship.
CREATE UNIQUE INDEX "esp_registrations_topicsId_key" ON "esp_registrations"("topicsId");

ALTER TABLE "esp_registrations" ADD CONSTRAINT "esp_registrations_topicsId_fkey"
  FOREIGN KEY ("topicsId") REFERENCES "topics"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
