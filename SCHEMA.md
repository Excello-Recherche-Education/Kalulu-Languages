# The `language.db` schema

Every pack's `language.db` is read by five programs and written by one, across
five repositories. This document is the contract between them: what the database
holds, who depends on which part of it, and the rules the data must follow.

**The current version is 1.** Its exact structure is [`schema/v1.sql`](schema/v1.sql);
this page explains it. A database says which version it follows in
`PRAGMA user_version`.

> **Status, 2026-10-16: all five packs, and the model database new languages
> start from, are at version 1.** Version 1 is the schema the packs already
> used — `fr_FR`'s, the most complete — with nothing added; the others were
> migrated to it, see "Where the packs stand". The model is Kalulu-Frontend's
> `model_database.db` (Kalulu-Frontend#361), which Kalulu-ProfTool copies.

## Why this exists

Until now the schema lived nowhere but in the databases themselves, and they
drifted apart: the five packs and the empty model new languages start from have
**five different schemas between them**. The Prof Tool also changes a pack's
structure as a side effect of opening a screen — the word list adds missing
`Reading` / `Writing` columns, *Lesson Exercises* drops a foreign key — so a
pack's schema depends on which screens someone happened to open. That is how
`es_CO` came to export empty word and syllable lists: its tables lack the columns
the export reads.

A version number makes the question "what does this pack contain?" answerable
without opening it, and a written schema gives the version a meaning.

## Who reads and writes it

| Program | Repository | Access | Tables it uses |
|---|---|---|---|
| **Prof Tool** | Kalulu-ProfTool | **reads and writes** — the only writer | every table except `LettersTracingData` |
| **The game** | Kalulu-Frontend | reads, on the device | `GPs`, `Lessons`, `GPsInLessons`, `Words`, `GPsInWords`, `Syllables`, `GPsInSyllables`, `Sentences`, `WordsInSentences`, `Pseudowords`, `LessonsExercises` |
| **Language Lambda** | Kalulu-Language-Lambda | reads, when a pack ZIP lands on S3; fills MySQL and uploads a copy of the database | `GPs` (`ID`, `Grapheme`, `Phoneme`, `Type`, `Exception`), `GPsInLessons` (lesson IDs come from here, not from `Lessons`) |
| **Backend** | Kalulu-Backend | reads that copy (`language-db-dumps/<locale>/language.db` on S3) | `Words` (`ID`, `Word`), `Syllables` (`ID`, `Syllable`), all of `Lessons` |
| **Languages Checker** | Kalulu-Languages-Checker | reads, in the tester's browser | `GPs` (`ID`, `Grapheme`, `Phoneme`), `Lessons`, `GPsInLessons`, `Words`, `GPsInWords`, `Syllables`, `GPsInSyllables` — not `Sentences`, which have no recording to review |

Measured on 2026-10-15 by reading each program's queries. Two consequences:

- **Only the Prof Tool reads `Reading` and `Writing`**, and nothing at all reads
  `ExerciseTypes` except the Prof Tool, which maintains it. Adding or filling those
  cannot affect the game, the Lambda, the backend or the Checker.
- **The backend reads `Lessons` with `SELECT *`**, so a column added to `Lessons`
  reaches it.

The empty database a new language starts from is `model_database.db` in
Kalulu-Frontend, copied by the Prof Tool. It is part of this contract too, and
must follow the same version as the packs.

## Tables

All IDs are SQLite `AUTOINCREMENT` integer keys. Every foreign key cascades on
update and on delete. Positions count from **0** and have no gaps.

### What exists in the language

**`GPs`** — the grapheme-phoneme pairs: one row per *reading* of a spelling, so
`c`→/k/ and `c`→/s/ are two rows.

| Column | Meaning |
|---|---|
| `Grapheme` | the spelling, as written in the database (file names encode it — see `CLAUDE.md`) |
| `Phoneme` | the sound, in the packs' keyboard-key notation (`@`, `S`, `%`…) |
| `Type` | `0` silent, `1` vowel, `2` consonant |
| `Exception` | `1` for an exception; the game leaves exceptions out unless a minigame asks for them |

**`Words`**, **`Syllables`**, **`Sentences`** — the stimuli. Each has its text
(`Word`, `Syllable`, `Sentence`) and three flags:

| Column | Default | Meaning |
|---|---|---|
| `Exception` | `0` | `1` for an irregular item; the game leaves it out of its pools |
| `Reading` | `1` | used for reading |
| `Writing` | `0` | used for writing |

`Syllables` also holds pseudo-syllables. A sentence's `\n` is a deliberate line
break.

**`GPsInWords`** (`WordID`, `GPID`, `Position`) and **`GPsInSyllables`**
(`SyllableID`, `GPID`, `Position`) — how each word or syllable decomposes into
GPs, in order. **`WordsInSentences`** (`SentenceID`, `WordID`, `Position`) — the
words of each sentence, in order.

**`Pseudowords`** (`Pseudoword`, `WordID`) — invented words tied to a real word,
used by a decoding minigame.

### When it is taught

**`Lessons`** (`LessonNb`) — the numbered lessons. **A lesson's `ID` is its
`LessonNb`** (rule 6), in every pack since 2026-10-20. The Language Lambda depends
on it: it writes `GPsInLessons.LessonID` to MySQL as the lesson number. Until then
the three Spanish packs stored lessons 36 and 37 under IDs 40 and 41, which only
the Prof Tool's export put right, by renumbering just before writing the ZIP — so
a ZIP made from the repository directly would have given MySQL lessons 40 and 41.
The game is unaffected either way: it joins on `ID` and orders by `LessonNb`.

**`GPsInLessons`** (`GPID`, `LessonID`) — which GP each lesson introduces. A word
or syllable becomes available at the latest lesson among its GPs; the game works
that out at run time from this table and the decompositions above.

**`LessonsExercises`** (`LessonID`, `Exercise1`, `Exercise2`, `Exercise3`) — the
minigames of each lesson. Each column holds an `ExerciseTypes.ID`, or **`0` for
"no minigame in this slot"**, so a lesson has one to three. There is deliberately
no foreign key on these columns: `0` matches no row.

**`ExerciseTypes`** (`Type`) — the minigame names. **The row with ID *n* holds
`MinigameTypes.NAMES[n - 1]`** from Kalulu-Frontend
(`sources/utils/minigame_types.gd`): `1` jellyfish, `2` crabs, `3` parakeets,
`4` monkey, `5` caterpillar, `6` frog, `7` turtles, `8` ants, `9` penguin,
`10` boss. The game itself never reads this table — it maps the IDs by position —
so the names matter to the Prof Tool and to anyone reading the data.

### Unused

**`LettersTracingData`** — empty in every pack and used by no program: letter
tracings are the CSV files under `<locale>/tracing_data/`. Version 1 keeps it so
that it adds and removes nothing; a later version may drop it.

## Rules the data must follow

Structure is only half the contract. These hold in a correct pack, and are
checked with the structure on every pull request (see "How the packs are checked"
below):

1. Every word and syllable that a lesson can offer has a decomposition, with
   positions `0, 1, 2…` and no gap.
2. Every GP used in a decomposition is introduced by some lesson, or the items
   containing it can never be offered.
3. Every `LessonsExercises` value is `0` or an existing `ExerciseTypes.ID`, and a
   lesson has at least one minigame.
4. `ExerciseTypes` matches `MinigameTypes.NAMES`, row for row.
5. `user_version` is the schema version the pack follows.
6. Every lesson's `ID` is its `LessonNb`.

Known breaches, all reported by the validator: in `fr_FR`, seven words lost a GP
from their decomposition and `payons` has none at all (rule 1); in `es_CO`,
lesson 37 has no `LessonsExercises` row at all, so the game finds no minigame for
it (rule 3). In `fr_FR`, lessons 37 and 40 also list the same minigame twice —
allowed by these rules, possibly a mistake. No pack breaks rule 2: every GP left
in a decomposition is taught by some lesson. Details in Kalulu-Main's
`docs/agent/Kalulu-Languages.BUG.md`.

## How the packs are checked

`.github/scripts/validate_packs.py` checks every `<locale>/language.db`.

**A pack change reaches `main` through a pull request, never a direct push** —
including a pack saved from the Prof Tool: commit it on a branch, open a pull
request, and merge once it is validated. The *Validate Language Packs* workflow
runs on every pull request into `main` (when it is opened, and again on every
push to its branch) and posts its report as a comment on the pull request,
updated in place. Run it locally the same way before opening one:

```bash
python3 .github/scripts/validate_packs.py                    # every pack
python3 .github/scripts/validate_packs.py fr_FR/language.db  # one
```

| Level | What | Effect |
|---|---|---|
| error | `user_version` is not the newest `schema/v<n>.sql` (rule 5); tables, columns, types, defaults, keys or indexes differ from that file; `integrity_check` fails; `foreign_key_check` finds rows pointing at nothing; a lesson's `ID` is not its `LessonNb` (rule 6) | the check fails |
| warning | rules 1 to 4 | reported; `--strict` makes them fail too, once the known breaches are fixed |
| notice | a rule that could not be checked, and why | reported only |

**Rule 6 is an error although it is a data rule**, because breaking it is not
contained in the pack: the Language Lambda would write the wrong lesson numbers
into production MySQL.

- **Structure is compared as SQLite reports it** (`PRAGMA table_info`,
  `foreign_key_list`, `index_list`), not as SQL text: the packs mix quoted and
  unquoted column definitions written by different tools, which mean the same.
- **Rule 1 is checked on every word and syllable**, not only those a lesson can
  offer.
- **Rule 4 needs the game's `MinigameTypes.NAMES`**, read from a Kalulu-Frontend
  checkout: `--frontend <path>`, or the `Kalulu-Frontend` folder beside this
  repository in a Kalulu-Main working copy. CI has neither, so there it only
  checks that the packs agree with each other, and says so.
- **The report is a comment on the pull request** because annotations only show
  inline on the files a pull request changes, and a pack's findings are often in
  files it does not touch. The same report is in the run's summary.

## Where the packs stand

**Every pack follows version 1** since 2026-10-16: structure identical to
`schema/v1.sql`, `user_version = 1`. Before that, none carried a version, and
four of the five differed from it:

| Database | What the migration changed |
|---|---|
| `fr_FR` | `ExerciseTypes` row 10, `fish` → `boss`; `user_version` |
| `pt_BR` | dropped the old foreign keys on `LessonsExercises.Exercise1`/`Exercise2`; `ExerciseTypes`; `user_version` |
| `es_AR`, `es_UY` | the foreign keys; added `Reading`/`Writing` to `Sentences`; `ExerciseTypes`; `user_version` |
| `es_CO` | the foreign keys; added `Reading`/`Writing` to `Words`, `Syllables` and `Sentences`; `ExerciseTypes`; `user_version` |
| `model_database.db` (Kalulu-Frontend) | the same as `es_CO`, and its five obsolete `ExerciseTypes` rows (`Syllable`, `Pairing`, `Words`, `Sentences`, `Boss`) replaced by the ten minigames — Kalulu-Frontend#361, merged into `3.1.7` as `5dfdd7b3` |

- **The old foreign keys rejected `0`**, the "no minigame" value, and both the game
  and the Prof Tool enforce foreign keys. The Prof Tool used to drop them when
  *Lesson Exercises* opened; only `fr_FR` had had that done.
- **The missing `Reading` / `Writing` columns** were why `es_CO` exported empty
  word and syllable lists — the export query failed outright — and why every new
  language started without them. Added with v1's defaults, `1` and `0`: exactly
  what the Prof Tool used to add when a screen opened.
- **`fish` was the boss's former name**; every pack had been exported before the
  rename.

**Lesson IDs, 2026-10-20.** In `es_AR`, `es_CO` and `es_UY`, lessons 36 and 37 went
from IDs 40 and 41 to 36 and 37 — one `UPDATE Lessons SET ID = LessonNb`, carried
to `GPsInLessons` and `LessonsExercises` by their `ON UPDATE CASCADE`. Every other
row of every table is unchanged, and so is the `AUTOINCREMENT` counter (41), as a
Prof Tool export leaves it. The Language Lambda's own code, run on each pack before
and after, now gives lessons 36 and 37 where it gave 40 and 41, with the same
lesson names, gardens and GPs. `es_AR` and `es_UY` are still byte-identical.

**What was checked.** Every table kept every row unchanged, apart from the
intended changes; the `LessonsExercises` rebuild kept its IDs and its
`AUTOINCREMENT` counter; SQLite's `integrity_check` and `foreign_key_check` pass.
The game's own `Database` functions, run in Godot against every lesson of every
pack before and after, return byte-identical results. Opening the Prof Tool's
schema-patching screens on a migrated pack no longer changes its schema, and
`es_CO`'s word and syllable export now returns its 1,622 words and 240 syllables.
None of this reaches a device until the pack ZIPs are next uploaded to S3.

## Changing the schema

- **A change is a new version**: a new `schema/v<n>.sql`, a migration from the
  previous one, and `user_version` set to *n* in every pack and in
  `model_database.db` together. A version file is never edited after it is in use.
  The validator always compares with the newest `schema/v<n>.sql`, so the new file
  and the migrated packs go in the same commit, or every pack fails.
- **Prefer adding to changing.** A new table or a new column with a default is
  invisible to a program that does not ask for it; renaming or removing breaks
  whoever reads it. Check the table above before removing anything.
- **Programs check the version, they do not repair the schema.** A program that
  finds an older version should migrate it in one place, or refuse it with a
  clear message — not patch columns as a side effect of opening a screen.
