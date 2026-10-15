-- Kalulu language pack schema, version 1.
--
-- The authoritative structure of every <locale>/language.db. SCHEMA.md at the
-- repository root explains each table, who reads and writes it, and the rules
-- the data must follow. A pack conforms when it has exactly these tables and
-- columns, with these types, defaults and foreign keys, and
-- PRAGMA user_version = 1.
--
-- Version 1 is the schema the packs already use (fr_FR's, which is the most
-- complete), written down; nothing in it is new. Changes to it are made by a
-- new version file and a migration, never by editing this one.

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

PRAGMA user_version = 1;
