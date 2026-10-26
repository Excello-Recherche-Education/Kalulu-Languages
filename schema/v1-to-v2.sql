-- Migration from schema version 1 to version 2, in one transaction:
--
--     sqlite3 <locale>/language.db < schema/v1-to-v2.sql
--
-- Adds the BookletOnly flag to Words, Syllables and Sentences, with the default
-- that keeps every existing entry in the game, and the empty Booklet* tables
-- with the one BookletSettings row the booklets read their defaults from.
-- Nothing already in the pack changes. Kalulu-ProfTool's PackSchema._to_v2()
-- makes the same changes to a pack it opens; Kalulu-Frontend's
-- model_database.db was migrated with this file.

BEGIN TRANSACTION;

ALTER TABLE "Words" ADD COLUMN "BookletOnly" INTEGER DEFAULT 0;
ALTER TABLE "Syllables" ADD COLUMN "BookletOnly" INTEGER DEFAULT 0;
ALTER TABLE "Sentences" ADD COLUMN "BookletOnly" INTEGER DEFAULT 0;

-- The reading booklets (Kalulu-Booklets reads these, the Prof Tool writes them;
-- nothing else does). SCHEMA.md, "The reading booklets", explains them.

-- One row: the language's booklet settings, and the defaults a chapter uses
-- where its own column is NULL.
CREATE TABLE "BookletSettings" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"Cursive"	INTEGER NOT NULL DEFAULT 1,
	"SyllableCount"	INTEGER NOT NULL DEFAULT 12,
	"SyllableColumns"	INTEGER NOT NULL DEFAULT 6,
	"WordCount"	INTEGER NOT NULL DEFAULT 12,
	"WordColumns"	INTEGER NOT NULL DEFAULT 4,
	"UppercaseProportion"	REAL NOT NULL DEFAULT 0,
	"SentenceFont"	INTEGER NOT NULL DEFAULT 0,
	"SentenceFirstFont"	INTEGER NOT NULL DEFAULT 2,
	"SentencePages"	INTEGER NOT NULL DEFAULT 1,
	"WritingModels"	INTEGER NOT NULL DEFAULT 1,
	"WritingTracings"	INTEGER NOT NULL DEFAULT 2,
	PRIMARY KEY("ID" AUTOINCREMENT)
);

-- Chapters follow the app's lessons: ordered by their lesson's LessonNb, then
-- by Position among the chapters of the same lesson. NULL in a setting column
-- means the BookletSettings value.
CREATE TABLE "BookletChapters" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"LessonID"	INTEGER NOT NULL,
	"Position"	INTEGER NOT NULL,
	"Booklet"	INTEGER NOT NULL DEFAULT 1,
	"Title"	TEXT NOT NULL DEFAULT '',
	"ImageGPID"	INTEGER,
	"GreySilent"	INTEGER NOT NULL DEFAULT 0,
	"SyllableCount"	INTEGER,
	"SyllableColumns"	INTEGER,
	"WordCount"	INTEGER,
	"WordColumns"	INTEGER,
	"UppercaseProportion"	REAL,
	"SentenceFont"	INTEGER,
	"SentenceFirstFont"	INTEGER,
	"SentencePages"	INTEGER,
	"WritingModels"	INTEGER,
	"WritingTracings"	INTEGER,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("LessonID") REFERENCES "Lessons"("ID") ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY("ImageGPID") REFERENCES "GPs"("ID") ON UPDATE CASCADE ON DELETE SET NULL
);

-- The GPs a chapter teaches: what its automatic syllables and words must
-- contain at least one of.
CREATE TABLE "BookletChapterGPs" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"ChapterID"	INTEGER NOT NULL,
	"GPID"	INTEGER NOT NULL,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("ChapterID") REFERENCES "BookletChapters"("ID") ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY("GPID") REFERENCES "GPs"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

-- A chapter's sentences, in order. Break says what comes before each one:
-- 0 the same line, 1 a new line, 2 a new paragraph.
CREATE TABLE "BookletSentences" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"ChapterID"	INTEGER NOT NULL,
	"SentenceID"	INTEGER NOT NULL,
	"Position"	INTEGER NOT NULL,
	"Break"	INTEGER NOT NULL DEFAULT 2,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("ChapterID") REFERENCES "BookletChapters"("ID") ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY("SentenceID") REFERENCES "Sentences"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

-- Entries written by hand, as they are printed ("la Lune", "un vélo"), in
-- order within their part: 1 syllables, 2 words, 3 writing, 4 tables,
-- 5 fluency. A table row has its right cell in Text2; Header marks a bold row
-- that starts a new table.
CREATE TABLE "BookletEntries" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"ChapterID"	INTEGER NOT NULL,
	"Part"	INTEGER NOT NULL,
	"Position"	INTEGER NOT NULL,
	"Text"	TEXT NOT NULL,
	"Text2"	TEXT NOT NULL DEFAULT '',
	"Header"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("ChapterID") REFERENCES "BookletChapters"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

-- Stories: free text, paragraphs separated by an empty line.
CREATE TABLE "BookletStories" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"ChapterID"	INTEGER NOT NULL,
	"Position"	INTEGER NOT NULL,
	"Title"	TEXT NOT NULL DEFAULT '',
	"Text"	TEXT NOT NULL DEFAULT '',
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("ChapterID") REFERENCES "BookletChapters"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

INSERT INTO "BookletSettings" DEFAULT VALUES;

PRAGMA user_version = 2;

COMMIT;
