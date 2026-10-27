-- Migration from schema version 2 to version 3, in one transaction:
--
--     sqlite3 <locale>/language.db < schema/v2-to-v3.sql
--
-- .bail on (below) matters: without it the sqlite3 shell carries on past a
-- failed statement and the final COMMIT keeps whatever succeeded. With it, the
-- first failure stops the script inside the transaction, which is then rolled
-- back. The first statement after BEGIN fails unless the pack is version 2, so
-- running it twice, or on a pack of any other version, changes nothing.
-- It is an sqlite3 shell command: run the file with the sqlite3 shell.
--
-- Adds the empty BookletFonts table and the four BookletSettings font columns,
-- all NULL, so every booklet keeps printing with the default fonts. Nothing
-- already in the pack changes. Kalulu-ProfTool's PackSchema._to_v3() makes the
-- same changes to a pack it opens; Kalulu-Frontend's model_database.db was
-- migrated with this file.

.bail on

BEGIN TRANSACTION;

-- Refuse anything but a version 2 pack: the insert breaks the CHECK otherwise.
CREATE TEMP TABLE "_migrating_from" ("Version" INTEGER CHECK ("Version" = 2));
INSERT INTO "_migrating_from" SELECT user_version FROM pragma_user_version;

-- Fonts the booklets may print with instead of the default ones, each a file
-- of Kalulu-Languages' fonts/ folder, named by its path there.
CREATE TABLE "BookletFonts" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"Name"	TEXT NOT NULL UNIQUE,
	"File"	TEXT NOT NULL UNIQUE,
	PRIMARY KEY("ID" AUTOINCREMENT)
);

-- The font that replaces each default one; NULL keeps the default.
ALTER TABLE "BookletSettings" ADD COLUMN "ScriptFontID" INTEGER REFERENCES "BookletFonts"("ID") ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE "BookletSettings" ADD COLUMN "ScriptBoldFontID" INTEGER REFERENCES "BookletFonts"("ID") ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE "BookletSettings" ADD COLUMN "ScriptBlackFontID" INTEGER REFERENCES "BookletFonts"("ID") ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE "BookletSettings" ADD COLUMN "CursiveFontID" INTEGER REFERENCES "BookletFonts"("ID") ON UPDATE CASCADE ON DELETE SET NULL;

PRAGMA user_version = 3;

COMMIT;
