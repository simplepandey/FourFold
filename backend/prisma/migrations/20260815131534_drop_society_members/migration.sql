-- society_members retired entirely — members are only ever added per-device
-- now (device_members), and the society founder logs in via password
-- (matched directly against Society.phoneNumber), never needing a roster
-- row. Nothing reads or writes this table anymore.
DROP TABLE "society_members";
