-- Migration from schema version 5 to version 6, in one transaction:
--
--     sqlite3 <locale>/language.db < schema/v5-to-v6.sql
--
-- .bail on (below) matters: without it the sqlite3 shell carries on past a
-- failed statement and the final COMMIT keeps whatever succeeded. With it, the
-- first failure stops the script inside the transaction, which is then rolled
-- back. The first statement after BEGIN fails unless the pack is version 5, so
-- running it twice, or on a pack of any other version, changes nothing.
-- It is an sqlite3 shell command: run the file with the sqlite3 shell, 3.35 or
-- later (ALTER TABLE ... DROP COLUMN).
--
-- Adds the Uppercase flag of Words, Syllables and Sentences, 0 everywhere, so
-- nothing is printed in capitals until the Prof Tool draws them; and drops the
-- UppercaseProportion of BookletChapters, refusing a pack where a chapter set
-- one (none did): the share is now the language's alone. Kalulu-ProfTool's
-- PackSchema._to_v6() makes the same changes to a pack it opens;
-- Kalulu-Frontend's model_database.db was migrated with this file.

.bail on

BEGIN TRANSACTION;

-- Refuse anything but a version 5 pack: the insert breaks the CHECK otherwise.
CREATE TEMP TABLE "_migrating_from" ("Version" INTEGER CHECK ("Version" = 5));
INSERT INTO "_migrating_from" SELECT user_version FROM pragma_user_version;

-- Refuse a pack whose chapters set their own share in capitals: it would be lost.
CREATE TEMP TABLE "_chapter_shares" ("Count" INTEGER CHECK ("Count" = 0));
INSERT INTO "_chapter_shares" SELECT COUNT(*) FROM "BookletChapters" WHERE "UppercaseProportion" IS NOT NULL;

-- 1: the booklets print the entry in capitals, while the language's
-- BookletSettings.UppercaseProportion is above 0.
ALTER TABLE "Words" ADD COLUMN "Uppercase" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Syllables" ADD COLUMN "Uppercase" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Sentences" ADD COLUMN "Uppercase" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "BookletChapters" DROP COLUMN "UppercaseProportion";

PRAGMA user_version = 6;

COMMIT;
