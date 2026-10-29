# The `language.db` schema

Every pack's `language.db` is read by six programs and written by one, across
six repositories. This document is the contract between them: what the database
holds, who depends on which part of it, and the rules the data must follow.

**The current version is 4.** Its exact structure is [`schema/v4.sql`](schema/v4.sql);
this page explains it. A database says which version it follows in
`PRAGMA user_version`.

> **Status, 2026-10-27: all five packs are at version 4.** Version 4 is
> version 3 without the `Writing` column of `Words`, `Syllables` and
> `Sentences`, which no program read. Version 3 is
> version 2 plus the fonts a language's booklets may print with instead of the
> default ones — the `BookletFonts` table and four font columns in
> `BookletSettings` — with nothing else changed. Version 2 is version 1 plus
> what the reading booklets need — a `BookletOnly` flag on `Words`, `Syllables`
> and `Sentences`, and the `Booklet*` tables; see "Where the packs stand". Version 1 was the schema the packs
> already used, written down on 2026-10-16. The model database new languages
> start from is Kalulu-Frontend's `model_database.db`, which Kalulu-ProfTool
> copies, and it follows the same version.

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
| **The game** | Kalulu-Frontend | reads, on the device | `GPs`, `Lessons`, `GPsInLessons`, `Words`, `GPsInWords`, `Syllables`, `GPsInSyllables`, `Sentences`, `WordsInSentences`, `Pseudowords`, `LessonsExercises`; `BookletOnly` from version 2, to leave those entries out |
| **Language Lambda** | Kalulu-Language-Lambda | reads, when a pack ZIP lands on S3; fills MySQL and uploads a copy of the database | `GPs` (`ID`, `Grapheme`, `Phoneme`, `Type`, `Exception`), `GPsInLessons` (lesson IDs come from here, not from `Lessons`); refuses a `user_version` it does not know |
| **Backend** | Kalulu-Backend | reads that copy (`language-db-dumps/<locale>/language.db` on S3) | all of `Words`, `Syllables` and `Lessons` (`SELECT *`), of which it uses `ID` and the text to label remediation scores |
| **Languages Checker** | Kalulu-Languages-Checker | reads, in the tester's browser | `GPs` (`ID`, `Grapheme`, `Phoneme`), `Lessons`, `GPsInLessons`, `Words`, `GPsInWords`, `Syllables`, `GPsInSyllables` — not `Sentences`, which have no recording to review; `BookletOnly` from version 2, to leave those entries out |
| **Booklet generator** | Kalulu-Booklets | reads, from its own pinned checkout of this repository | everything the game reads, `BookletOnly` included, and the `Booklet*` tables; the font files `BookletFonts` names, from `fonts/` |

Measured on 2026-10-15 by reading each program's queries, and on 2026-10-26 for
version 2. Three consequences:

- **Only the Prof Tool reads `Reading`**, and nothing at all reads
  `ExerciseTypes` except the Prof Tool, which maintains it. Filling those cannot
  affect the game, the Lambda, the backend or the Checker. Versions 1 to 3 also
  had a `Writing` flag that only the Prof Tool read; version 4 dropped it.
- **The backend reads `Words`, `Syllables` and `Lessons` with `SELECT *`**, so a
  column added to them reaches it. Version 2's `BookletOnly` does, harmlessly: it
  uses only `ID` and the text, and the game never scores a booklet-only entry.
- **Only the Prof Tool and the booklet generator read the `Booklet*` tables.**
  `BookletOnly` is the one part of version 2 the game reads.

The empty database a new language starts from is `model_database.db` in
Kalulu-Frontend, copied by the Prof Tool. It is part of this contract too, and
must follow the same version as the packs.

## Tables

All IDs are SQLite `AUTOINCREMENT` integer keys. Every foreign key cascades on
update and on delete, but two of version 2's: deleting a lesson that has booklet
chapters is refused (`BookletChapters.LessonID`, `ON DELETE RESTRICT`), and
deleting the GP a chapter's teacher picture comes from leaves the chapter without
one (`ImageGPID`, `ON DELETE SET NULL`). Positions count from **0** and have no gaps — except in the `Booklet*` lists, where only their order counts (rule 8).

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
| `BookletOnly` | `0` | `1` for an entry only the reading booklets print (version 2; `NOT NULL`, unlike the two above); the game leaves it out of its pools — see "The reading booklets" |

