# Fonts

The two typefaces Kalulu prints and displays its reading content with. They are
kept here, beside the language packs, because every program that shows a pack's
text to a child uses them: the game, and the printed reading booklets.

| Typeface | Folder | Used for | Version | License | Modified |
|---|---|---|---|---|---|
| **Mulish** | [`mulish/`](mulish/) | script (print) letters | 3.603, Black from an earlier release | SIL Open Font License 1.1 | **yes, by Excello** — see below |
| **Marelle** | [`marelle/`](marelle/) | cursive letters, as taught in French schools | 1.005 | SIL Open Font License 1.1 | no |

Both are free software: they may be used, copied, embedded in documents and
apps, and redistributed, including commercially, under the terms of the
[SIL Open Font License, version 1.1](https://openfontlicense.org). The license
text travels with each typeface, in its folder's `OFL.txt`, as the license
requires. Nothing in this folder is under the CC BY-SA 4.0 license that covers
the rest of this repository: these files are under the OFL only.

---

## Mulish

| | |
|---|---|
| Designer | Vernon Adams, and the Mulish Project Authors |
| Original copyright | Copyright 2016 The Mulish Project Authors (<https://github.com/googlefonts/mulish>); Black: Copyright 2011 The Mulish Project Authors |
| Kalulu modifications | Copyright 2023 (Regular, Bold) and 2025 (Black) Excello Recherche & Éducation |
| License | SIL Open Font License 1.1 — [`mulish/OFL.txt`](mulish/OFL.txt) |
| Reserved Font Name | none |
| Source | <https://github.com/googlefonts/mulish> |

| File | Weight |
|---|---|
| `kalulu_mulish_regular.otf` | Regular |
| `kalulu_mulish_bold.otf` | Bold |
| `kalulu_mulish_black.otf` | Black |

### This is a Modified Version

Kalulu's Mulish is not the font as Google Fonts distributes it. **Two letters
were redrawn**, in all three weights, so that a beginning reader cannot mistake
one letter for another:

| Letter | Change |
|---|---|
| `I` (capital i) | given serifs, top and bottom, across the whole width of the letter, so that it no longer looks like a lowercase `l` |
| `t` | its foot redrawn to rest on the baseline instead of dipping just below it |

Every other letter of Regular and Bold has the outline and the advance width of
Mulish 3.603 (checked glyph by glyph against it). Their OpenType tables are
simpler than that release's: ligatures (`liga`) and kerning (`kern`) only, with
fewer kerning pairs — `AV` or `To` are spaced a little wider than in Google's
build. The Black weight comes from an earlier Mulish release and shows the same
two changes.

The Open Font License allows this: a Modified Version may be distributed as long
as it stays under the OFL and keeps the original copyright notices, which it
does. Mulish has no Reserved Font Name, so the modified files may keep the name
"Mulish" in their internal tables, as they do. Anyone who modifies them further
must do the same: keep the notices above, add their own, and distribute the
result under the OFL.

> **Known side effect.** The serifs of the capital `I` reach the edges of the
> letter, so in "Il" they touch the `l` that follows. It is the price of an `I`
> no child can read as `l`.

### Where copies of it live

**This folder holds the reference copy.** Other repositories carry copies of
these files, and a change is made here first, then copied to them:

| Repository | Copy | How |
|---|---|---|
| Kalulu-Frontend | `assets/fonts/kalulu_mulish_*.otf`, `assets/fonts/OFL.txt` | byte-identical copies |
| Kalulu-Booklets | none — it reads them from its `kalulu-languages/` checkout | — |
| Kalulu-Manuals | `assets/fonts/kalulu_mulish_*.ttf` | converted to TrueType (`tools/otf_to_ttf.py`) |

---

## Marelle

| | |
|---|---|
| Designers | Laurent Bourcellier, Jonathan Fabreguettes, Rosalie Wagner |
| Copyright | Copyright 2026 Ministère de l'Éducation nationale, de l'Enseignement supérieur et de la Recherche, Laurent Bourcellier, Jonathan Fabreguettes and Rosalie Wagner, with Reserved Font Name "Marelle" |
| License | SIL Open Font License 1.1 — [`marelle/OFL.txt`](marelle/OFL.txt) |
| Reserved Font Name | **"Marelle"** |
| Source | <https://marelle.forge.apps.education.fr>, la Forge des communs numériques éducatifs |

A free cursive for teaching handwriting in primary school, supported by the
French Ministry of Education's Direction du numérique pour l'Éducation. **The
files are the 1.005 release, unmodified**, all eight of its variants:

| File | Name | What it is |
|---|---|---|
| `Marelle-Regular.ttf` | Marelle | the school cursive: ascenders and capitals three x-heights tall, descenders two, the proportions of Seyès ruling |
| `Marelle2-Regular.ttf` | Marelle 2 | the same letters with shorter loops: ascenders and capitals two x-heights, descenders one |
| `MarelleBaton-Regular.ttf` | Marelle Baton | Marelle with upright print capitals (*capitales bâton*) instead of cursive ones |
| `MarelleBaton2-Regular.ttf` | Marelle Baton 2 | Marelle 2 with upright print capitals |
| `MarelleLIGNES-Regular.otf` | Marelle LIGNES | Marelle with Seyès ruling drawn into every glyph, so that text comes out on its own lines |
| `MarelleLIGNES2-Regular.otf` | Marelle LIGNES 2 | the same for Marelle 2 |
| `MarelleLIGNESBaton-Regular.otf` | Marelle LIGNES Baton | the same for Marelle Baton |
| `MarelleLIGNESBaton2-Regular.otf` | Marelle LIGNES Baton 2 | the same for Marelle Baton 2 |

The release publishes the four plain variants as TrueType (`.ttf`) only and the
four LIGNES variants as OpenType/CFF (`.otf`) only; they are kept as published.

Marelle joins its letters through OpenType rules (contextual alternates and
chained substitutions). **Text set in it must go through a shaping engine**
(HarfBuzz, or a browser, or a word processor), or the joins come out wrong.

### "Marelle" is a Reserved Font Name

Do not modify these files and keep the name. Under the OFL, a modified version
of Marelle must be renamed: it may not use "Marelle" as its name, in its file
name or its internal tables, without the copyright holders' written permission.
Using the fonts unmodified, embedding them in a PDF or an app, and subsetting
them when a PDF embeds only the letters it uses, are all allowed.

---

## Changing a font here

1. Make the change in this folder, in a pull request like every change to this
   repository.
2. Update this file: the version, the modifications, the copyright notices.
3. Copy the new Mulish files to Kalulu-Frontend's `assets/fonts/` in a pull
   request there, and regenerate Kalulu-Manuals' TrueType copies.
4. Kalulu-Booklets picks the fonts up when its `kalulu-languages` pointer is
   moved to the commit that changed them.

## Adding a font for the booklets

A language's booklets can print with another font than Mulish or Marelle, for
any of the four they use: script regular, bold or black, and cursive
(`BookletFonts` in [`SCHEMA.md`](../SCHEMA.md)). The font lives here, like these
two:

1. Check its license lets it be redistributed: this repository is public. The
   SIL Open Font License does; a font that comes with an operating system or a
   word processor usually does not.
2. Put the file in a folder of its own here (`andika/Andika-Regular.ttf`), with
   its license text beside it, and describe it in this file as the two above
   are, naming the file in backticks: the validator warns about a booklet font
   this file does not name (rule 10).
3. Open a pull request. Once it is merged, the Prof Tool can add the font to a
   language (Booklets, *Language settings*, *Add custom font*) and choose what it
   replaces.

The booklets need a `.ttf` or `.otf` file, and for the cursive, a font that
joins its letters through OpenType rules, as Marelle does.
