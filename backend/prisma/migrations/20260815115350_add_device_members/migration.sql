-- Split per-device access/role out of society_members into its own table,
-- so one person can have access to multiple devices (each with its own
-- role) instead of a single productCode column limiting them to one.

CREATE TABLE "device_members" (
    "id" TEXT NOT NULL,
    "productCode" TEXT NOT NULL,
    "societyCode" TEXT NOT NULL,
    "phoneNumber" TEXT NOT NULL,
    "userId" TEXT,
    "role" TEXT NOT NULL DEFAULT 'member',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_members_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "device_members_productCode_phoneNumber_key" ON "device_members"("productCode", "phoneNumber");
CREATE INDEX "device_members_productCode_idx" ON "device_members"("productCode");
CREATE INDEX "device_members_societyCode_idx" ON "device_members"("societyCode");
CREATE INDEX "device_members_userId_idx" ON "device_members"("userId");
CREATE INDEX "device_members_phoneNumber_idx" ON "device_members"("phoneNumber");

-- Carry over every existing society_members row that had a device link.
INSERT INTO "device_members" ("id", "productCode", "societyCode", "phoneNumber", "userId", "role", "joinedAt")
SELECT gen_random_uuid()::text, "productCode", "societyCode", "phoneNumber", "userId", "role", "joinedAt"
FROM "society_members"
WHERE "productCode" IS NOT NULL;

-- society_members goes back to being the pure society roster.
ALTER TABLE "society_members" DROP COLUMN "productCode";
