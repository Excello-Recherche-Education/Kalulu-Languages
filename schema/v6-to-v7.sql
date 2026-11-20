-- Migration from schema version 6 to version 7, in one transaction:
--
--     sqlite3 <locale>/language.db < schema/v6-to-v7.sql
--
-- .bail on (below) matters: without it the sqlite3 shell carries on past a
-- failed statement and the final COMMIT keeps whatever succeeded. With it, the
-- first failure stops the script inside the transaction, which is then rolled
-- back. The first statement after BEGIN fails unless the pack is version 6, so
-- running it twice, or on a pack of any other version, changes nothing.
-- It is an sqlite3 shell command: run the file with the sqlite3 shell, 3.35 or
-- later (ALTER TABLE ... DROP COLUMN).
--
-- Says what a language's booklets print. Cursive becomes two series: a pack
-- with Cursive 1 prints the cursive series, as it did, and one with Cursive 0
-- the script series, as it did; a language may then print both. Every version
-- is printed, as before: TeacherVersion to AdhdVersion all 1. Nothing a pack
-- prints changes. Kalulu-ProfTool's PackSchema._to_v7() makes the same changes
-- to a pack it opens; Kalulu-Frontend's model_database.db was migrated with
-- this file.

.bail on

BEGIN TRANSACTION;

-- Refuse anything but a version 6 pack: the insert breaks the CHECK otherwise.
CREATE TEMP TABLE "_migrating_from" ("Version" INTEGER CHECK ("Version" = 6));
INSERT INTO "_migrating_from" SELECT user_version FROM pragma_user_version;

-- The series: script (everything in script, with the share in capitals) and
-- cursive (titles, sentences and writing pages in cursive too). At least one.
ALTER TABLE "BookletSettings" ADD COLUMN "ScriptSeries" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "BookletSettings" ADD COLUMN "CursiveSeries" INTEGER NOT NULL DEFAULT 1;
UPDATE "BookletSettings" SET "ScriptSeries" = ("Cursive" = 0), "CursiveSeries" = ("Cursive" != 0);
ALTER TABLE "BookletSettings" DROP COLUMN "Cursive";

-- The versions printed besides the base one, which always is.
ALTER TABLE "BookletSettings" ADD COLUMN "TeacherVersion" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "BookletSettings" ADD COLUMN "NoWritingVersion" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "BookletSettings" ADD COLUMN "DyslexiaVersion" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "BookletSettings" ADD COLUMN "DyspraxiaVersion" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "BookletSettings" ADD COLUMN "AdhdVersion" INTEGER NOT NULL DEFAULT 1;

PRAGMA user_version = 7;

COMMIT;