Versions 1 to 3 had a fourth flag, `Writing` (default `0`, "used for writing"),
which only the Prof Tool read or wrote and no pack ever set. **Version 4 dropped
it**: what a booklet's writing page prints is chosen in its chapter
(`BookletEntries`), not flagged on the lists.

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

### The reading booklets

Kalulu-Booklets prints, for each pack, a series of A5 booklets that follow the
app's lessons. These tables say what goes in them; only the Prof Tool writes
them and only the generator reads them. The design and the reasons behind it are
in Kalulu-Main's `docs/BOOKLETS-FROM-PACKS.md`.

**`BookletOnly`** on `Words`, `Syllables` and `Sentences` keeps an entry out of
the game: the booklets are running text, and print word forms (`salué`, `amis`,
first names) the game has no recording for. A booklet-only entry is still
decomposed like any other — that is how the booklets know which letters are
silent and from which lesson it can be read.

> **Mark nothing booklet-only in a published pack until the game that honours
> the flag is what players run.** The game reads it from Kalulu-Frontend 3.1.7
> on; an older game ignores the column and would offer those entries like any
> other — without their recordings.

**`BookletSettings`** — exactly one row: whether the language is also written in
cursive (`Cursive`), and the defaults every chapter uses where its own column is
`NULL`:

| Column | Default | Meaning |
|---|---|---|
| `Cursive` | `1` | titles, sentences and writing pages also in cursive. At `0` everything is printed in script, and `SentenceFont` / `SentenceFirstFont` are ignored |
| `SyllableCount` / `SyllableColumns` | `12` / `6` | syllables printed, and their columns (see `BookletEntries` for how they are chosen) |
| | | **Ranges** (rule 8): columns 1–10, counts 0–999, `SentencePages` −1–99, writing copies 0–10, `UppercaseProportion` 0–1 |
| `WordCount` / `WordColumns` | `12` / `4` | words printed, and their columns, chosen as syllables are |
| `UppercaseProportion` | `0` | share of syllables, words and sentences printed in capitals, from 0 to 1 |
| `SentenceFont` | `0` | `0` alternate script and cursive by paragraph, `1` script only, `2` cursive only |
| `SentenceFirstFont` | `2` | when alternating, the first paragraph's: `1` script, `2` cursive |
| `SentencePages` | `1`, written `0` | `-1` no sentence at all; `0` the sentences fit on the page they start on, the chapter page, and the rest is not printed; `1` or more: that many pages more for them. Until 2026-10-27, `1` meant what `0` means now and `0` meant no limit, so the column's `DEFAULT 1` is from then: the packs, the migration and the Prof Tool write `0` |
| `WritingModels` / `WritingTracings` | `1` / `2` | copies of each writing item in black, and in light grey to trace over |
| `ScriptFontID` / `ScriptBoldFontID` / `ScriptBlackFontID` / `CursiveFontID` | `NULL` | the `BookletFonts` row that replaces, everywhere in the language's booklets, the default script (Mulish regular, bold, black) or cursive (Marelle) font; `NULL` keeps the default (version 3). Chapters cannot override them |

**`BookletFonts`** (`Name`, `File`, each unique) — fonts the language's booklets
may print with instead of the default ones (version 3). `File` is the font's
path inside this repository's [`fonts/`](fonts/) folder, folders separated by
`/` (`andika/Andika-Regular.ttf`), and must be a TrueType or OpenType file
there, `.ttf` or `.otf`; `Name` is what the Prof Tool shows. A font is only
listed here: it replaces a default one when a `BookletSettings` font column
names it. Deleting it gives those columns `NULL`, the default, back (`ON DELETE
SET NULL`). **Add the font file to `fonts/` first, with its license in
`fonts/LICENSE.md`**: this repository is public, so it may only hold a font
whose license lets it be redistributed, and the generator loads the file from
there.

