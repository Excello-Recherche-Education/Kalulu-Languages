-- Migration from schema version 4 to version 5, in one transaction:
--
--     sqlite3 <locale>/language.db < schema/v4-to-v5.sql
--
-- .bail on (below) matters: without it the sqlite3 shell carries on past a
-- failed statement and the final COMMIT keeps whatever succeeded. With it, the
-- first failure stops the script inside the transaction, which is then rolled
-- back. The first statement after BEGIN fails unless the pack is version 4, so
-- running it twice, or on a pack of any other version, changes nothing.
-- It is an sqlite3 shell command: run the file with the sqlite3 shell.
--
-- Adds the empty BookletImages table and the BookletChapters ImageID column,
-- all NULL, so every chapter keeps the picture its ImageGPID gives it. Nothing
-- already in the pack changes. Kalulu-ProfTool's PackSchema._to_v5() makes the
-- same changes to a pack it opens; Kalulu-Frontend's model_database.db was
-- migrated with this file.

.bail on

BEGIN TRANSACTION;

-- Refuse anything but a version 4 pack: the insert breaks the CHECK otherwise.
CREATE TEMP TABLE "_migrating_from" ("Version" INTEGER CHECK ("Version" = 4));
INSERT INTO "_migrating_from" SELECT user_version FROM pragma_user_version;

-- Pictures the teacher's booklet may show before a chapter, each a file of the
-- pack's booklet_images/ folder, named by its path there.
CREATE TABLE "BookletImages" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"Name"	TEXT NOT NULL UNIQUE,
	"File"	TEXT NOT NULL UNIQUE,
	PRIMARY KEY("ID" AUTOINCREMENT)
);

-- The chapter's own picture, shown instead of its ImageGPID's; NULL keeps that.
ALTER TABLE "BookletChapters" ADD COLUMN "ImageID" INTEGER REFERENCES "BookletImages"("ID") ON UPDATE CASCADE ON DELETE SET NULL;

PRAGMA user_version = 5;

COMMIT;
