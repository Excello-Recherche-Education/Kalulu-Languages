-- Migration from schema version 3 to version 4, in one transaction:
--
--     sqlite3 <locale>/language.db < schema/v3-to-v4.sql
--
-- .bail on (below) matters: without it the sqlite3 shell carries on past a
-- failed statement and the final COMMIT keeps whatever succeeded. With it, the
-- first failure stops the script inside the transaction, which is then rolled
-- back. The first statement after BEGIN fails unless the pack is version 3, so
-- running it twice, or on a pack of any other version, changes nothing.
-- It is an sqlite3 shell command: run the file with the sqlite3 shell, 3.35 or
-- later (ALTER TABLE ... DROP COLUMN).
--
-- Drops the Writing column of Words, Syllables and Sentences. No program read
-- it, and no pack set it: what a booklet's writing page prints is chosen in its
-- chapters (BookletEntries), not flagged on the lists. Nothing else changes.
-- Kalulu-ProfTool's PackSchema._to_v4() makes the same change to a pack it
-- opens; Kalulu-Frontend's model_database.db was migrated with this file.

.bail on

BEGIN TRANSACTION;

-- Refuse anything but a version 3 pack: the insert breaks the CHECK otherwise.
CREATE TEMP TABLE "_migrating_from" ("Version" INTEGER CHECK ("Version" = 3));
INSERT INTO "_migrating_from" SELECT user_version FROM pragma_user_version;

ALTER TABLE "Words" DROP COLUMN "Writing";
ALTER TABLE "Syllables" DROP COLUMN "Writing";
ALTER TABLE "Sentences" DROP COLUMN "Writing";

PRAGMA user_version = 4;

COMMIT;