**`BookletChapters`** — the booklets' chapters. **They follow the app's
lessons**: a chapter belongs to a lesson (`LessonID`), chapters are ordered by
that lesson's `LessonNb` and then by `Position` among the chapters of the same
lesson, and `Booklet` numbers them 1, 2, 3… along that order, each chapter in the
same booklet as the one before or the next. A lesson that has chapters cannot be
deleted: they would go with it, hand-written lists and stories included. One lesson can
make several chapters (French lesson 13 is "x s t e" and "N n"), and a chapter
can teach nothing new (the consonant clusters). `Title` is printed as written,
`\n` between its lines, nothing when empty. `ImageGPID` names the GP whose
Look & Learn image heads the chapter in the teacher's booklet; `NULL` gives the
chapter no teacher page. `GreySilent` prints silent letters in grey. Every other
column overrides the `BookletSettings` one of the same name.

**Every lesson has a chapter: its first one, the lesson's forced chapter**
(since 2026-10-29). It is always printed, and the Prof Tool lets it go only with
its lesson. The chapters after it in the same lesson are optional: printed
between it and the next lesson's, readable at that lesson, and deletable.
**A lesson with no chapter gets its forced one by default.** The Prof Tool's
Booklets screen makes it when it opens the pack, and it is written at the next
save. Kalulu-Booklets prints the same chapter until then. Each one:

- has the lesson's GPs, in `GPsInLessons` order;
- is titled after them, each grapheme once, exceptions and silent letters left
  out unless nothing else is left, a single letter with its capital (`L l`);
- is at position 0, with no setting of its own, in the booklet of the last
  chapter at or before its lesson: booklet 1 when there is none, so a pack with
  no chapter gets one per lesson, all in booklet 1.

The Prof Tool also gives each one the first of those GPs that has a Look & Learn
image as its teacher's picture. Until 2026-10-29 this applied only while
`BookletChapters` was empty.

**`BookletChapterGPs`** (`ChapterID`, `GPID`, each pair once) — what the chapter teaches. Its
syllables and words are filled from those readable at its lesson that contain
at least one of these GPs.

**`BookletSentences`** (`ChapterID`, `SentenceID`, `Position`, `Break`) — the
chapter's sentences, in order, each a `Sentences` row so that its words are
known. `Break` says what comes before a sentence: `0` it continues the line,
`1` a new line, `2` a new paragraph. Script and cursive alternate by paragraph.
**A chapter that lists no sentence gets as many as fit** in the pages
`SentencePages` allows (none at `-1`), each whole and a paragraph of its own:
the sentences readable at its lesson, exceptions left out, those with a word
holding one of its GPs first, then the others; within each, booklet-only ones
first, then in the pack's order. One that would run onto the next page is
passed over for one that fits, and one the booklet already printed comes after
the others.

**`BookletEntries`** (`ChapterID`, `Part`, `Position`, `Text`, `Text2`,
`Header`) — what is written by hand, stored **as it is printed** ("la Lune",
"un vélo") and matched to `Words` word by word, case ignored, as sentences are.
**A hyphenated form is one word when `Words` has it** ("tam-tam", "arc-en-ciel",
decomposed with the hyphen skipped: t-a-m-t-a-m), **and otherwise the words
between its hyphens** ("as-tu" is `as` and `tu`; the euphonic t of "a-t-il" is no
word and is left out). The Prof Tool, the Sentence List's parser and the
generator all cut this way.
`Part`: `1` syllables, `2` words, `3` writing page, `4` tables, `5` fluency test.
**Syllables and words are picked from the pack**: a syllable is a `Syllables` row's
text as it is stored; a word is a `Words` row's, which may be printed with its
article or capital ("la Lune" for `lune`) as long as it still holds that word.
A chapter prints exactly `SyllableCount` syllables and `WordCount` words: its
picks first, in order, and past the count the last ones are left out; short of
it, the rest is filled from the pack — the syllables or words readable at the
chapter's lesson that hold one of its GPs, exceptions and entries with no vowel
left out, **booklet-only ones first, then in the pack's order** (by `ID`), each
spelling once and none already picked. When even that falls short, what was
chosen is repeated until the count is reached. **The writing page, the tables
and the fluency test are picked from the pack too**: each writing model, each
table cell and each fluency item is a `GPs` grapheme, a syllable, a word or a
sentence of the pack. It may be printed differently ("La Lune" for `lune`) as
long as it still holds what was picked, and the Prof Tool refuses to save one
that does not. These three parts are printed as listed, with no automatic
choice. A table row holds its right cell in `Text2`; `Header = 1` marks a bold
row, which starts a new table.

