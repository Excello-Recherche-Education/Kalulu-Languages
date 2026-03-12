# Kalulu-Languages

Language packs used by the [Kalulu](https://github.com/Excello-Recherche-Education/Kalulu) application, an open-source educational game that helps children learn to read through grapheme-phoneme decoding.

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
├── version.txt              # ISO 8601 timestamp of the last pack generation
├── language_sounds/         # Audio files (MP3) — words, phonemes, syllables
├── tracing_data/            # Letter tracing data (CSV coordinate paths)
│   └── <letter>_lower.csv, <letter>_upper.csv
└── look_and_learn/          # Multimedia assets for the "look and learn" activity
    ├── images/              # GP images (PNG)
    ├── sounds/              # GP sounds (MP3)
    └── video/               # GP videos (OGV)
```

## SQLite database (`language.db`)

The database contains 14 tables describing the pedagogical progression:

| Table | Description |
|-------|-------------|
| `GPs` | Grapheme-phoneme correspondences (grapheme, phoneme, vowel/consonant type, exception flag) |
| `Lessons` | Numbered lessons (1 to 60) |
| `GPsInLessons` | GP ↔ lesson association (which GP is introduced in which lesson) |
| `Words` | Vocabulary words with reading/writing flags |
| `GPsInWords` | GP breakdown of each word with position |
| `Syllables` | Syllables available for exercises |
| `GPsInSyllables` | GP breakdown of each syllable with position |
| `Sentences` | Sentences composed of vocabulary words |
| `WordsInSentences` | Word ↔ sentence association with position |
| `Pseudowords` | Pseudowords generated from real words (decoding exercises) |
| `LessonsExercises` | Exercise types assigned to each lesson |
| `ExerciseTypes` | Exercise type reference table |
| `LettersTracingData` | Letter tracing paths (may be empty if tracing data lives in `tracing_data/`) |

## CSV files

### `gp_list.csv`
Columns: `Grapheme, Phoneme, Type, Exception`
Flat list of grapheme-phoneme correspondences. `Type` is `Vowel` or `Consonant`. `Exception = 1` for irregular graphemes.

### `words_list.csv`
Columns: `ORTHO, GPMATCH, LESSON, READING, WRITING`
Each word includes its GP breakdown in parentheses (e.g. `(a-a.b-b.r-R.i-i)` for "abri") and the lesson number where it is introduced.

### `syllables_list.csv`
Columns: `ORTHO, GPMATCH, LESSON, READING, WRITING`
Same format as words, applied to syllables.

### `sentences_list.csv`
Columns: `Sentence, Lesson`
Sentences used in exercises, associated with a lesson number.

### `summary.txt`
Human-readable lesson-by-lesson view listing the words, syllables, and sentences introduced at each step of the progression.

## How language packs are used

Language packs are consumed in two ways:

1. **By the Godot frontend** — downloaded as a ZIP archive via a presigned S3 URL provided by the backend. The game loads `language.db` and the audio/visual assets to drive the exercises.

2. **By the Language Lambda** — when an updated pack is uploaded to S3, the `Kalulu-Language-Lambda` extracts `language.db`, distributes the lessons across 20 gardens, and updates the backend's MySQL tables (DEV + PROD).

## Releases

When a pull request is merged into `main`, a GitHub Actions workflow automatically:

1. Detects all locale folders (matching the `xx_XX` pattern)
2. Compresses each one into a ZIP archive (e.g. `fr_FR.zip`, `pt_BR.zip`)
3. Creates a new GitHub Release with all ZIP files attached as downloadable assets

Each language pack can be downloaded directly from the [Releases page](../../releases). The latest packs are always available at:

```
https://github.com/Excello-Recherche-Education/Kalulu-Languages/releases/latest/download/<locale>.zip
```

For example: `.../releases/latest/download/fr_FR.zip`

## Adding or modifying a language

To add or modify a language pack, use the **Prof_Tool** included in the [Kalulu frontend repository](https://github.com/Excello-Recherche-Education/Kalulu). Prof_Tool provides a graphical interface to edit linguistic data (grapheme-phoneme correspondences, words, syllables, sentences) and export a complete, ready-to-deploy language pack.

For more details on Prof_Tool and the overall Kalulu architecture, see the [Kalulu frontend README](https://github.com/Excello-Recherche-Education/Kalulu#readme).
