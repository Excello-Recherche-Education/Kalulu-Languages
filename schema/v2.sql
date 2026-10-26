-- Kalulu language pack schema, version 2.
--
-- The authoritative structure of every <locale>/language.db. SCHEMA.md at the
-- repository root explains each table, who reads and writes it, and the rules
-- the data must follow. A pack conforms when it has exactly these tables and
-- columns, with these types, defaults and foreign keys, and
-- PRAGMA user_version = 2.
--
-- Version 2 is version 1 plus what the reading booklets need: a BookletOnly
-- flag on Words, Syllables and Sentences, and the Booklet* tables at the end.
-- schema/v1-to-v2.sql is the migration. Changes to it are made by a new
-- version file and a migration, never by editing this one.

CREATE TABLE "GPs" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"Grapheme"	TEXT NOT NULL,
	"Phoneme"	TEXT NOT NULL,
	"Type"	INTEGER DEFAULT 0,
	"Exception"	INTEGER DEFAULT 0,
	PRIMARY KEY("ID" AUTOINCREMENT)
);

CREATE TABLE "Lessons" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"LessonNb"	INTEGER NOT NULL,
	PRIMARY KEY("ID" AUTOINCREMENT)
);

CREATE TABLE "GPsInLessons" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"GPID"	INTEGER NOT NULL,
	"LessonID"	INTEGER NOT NULL,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("LessonID") REFERENCES "Lessons"("ID") ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY("GPID") REFERENCES "GPs"("ID") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "Words" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"Word"	TEXT NOT NULL,
	"Exception"	INTEGER DEFAULT 0,
	"Reading"	INTEGER DEFAULT 1,
	"Writing"	INTEGER DEFAULT 0,
	"BookletOnly"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("ID" AUTOINCREMENT)
);

CREATE TABLE "GPsInWords" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"WordID"	INTEGER NOT NULL,
	"GPID"	INTEGER NOT NULL,
	"Position"	INTEGER NOT NULL,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("GPID") REFERENCES "GPs"("ID") ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY("WordID") REFERENCES "Words"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE "Syllables" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"Syllable"	TEXT NOT NULL,
	"Exception"	INTEGER DEFAULT 0,
	"Reading"	INTEGER DEFAULT 1,
	"Writing"	INTEGER DEFAULT 0,
	"BookletOnly"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("ID" AUTOINCREMENT)
);

CREATE TABLE "GPsInSyllables" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"GPID"	INTEGER NOT NULL,
	"SyllableID"	INTEGER NOT NULL,
	"Position"	INTEGER NOT NULL,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("SyllableID") REFERENCES "Syllables"("ID") ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY("GPID") REFERENCES "GPs"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE "Sentences" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"Sentence"	TEXT NOT NULL,
	"Exception"	INTEGER DEFAULT 0,
	"Reading"	INTEGER DEFAULT 1,
	"Writing"	INTEGER DEFAULT 0,
	"BookletOnly"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("ID" AUTOINCREMENT)
);

CREATE TABLE "WordsInSentences" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"SentenceID"	INTEGER NOT NULL,
	"WordID"	INTEGER NOT NULL,
	"Position"	INTEGER NOT NULL,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("WordID") REFERENCES "Words"("ID") ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY("SentenceID") REFERENCES "Sentences"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE "Pseudowords" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"Pseudoword"	TEXT,
	"WordID"	INTEGER NOT NULL,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("WordID") REFERENCES "Words"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

-- One row per minigame: the row at ID n holds MinigameTypes.NAMES[n - 1] in
-- Kalulu-Frontend. LessonsExercises stores these IDs.
CREATE TABLE "ExerciseTypes" (
	"ID"	INTEGER PRIMARY KEY ASC AUTOINCREMENT UNIQUE NOT NULL,
	"Type"	TEXT NOT NULL
);

-- No foreign key on Exercise1..3: 0 means "no minigame in this slot", which no
-- ExerciseTypes row has, so a lesson can hold one to three minigames.
CREATE TABLE "LessonsExercises" (
	"ID"	INTEGER NOT NULL UNIQUE,
	"LessonID"	INTEGER NOT NULL,
	"Exercise1"	INTEGER NOT NULL,
	"Exercise2"	INTEGER NOT NULL,
	"Exercise3"	INTEGER NOT NULL,
	PRIMARY KEY("ID" AUTOINCREMENT),
	FOREIGN KEY("LessonID") REFERENCES "Lessons"("ID") ON UPDATE CASCADE ON DELETE CASCADE
);

-- Unused: empty in every pack, read and written by nothing. Letter tracings are
-- the CSV files under <locale>/tracing_data/. Kept so version 1 adds and removes
-- nothing; a later version may drop it.
CREATE TABLE "LettersTracingData" (
	"ID"	INTEGER NOT NULL UNIQUE PRIMARY KEY AUTOINCREMENT,
	"Letter"	TEXT,
	"LowerTracingPath"	TEXT DEFAULT '',
	"UpperTracingPath"	TEXT DEFAULT ''
);

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

PRAGMA user_version = 2;
