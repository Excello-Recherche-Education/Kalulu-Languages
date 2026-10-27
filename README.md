# Kalulu-Languages

Language packs used by the [Kalulu](https://github.com/Excello-Recherche-Education/Kalulu-Frontend) application, an open-source educational game that helps children learn to read through grapheme-phoneme decoding.

## Available languages

| Folder | Language | Graphemes | Words | Sentences | Sounds | Tracing |
|--------|----------|-----------|-------|-----------|--------|---------|
| `fr_FR` | French (France) | 118 | 2,495 | 254 | 3,436 | 78 |
| `es_AR` | Spanish (Argentina) | — | — | — | 1,747 | 66 |
| `es_CO` | Spanish (Colombia) | — | — | — | 1,644 | 66 |
| `es_UY` | Spanish (Uruguay) | — | — | — | 1,747 | 66 |
| `pt_BR` | Portuguese (Brazil) | — | — | — | 2,202 | 88 |

## Language pack structure

Each `<locale>` folder follows the same layout:

```
<locale>/
├── language.db              # SQLite database — single source of truth for linguistic data
├── gp_list.csv              # Grapheme-phoneme correspondences
├── words_list.csv           # Words with GP breakdown and lesson level
├── syllables_list.csv       # Syllables with GP breakdown
├── sentences_list.csv       # Sentences associated with each lesson
├── summary.txt              # Human-readable lesson-by-lesson summary (words, syllables, sentences)
├── version.txt              # ISO 8601 UTC timestamp of the last change to this pack
├── language_sounds/         # Audio files (MP3) — words, phonemes, syllables
├── tracing_data/            # Letter tracing data (CSV coordinate paths)
│   └── <letter>_lower.csv, <letter>_upper.csv
└── look_and_learn/          # Multimedia assets for the "look and learn" activity
    ├── images/              # GP images (PNG)
    ├── sounds/              # GP sounds (MP3)
    └── video/               # GP videos (OGV)
```

## SQLite database (`language.db`)

The database contains 19 tables describing the pedagogical progression. Its exact
structure, who reads which part of it, and the rules the data must follow are in
[SCHEMA.md](SCHEMA.md) (schema version 2, [`schema/v2.sql`](schema/v2.sql)).

| Table | Description |
|-------|-------------|
| `GPs` | Grapheme-phoneme correspondences (grapheme, phoneme, vowel/consonant type, exception flag) |
| `Lessons` | Numbered lessons (60 in `fr_FR`) |
| `GPsInLessons` | GP ↔ lesson association (which GP is introduced in which lesson) |
| `Words` | Vocabulary words with reading/writing flags, and a booklet-only flag |
| `GPsInWords` | GP breakdown of each word with position |
| `Syllables` | Syllables available for exercises |
| `GPsInSyllables` | GP breakdown of each syllable with position |
| `Sentences` | Sentences composed of vocabulary words |
| `WordsInSentences` | Word ↔ sentence association with position |
| `Pseudowords` | Pseudowords generated from real words (decoding exercises) |
| `LessonsExercises` | The one to three minigames of each lesson (`0` = no minigame in that slot) |
| `ExerciseTypes` | Exercise type reference table |
| `LettersTracingData` | Unused and empty in every pack: letter tracings live in `tracing_data/` |
| `BookletSettings`, `BookletChapters`, `BookletChapterGPs`, `BookletSentences`, `BookletEntries`, `BookletStories` | What the printed reading booklets ([Kalulu-Booklets](https://github.com/Excello-Recherche-Education/Kalulu-Booklets)) contain, chapter by chapter |

## CSV files

### `gp_list.csv`
Columns: `Grapheme, Phoneme, Type, Exception`
Flat list of grapheme-phoneme correspondences. `Type` is `Vowel` or `Consonant`. `Exception = 1` for irregular graphemes.

### `words_list.csv`
Columns: `ORTHO, GPMATCH, LESSON, READING, WRITING, BOOKLET_ONLY` (the last one written by the Prof Tool from schema version 2 on)
Each word includes its GP breakdown in parentheses (e.g. `(a-a.b-b.r-R.i-i)` for "abri") and the lesson number where it is introduced.

### `syllables_list.csv`
Columns: `ORTHO, GPMATCH, LESSON, READING, WRITING, BOOKLET_ONLY`
Same format as words, applied to syllables.

### `sentences_list.csv`
Columns: `Sentence, Lesson, BookletOnly`
Sentences used in exercises, associated with a lesson number.

### `summary.txt`
Human-readable lesson-by-lesson view listing the words, syllables, and sentences introduced at each step of the progression.

## How language packs are used

Language packs are consumed in two ways:

1. **By the Godot frontend** — downloaded as a ZIP archive via a presigned S3 URL provided by the backend. The game loads `language.db` and the audio/visual assets to drive the exercises.

2. **By the Language Lambda** — when an updated pack is uploaded to S3, the `Kalulu-Language-Lambda` extracts `language.db`, distributes the lessons across 20 gardens, and updates the backend's MySQL tables (DEV + PROD).

## Publishing to the app

What the game downloads, and what the Language Lambda reads, is `<locale>.zip` at
the root of the language-pack S3 bucket. The **Publish Language Packs** workflow
puts it there, and is the only way it gets there:

1. Merge the pull request carrying the change — it has passed the pack validator.
2. **Actions → Publish Language Packs → Run workflow**, on `main`. Give the packs to
   publish (`all`, or e.g. `es_AR es_CO`). Tick *dry run* to build and check the
   ZIPs without uploading them.

The workflow validates the packs again, checks that every media file was fetched
from LFS, builds each ZIP in the layout the app and the Language Lambda read (one
top-level `<locale>/` folder), and uploads it with its SHA-256, which S3 verifies. Each object
records the commit and the run it came from, and the bucket keeps every previous
version.

**A pack that has not changed since it was last published is skipped**, so `all` is
safe to run: an upload changes the object's date, which makes every device download
the pack again, and runs the Language Lambda. "Changed" means the content of the
`<locale>/` folder (its git tree, stored on the object as a fingerprint), not the
ZIP, which differs on every run. Tick *force* to upload unchanged packs anyway. The
run summary says, pack by pack, what was uploaded or skipped and why; a dry run says
what would be.

**Every upload starts the Language Lambda**, which rewrites that language's lessons
and gardens in DEV *and* PROD MySQL. Devices download the new pack the next time
they check. Run it on purpose, not as a test — the dry run is the test.

The `Languages-Checker/` folder, which the volunteer testers' web tool reads, is not
touched: copying a pack there stays a manual step.

## Releases

The **Release Language Packs** workflow, run by hand, zips every locale folder
(matching the `xx_XX` pattern) and attaches the ZIPs to a new GitHub Release. A
release is an archive for people; it reaches neither the app nor the testers.

Each language pack can be downloaded from the [Releases page](../../releases). The latest packs are always available at:

```
https://github.com/Excello-Recherche-Education/Kalulu-Languages/releases/latest/download/<locale>.zip
```

For example: `.../releases/latest/download/fr_FR.zip`

## Media optimization

A GitHub Actions workflow is available to optimize all media assets (PNG images, MP3 audio, OGV videos) across every language pack. It is designed for tablet/phone targets where ultra-high quality is unnecessary.

**How to run it:** go to **Actions → Optimize Media Assets → Run workflow**. All parameters have sensible defaults but can be tuned per run.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `png_max_dimension` | `2048` | Images wider or taller than this are resized down (aspect ratio preserved) |
| `png_lossy_quality` | `65-80` | pngquant quality range — lower values produce smaller files |
| `mp3_bitrate` | `64k` | Target bitrate for speech audio (mono, 22050 Hz) |
| `ogv_crf` | `6` | libtheora quality factor (0–10, higher = better) |
| `ogv_max_height` | `720` | Videos taller than this are scaled down (aspect ratio preserved) |

**Tools used:**

| Asset | Tool | Strategy |
|-------|------|----------|
| PNG | [oxipng](https://github.com/shssoichiro/oxipng) | Lossless metadata stripping and recompression |
| PNG | [pngquant](https://pngquant.org/) | Lossy palette reduction (skipped if result is larger) |
| PNG | ImageMagick | Resize oversized images while preserving aspect ratio |
| MP3 | ffmpeg | Re-encode to target bitrate (skipped if already at/below target) |
| OGV | ffmpeg | Re-encode with libtheora + libvorbis, optional downscale |

An optimized file is only kept if it is **strictly smaller** than the original — the workflow never makes things worse. If any files are improved, the workflow automatically creates a pull request to `main` on the branch `chore/optimize-media-assets`.

## Kalulu's voice lines

The narrator lines Kalulu speaks on the menus, in the gardens, and inside the minigames live in `<locale>/language_sounds/kalulu/`. They are synthesized with macOS `say` using a high-quality ("Enhanced") voice per locale, then re-encoded with ffmpeg.

See **[KALULU-VOICE-GENERATION.md](KALULU-VOICE-GENERATION.md)** for the full procedure: which voice each locale uses, the texts, and — the part that matters most — how to match each pack's own loudness, since the packs sit as much as 13 dB apart and the game applies no compression at playback.

## Adding or modifying a language

To add or modify a language pack, use the **[Kalulu Prof Tool](https://github.com/Excello-Recherche-Education/Kalulu-ProfTool)**, the language-pack editor. It has a repository of its own (it used to live inside Kalulu-Frontend), and ready-to-run builds for macOS, Windows and Linux are on its [releases page](https://github.com/Excello-Recherche-Education/Kalulu-ProfTool/releases). It provides a graphical interface to edit the linguistic data — grapheme-phoneme correspondences, words, syllables, sentences, lessons and their minigames, letter tracings, Look & Learn media and recordings.

The Prof Tool works on the pack folders of this repository directly, with no archive in between:

1. **Open language.db** and pick `<locale>/language.db` in a checkout of this repository. The Prof Tool works on its own copy of that pack folder.
2. Edit the pack.
3. **Save** onto the same `<locale>/language.db`. The Prof Tool regenerates the CSV lists, `summary.txt` and `version.txt`, then writes the whole pack back into that folder.
4. Commit the result on a branch and open a pull request — see [How the packs are checked](SCHEMA.md#how-the-packs-are-checked).

Saving overwrites files but never deletes any: a file removed from a pack in the Prof Tool has to be removed from this repository by hand, in the same pull request.

For more on the Prof Tool itself, see its [README](https://github.com/Excello-Recherche-Education/Kalulu-ProfTool#readme); for the overall Kalulu architecture, the [Kalulu frontend README](https://github.com/Excello-Recherche-Education/Kalulu-Frontend#readme).

**Whatever the route, update the pack's `version.txt`** so it always carries the date of
the last change made to that pack:

```bash
date -u +%Y-%m-%dT%H:%M:%S > <locale>/version.txt
```

Saving from the Prof Tool writes this file itself, so it is already correct. Anything
edited outside the Prof Tool — a CSV by hand, an MP3 re-recorded under `language_sounds/`,
tracing or look-and-learn media, `language.db` patched in place — must be stamped in the
same commit. The timestamp travels into every Checker report as `pack_version`, so a stale
one attributes a tester's feedback to a pack that no longer exists.

---

## Related Repositories

| Repository | Description |
|---|---|
| [Kalulu (Frontend)](https://github.com/Excello-Recherche-Education/Kalulu-Frontend) | The Godot-based reading game for children |
| [Kalulu Prof Tool](https://github.com/Excello-Recherche-Education/Kalulu-ProfTool) | The language-pack editor these packs are made with |
| [Kalulu Backend](https://github.com/Excello-Recherche-Education/Kalulu-Backend) | Serverless API — authentication, sync, dashboards, and data management |
| [Kalulu Language Lambda](https://github.com/Excello-Recherche-Education/Kalulu-Language-Lambda) | Pipeline that processes language packs and updates the database |

---

Built with care by [Excello Recherche & Education](https://github.com/Excello-Recherche-Education)

We also have a [website](https://excellolab.org/)
