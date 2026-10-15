# The `language.db` schema

Every pack's `language.db` is read by five programs and written by one, across
five repositories. This document is the contract between them: what the database
holds, who depends on which part of it, and the rules the data must follow.

**The current version is 1.** Its exact structure is [`schema/v1.sql`](schema/v1.sql);
this page explains it. A database says which version it follows in
`PRAGMA user_version`.

> **Status, 2026-10-15: version 1 is written down, not yet applied.** It is the
> schema the packs already use — `fr_FR`'s, the most complete — with nothing
> added. No database carries a version yet (every `user_version` is 0), and four
> of the five packs differ from it in small ways; see "Where the packs stand".
> Bringing them to version 1 is the next step.

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

**`Lessons`** (`LessonNb`) — the numbered lessons. **Join on `ID`, order by
`LessonNb`**: they are equal in every pack today, but nothing guarantees it.

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

Structure is only half the contract. These hold in a correct pack, and **are not
yet checked anywhere** — a validator in this repository's CI is the step after the
migration:

1. Every word and syllable that a lesson can offer has a decomposition, with
   positions `0, 1, 2…` and no gap.
2. Every GP used in a decomposition is introduced by some lesson, or the items
   containing it can never be offered.
3. Every `LessonsExercises` value is `0` or an existing `ExerciseTypes.ID`, and a
   lesson has at least one minigame.
4. `ExerciseTypes` matches `MinigameTypes.NAMES`, row for row.
5. `user_version` is the schema version the pack follows.

Known breaches, found by other means: in `fr_FR`, seven words lost a GP from their
decomposition and `payons` has none at all (rules 1 and 2), and lessons 37 and 40
list the same minigame twice (allowed by these rules, possibly a mistake). Details
in Kalulu-Main's `docs/agent/Kalulu-Languages.BUG.md`.

## Where the packs stand

Compared on 2026-10-15 against `schema/v1.sql`, by table, column, type, default,
nullability and foreign key. No database has views, triggers or indexes of its
own.

| Database | Structure | `ExerciseTypes` | `user_version` |
|---|---|---|---|
| `fr_FR` | **matches v1** | row 10 says `fish` | 0 |
| `pt_BR` | old foreign keys on `LessonsExercises.Exercise1`/`Exercise2` | row 10 says `fish` | 0 |
| `es_AR`, `es_UY` | old foreign keys; no `Reading`/`Writing` on `Sentences` | row 10 says `fish` | 0 |
| `es_CO` | old foreign keys; no `Reading`/`Writing` on `Words`, `Syllables` or `Sentences` | row 10 says `fish` | 0 |
| `model_database.db` (Kalulu-Frontend) | old foreign keys; no `Reading`/`Writing` on any table | 5 obsolete rows (`Syllable`, `Pairing`, `Words`, `Sentences`, `Boss`) | 0 |

- **The old foreign keys** reject `0`, the "no minigame" value. The Prof Tool drops
  them when *Lesson Exercises* opens; only `fr_FR` has had that done.
- **The missing `Reading` / `Writing` columns** are why `es_CO` exports empty
  lists, and why **every new language starts without them**: the model lacks them.
- **`fish` is the boss's former name.** The Prof Tool rewrites the table when
  *Lesson Exercises* opens; every pack was exported before the rename.

None of this changes what the game shows: it reads none of the columns or rows
involved. It changes what the Prof Tool exports, and what the next tools can rely
on.

## Changing the schema

- **A change is a new version**: a new `schema/v<n>.sql`, a migration from the
  previous one, and `user_version` set to *n* in every pack and in
  `model_database.db` together. A version file is never edited after it is in use.
- **Prefer adding to changing.** A new table or a new column with a default is
  invisible to a program that does not ask for it; renaming or removing breaks
  whoever reads it. Check the table above before removing anything.
- **Programs check the version, they do not repair the schema.** A program that
  finds an older version should migrate it in one place, or refuse it with a
  clear message — not patch columns as a side effect of opening a screen.
