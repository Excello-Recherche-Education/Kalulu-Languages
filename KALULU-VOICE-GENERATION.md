# Generating Kalulu's voice lines

How the `<locale>/language_sounds/kalulu/*.mp3` files are produced: the narrator lines
Kalulu speaks on the menus, the gardens, and inside the minigames.

This covers **Kalulu's voice only**. Word, syllable, grapheme-phoneme, and Look & Learn
recordings live directly under `language_sounds/` and are a separate job.

Written after generating `brain_screen_victory.mp3` for all five packs (2026-08-20).

---

## The pipeline

macOS speech synthesis, then a re-encode. No external service, no API key.

```bash
say -v "<voice>" -o raw.aiff "<text>"                       # AIFF, mono, 22050 Hz
ffmpeg -y -i raw.aiff -af "volume=<gain>dB" \
       -ac 1 -ar 22050 -b:a 64k out.mp3
```

`say` writes AIFF at 22050 Hz mono 16-bit big-endian. The `volume` gain is **not
optional and not a constant** — see [Matching the pack's level](#matching-the-packs-level),
which is the part that takes the thinking.

`-ac 1 -ar 22050 -b:a 64k` is the repository's canonical audio target, the same one
`.github/workflows/optimize-media-assets.yml` enforces.

### Voices

One per locale, all from Apple's high-quality tier. macOS calls that tier
**"Enhanced"** (some are also offered as "Premium") — there is no voice literally
named "Premium".

| Locale | Voice | Notes |
|---|---|---|
| `fr_FR` | `Thomas (Enhanced)` | |
| `es_AR` | `Diego (Enhanced)` | |
| `es_CO` | `Carlos (Enhanced)` | |
| `es_UY` | — | Do not generate. See [es_UY is a copy of es_AR](#es_uy-is-a-copy-of-es_ar) |
| `pt_BR` | `Felipe (Enhanced)` | |

These are **not installed by default**. Install them under
**System Settings → Accessibility → Spoken Content → System Voice → Manage Voices**,
then confirm:

```bash
say -v '?' | grep -iE "enhanced|premium"
```

A voice that is not installed makes `say` fail; it does not silently fall back.

---

## Matching the pack's level

**Every pack sits at a different loudness, and the difference is large.** Reusing one
pack's gain for another produces a line that is audibly wrong. Measured across the
existing `kalulu/` folders:

| Pack | Median loudness | Spread |
|---|---|---|
| `fr_FR` | −15.5 LUFS | narrow |
| `pt_BR` | −15.4 LUFS | −17.8 to −13.7 |
| `es_AR` | −20.4 LUFS | −18.4 to −21.9 |
| `es_CO` | **−28.1 LUFS** | −30.9 to −13.1 |

`fr_FR` and `es_CO` are **13 dB apart**. There is no single gain that works for both.

### Why this matters at playback

`Kalulu-Frontend/resources/audio_buses/main_audio_bus_layout.tres` gives the `Voice`
bus +6 dB and **no effects** — no compressor, no limiter. Nothing rescues a level
mismatch at runtime; whatever the file contains is what the child hears.

### Do not normalize the peak

The obvious approach — normalize to 0 dB peak like the surrounding files — is wrong.
The `es_AR` and `es_CO` files peak at 0 dB but carry their speech far below that
(loudness range only 0.9–3.2 LU, so this is not wide dynamics; they simply have an
isolated transient at full scale). Peak-normalizing a fresh `say` recording, whose
speech body sits much closer to its peak, lands 5 dB too loud in `es_AR` and 14 dB
too loud in `es_CO`.

**Match integrated loudness (LUFS), not peak.**

### Procedure

1. Measure the **direct siblings** of the file you are creating — the other lines on
   the same screen, not the whole folder. `gardens_screen_intro` in `es_CO` is a
   −14.1 LUFS outlier among neighbours at −27 to −31; a folder-wide average would
   have been dragged off target.

   ```bash
   cd <locale>/language_sounds/kalulu
   for f in brain_screen_*.mp3 gardens_screen_*.mp3; do
     printf "%-34s " "$f"
     ffmpeg -i "$f" -af ebur128 -f null - 2>&1 \
       | grep -A4 "Integrated loudness" | grep -oE "I: +-?[0-9.]+ LUFS"
   done
   ```

2. Synthesize, and measure the raw AIFF the same way.

3. `gain = target − raw`. Add `,alimiter=limit=0.99:attack=5:release=60` after the
   `volume` filter **only for a positive gain**, to catch the few peaks it pushes up.

4. Verify (below). Iterate on the gain if the result missed by more than ~1 dB —
   the mp3 encode shifts things slightly.

### Levels used for `brain_screen_victory.mp3`

| Pack | Raw | Gain | Result | Sibling range |
|---|---|---|---|---|
| `fr_FR` | −18.1 | **+2.9 dB** + limiter | −15.1 LUFS | −14.9 to −16.1 |
| `es_AR` | −17.8 | **−2.0 dB** | −19.9 LUFS | −18.8 to −21.9 |
| `es_CO` | −17.8 | **−10.7 dB** | −28.9 LUFS | −27.2 to −30.9 |
| `pt_BR` | −17.9 | **+2.6 dB** + limiter | −15.7 LUFS | −14.5 to −16.2 |

---

## Verification

Never trust the encode blind. Check format, loudness, and that nothing clipped:

```bash
f=out.mp3
afinfo "$f" | grep -E "Data format|duration"
ffmpeg -i "$f" -af ebur128    -f null - 2>&1 | grep -A4 "Integrated loudness" | grep -oE "I: +-?[0-9.]+ LUFS"
ffmpeg -i "$f" -af volumedetect -f null - 2>&1 | grep -oE "max_volume: -?[0-9.]+ dB"
ffmpeg -i "$f" -af astats=metadata=1 -f null - 2>&1 | grep -oE "Flat factor: [0-9.]+" | head -1
```

Expected: `1 ch, 22050 Hz`, loudness inside the sibling range, and **`Flat factor: 0`**
— a non-zero flat factor means consecutive samples pinned at full scale, i.e. real
clipping. A peak reading of `-0.0 dB` on its own is fine; some shipped files overshoot
to +1.8 dB.

Then **listen to it**. Measurements cannot catch a mispronunciation, and synthesis
does mangle words. If a word comes out wrong, adjust punctuation or insert pauses
(`[[slnc 300]]`) rather than changing voice.

---

## Writing the text

The line has to be written for the locale, not translated word for word from French.
Check the register the pack already uses instead of assuming from the country:

```bash
grep -oiE "\b(você|vos|tú|sabés|sabes|tenés|tienes|sos|eres)\b" \
  <locale>/sentences_list.csv | sort | uniq -c | sort -rn
```

- **`es_AR`, `es_CO`, `es_UY` all use neutral Spanish with *tuteo*** ("Tienes",
  "Sabes", "Mira") — no Argentine or Uruguayan *voseo*, despite the locale names.
  Their `sentences_list.csv` files are byte-identical (same md5), so **one Spanish
  text serves all three**.
- **`pt_BR` uses *você*.** Avoid repeating the pronoun in every clause; Brazilian
  Portuguese drops it naturally once established. "Parabéns" is warmer than a literal
  "Bravo".

Length is free: `brain_reward.gd` does `await _voice_player.finished` rather than
running a timer, and `kalulu_animator.gd` loops the `Talk` animation with random
blink/ear variants for as long as the audio lasts. The victory line went from 4.4 s
to 11.3 s with no code change.

### Texts used for `brain_screen_victory.mp3`

**fr_FR**
> Bravo mon ami, tu as terminé toutes les leçons, maintenant tu sais lire. Tu peux
> partir explorer le monde, toutes les connaissances te sont désormais accessibles.
> Je suis fier de toi !

**es_AR / es_CO / es_UY**
> ¡Bravo, amigo mío! Has terminado todas las lecciones, ahora sabes leer. Puedes
> salir a explorar el mundo, todos los conocimientos están ahora a tu alcance.
> ¡Estoy orgulloso de ti!

**pt_BR**
> Parabéns, meu amigo! Você terminou todas as lições, agora você sabe ler. Pode sair
> para explorar o mundo, todo o conhecimento está agora ao seu alcance. Estou
> orgulhoso de você!

---

## es_UY is a copy of es_AR

All 75 files in `es_UY/language_sounds/kalulu/` are **byte-identical** to `es_AR`'s.
The pack holds no recordings of its own for Kalulu's voice.

So do not synthesize for `es_UY` — copy, or the two packs drift apart for no reason
(a fresh encode of the same text yields different bytes):

```bash
cp es_AR/language_sounds/kalulu/<name>.mp3 es_UY/language_sounds/kalulu/<name>.mp3
```

Confirm the parity still holds afterwards:

```bash
n=0; for f in es_UY/language_sounds/kalulu/*.mp3; do
  [ "$(md5 -q "$f")" = "$(md5 -q "es_AR/language_sounds/kalulu/$(basename "$f")")" ] && n=$((n+1))
done; echo "$n identical"
```

This parity applies to `kalulu/` **only**. The two packs' *word* sounds diverged when
`es_AR voices normalization` (commit `c642d5f9`) regenerated 1,517 files in `es_AR`
and left `es_UY` untouched.

---

## Which files a pack needs

The frontend requests **48 speeches**, all through a single funnel —
`Database.get_kalulu_speech_path(category, name)` in
`Kalulu-Frontend/sources/utils/autoloads/database.gd`, resolving to:

```
<locale>/language_sounds/kalulu/<category>_<name>.mp3
```

Do not maintain that list by hand. `Kalulu-Frontend/.github/scripts/check_kalulu_speeches.py`
cross-checks what the game requests, what the Prof Tool offers a slot for, and what
each pack ships:

```bash
python3 Kalulu-Frontend/.github/scripts/check_kalulu_speeches.py \
  --frontend Kalulu-Frontend --packs Kalulu-Languages
```

It runs on every frontend pull request and comments the report. Two blind spots to
keep in mind:

- **It compares file names, never content.** A file copied from a sibling to fill a
  gap reads as present. `fr_FR/boss_help.mp3` is a byte-identical copy of
  `boss_intro.mp3`, so no pack actually has a boss help line even though the count
  says 51/51. Find them by hashing the folder:

  ```bash
  cd <locale>/language_sounds/kalulu
  md5 -r *.mp3 | sort \
    | awk '{if ($1 == prev) print "  " prevfile " == " $2; prev = $1; prevfile = $2}'
  ```
- **Its "rename" verdicts on legacy files mislead.** It reports
  `garden_screen_*` as a misspelling of the live `gardens_screen`, but those line
  *names* do not exist either — they are leftovers from a retired screen layout and
  should be deleted, not renamed.

---

## Gotchas

- **`say --data-format` breaks the output.** `--data-format=LEI16@22050` fails with
  `Opening output file failed: fmt?` and leaves a 0-byte file. Omit it; the default is
  already 22050 Hz mono, which is what we want.
- **Never carry a gain between packs.** Re-measure. See the 13 dB spread above.
- **`fr_FR` is at 44100 Hz**, unlike every other pack and unlike the canonical
  `-ar 22050`. `brain_screen_victory.mp3` was matched to its 44100 Hz siblings rather
  than to the repository target. Worth reconciling one day, in one pass, deliberately.
- **`pt_BR` has two competing formats** — 23 files at 22050 Hz/64 kbps and 23 at
  44100 Hz/VBR 116–181 kbps, mixed even within the `brain_screen_*` family. New files
  follow 22050 Hz/64 kbps.
- **`es_CO` is very quiet overall** (median −28.1 LUFS, 36 of 46 files below −25).
  New files match their siblings so they do not stick out, but the folder arguably
  wants one renormalization pass to around −16 LUFS.
- **MP3s are LFS-tracked** (`*.mp3` in `.gitattributes`). Copying a file into place is
  enough; `git add` applies the filter.