**`BookletStories`** (`ChapterID`, `Position`, `Title`, `Text`) — stories, free
text, paragraphs separated by an empty line. Their words need not be in `Words`;
the Prof Tool points out those that are not, or not yet taught.

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
7. `BookletOnly` is `0` or `1` — the game keeps only the `0`s, so any other
   value takes an entry out of it — and a sentence the game can offer
   (`BookletOnly = 0`) holds no booklet-only word.
8. The booklet tables can be read: one `BookletSettings` row; every value of
   its SQLite type (a number where a number is meant — SQLite would store text)
   and within its range; text the generator reads — `Words`, `Syllables`,
   `Sentences` and the booklet tables' — in valid UTF-8, which a strict reader
   needs; booklets numbered 1, 2, 3… along the chapters, each
   chapter in the same booklet as the one before or the next; one order in every
   list — chapters within a lesson, sentences and stories within a chapter,
   entries within a chapter's part — meaning no position used twice and none
   below 0. **Gaps are allowed**: deleting a sentence from the Sentence List
   removes it from its chapters by `ON DELETE CASCADE` and leaves one, and the
   order is still the order. Every `BookletFonts` row has a name and names a
   `.ttf` or `.otf` file of `fonts/` that is a TrueType or OpenType font.
9. What a chapter teaches, and the sentences it prints, are readable at its
   lesson: every word of a sentence decomposed, and every GP in them taught by
   that lesson or an earlier one.
10. Every font `BookletFonts` names is listed in `fonts/LICENSE.md`, the record
    of what this repository may redistribute.

Known breaches, as of 2026-10-22: one. In `fr_FR`, `payons` has no decomposition at
all (rule 1). Its spelling needs an `ay` GP the pack does not have, and how to
teach it is waiting for the experts. The seven French words that lost a GP and
`es_CO`'s lesson 37 without minigames were fixed in October 2026. In `fr_FR`,
lessons 37 and 40 list the same minigame twice — allowed by these rules, possibly
a mistake. Details in Kalulu-Main's `docs/agent/Kalulu-Languages.BUG.md`.

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
| error | `user_version` is not the newest `schema/v<n>.sql` (rule 5); tables, columns, types, defaults, keys or indexes differ from that file; `integrity_check` fails; `foreign_key_check` finds rows pointing at nothing; rules 2, 3, 4, 6, 7 and 8 | the check fails |
| warning | rules 1, 9 and 10 | reported; `--strict` makes them fail too. Rule 1 becomes an error once `payons` is settled |
| notice | a rule that could not be checked, and why: a non-blocking rule (1, 9), or any rule on a pack whose structure already fails | reported only |

A blocking rule that cannot run on a pack following the schema — an SQLite error
reading its data — is an error, not a notice: it would otherwise pass silently.
Text that is not valid UTF-8 is read with replacement characters, so it shows in
the report instead of stopping a rule.

**Rules 2, 3, 4 and 6 are errors although they are data rules**, because a pack
that breaks one fails children in the game, silently:

- rule 2 — every word and syllable holding a GP no lesson teaches is never offered.
  It holds for booklet-only words too, which the game never offers: a booklet
  prints a word from the lesson its GPs are taught in, so a GP no lesson teaches
  leaves the word with no place in any booklet either;
- rule 3 — a lesson without a minigame row, or with three empty slots, has
  nothing to play, and a slot naming no minigame points at one that does not
  exist;
- rule 4 — lessons name their minigames by number, so a list that differs from the
  game's plays the wrong one;
- rule 6 — the Language Lambda would write the wrong lesson numbers into
  production MySQL.

They became errors on 2026-10-22, when no pack broke them any more. Rule 1 stays a
warning only while one known case waits for a decision.

**Rules 7 and 8 are errors from the start**, version 2 having no data to break
them: rule 7 for the same reason as the four above — a game sentence holding a
booklet-only word brings back into the game what it was told to leave out — and
rule 8 because the generator cannot read booklet tables that break it. **Rule 9
is a warning**: a chapter printing a word its lesson cannot read yet is the
booklets' content to put right, and never reaches the game. **Rule 10 is a
warning** too: a font missing from `LICENSE.md` prints, but its record has to be
written before the pull request is merged.

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

**Every pack follows version 4** since 2026-10-27: structure identical to
`schema/v4.sql`, `user_version = 4`. All five were migrated from version 3 with
[`schema/v3-to-v4.sql`](schema/v3-to-v4.sql) (the sqlite3 shell, 3.35 or later
for `DROP COLUMN`; it refuses any pack that is not version 3), which drops the
`Writing` column of `Words`, `Syllables` and `Sentences`. No pack had set it on
any row. Every other column of every table kept every row and every value, and
`es_AR` and `es_UY` are still byte-identical. The `WRITING` column left
`words_list.csv` and `syllables_list.csv` in the same change. As for version 3,
publishing needs the Language Lambda that reads version 4, and editing needs a
Prof Tool that knows it.

**Version 3, 2026-10-27**: structure identical to
`schema/v3.sql`, `user_version = 3`. All five were migrated from version 2 with
[`schema/v2-to-v3.sql`](schema/v2-to-v3.sql) (the sqlite3 shell again; it
refuses any pack that is not version 2), which adds the empty `BookletFonts`
table and the four `BookletSettings` font columns, `NULL` everywhere, so every
booklet keeps its default fonts. Every table of version 2 kept every row and
every value, checked table by table against the version 2 databases, and
`sqlite_sequence` is unchanged. `es_AR` and `es_UY` are still byte-identical.

- **The game reads none of it**, and does not check the version: nothing changes
  on a device but the pack downloading again after the next publish.
- **Publishing a version 3 pack needs the Language Lambda that reads it**, as for
  version 2: until its version 3 support is deployed, *Publish Language Packs*
  fails at the Lambda for every pack.
- **A Prof Tool older than version 3 refuses these packs** (`PackSchema`), so
  editing them needs the release that adds version 3.

**Version 2, 2026-10-26** (migrated again on 2026-10-27,
as version 2 was revised in review before it was merged): structure identical to
`schema/v2.sql`, `user_version = 2`. All five were migrated from version 1 with
[`schema/v1-to-v2.sql`](schema/v1-to-v2.sql) (run with the sqlite3 shell: its `.bail on` makes a
failure roll the whole transaction back; it refuses any pack that is not version
1, so a second run changes nothing), which adds and fills nothing but
the new: the `BookletOnly` columns (`0` everywhere, so every entry stays the
game's), the empty `Booklet*` tables, and the one `BookletSettings` row with its
defaults. Every table of version 1 kept every row and every value, checked table
by table against the version 1 databases; the only other change is
`sqlite_sequence` gaining the `BookletSettings` counter. `es_AR` and `es_UY` are
still byte-identical.

- **The first publish after this change re-sends all five packs**: each pack's
  tree changed, so *Publish Language Packs* uploads every one, the Lambda runs on
  DEV and PROD for each, and every device downloads its pack again.
- **Publishing a version 2 pack needs the Language Lambda that reads it.** The
  Lambda refuses a `user_version` it does not know before writing anything, so
  until its version 2 support is deployed, *Publish Language Packs* would fail at
  the Lambda for every pack.
- **A Prof Tool older than version 2 refuses these packs** when it opens them
  (`PackSchema`, since 1.5.2), so it cannot write them back as version 1.

**Version 1, 2026-10-16**: structure identical to `schema/v1.sql`,
`user_version = 1`. Before that, none carried a version, and four of the five
differed from it:

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
