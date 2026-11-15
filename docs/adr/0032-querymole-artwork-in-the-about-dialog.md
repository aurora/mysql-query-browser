# ADR-0032 — QueryMole artwork in the About dialog

- Status: Accepted (implemented; second version of the artwork, with a separate wordmark, the same day)
- Date: 2026-11-15
- Deciders: Harald Lapp (project owner)

## Context

ADR-0030 removed the MySQL logo from the About picture and set the word "QueryMole" on the original's gradient as
a placeholder; the final logo was deferred. The owner has now supplied a QueryMole artwork (first
version: `assets/querymole-about.png`, 1423x547, generated with an OpenAI image model; `docs/licenses.md`): a mole with a
magnifier and SQL snippets on a dark navy background, on the right the "QueryMole" wordmark, the line "Explore.
Query. Understand." and a thin rule below it, and empty background under that.

It does not fit the original dialog: the original picture is 444x341, light, and the dialog writes version,
copyright, licence note and credits in grey onto its lower part. The new artwork is 2.6:1 and dark. Scaled to 444
pixels it would be 171 pixels high and the wordmark hard to read; grey text on navy is barely legible.

## Decision

- **Picture** (second version of the artwork, the same day). The owner replaced the first artwork, which had the
  wordmark painted in, by two images: the mole on the left of an empty navy background (`assets/querymole-about.png`,
  1210x620) and the wordmark with slogan and rule on a transparent background (`assets/querymole-text-1.png`).
  `tools/make_branding.sh` scales the artwork to the dialog's picture height (**666x341**, no band needed at about
  2:1) and sets the wordmark top right (250 pixels wide at x 400, y 14). Kept apart, the wordmark stays sharp and can
  be placed exactly over the text column. The masters stay in `assets/`; the generated file is committed like the
  other branding images (ADR-0030).
- **Dialog.** `CommonFuncs.CreateAboutForm` takes the dialog's width from the picture (666 instead of 444; buttons
  and bevel follow) and puts the texts in a column right of the mole, **below the rule under the slogan**, aligned
  with it (`AboutColLeft`/`AboutColTop`/`AboutColWidth`: x = 405, from y = 108, 242 pixels wide, down to the button
  line). The texts are light (`rgb(206,218,232)` for the version, `rgb(160,178,200)` for the rest) instead of
  `clGray`. `About.lfm` stays as converted; the changes are made at run time like those of ADR-0026 and ADR-0031.
- **Lines set by hand.** A 242-pixel column wraps long sentences at random places, so the lines are broken in the
  text where possible:

  ```
  version 0.1.0 alpha.2                        (bold)
  based on MySQL Query Browser 1.2.4 beta      (own label, plain)

  © Copyright 2005, 2006 by MySQL AB.          (the original's line, broken after its first sentence)
  All rights reserved.
  QueryMole © 2026 Harald Lapp and contributors.   (ADR-0031)

  Free software under the GNU GPL, version 2
  or later; you may redistribute it under its
  terms. It comes with NO WARRANTY.
  github.com/aurora/querymole
  Not affiliated with Oracle.
  ```

  The licence note replaces the longer one of ADR-0026 and keeps what GPLv2 §2(c) asks an interactive program to
  show: the copyright notice (above it), no warranty, that users may redistribute under the licence, where to find
  more (the project page). In the credits view the credits take the place of copyright and licence as before; the
  two version lines stay.
- **Credits in two sections** (changes the credits text of ADR-0026). One list that ended with "Revival (Free
  Pascal / Lazarus): Harald Lapp, ..." read as if the original's authors ("Mike Lischke, Windows development")
  worked on this program. The credits view now shows:

  ```
  Original: MySQL Query Browser (MySQL AB)        (bold)
  Michael G. Zinner, graphical design, ... | Mike Hillyer, documentation   (the original's list, unchanged)

  QueryMole                                       (bold)
  Harald Lapp, port to Free Pascal / Lazarus, maintenance, with the help of Claude Code (Anthropic), an AI
  coding assistant
  ```

  The original's authors stay named (most of the code and the design are theirs), framed so that nobody reads them
  as contributors to or supporters of QueryMole. New contributors are added to the QueryMole section. The headings
  and the QueryMole text are labels added by `CreateAboutForm`, measured so each section follows the previous one;
  a small component switches them together with the original's credits label (`About.pas` stays as ported).
- **Unchanged:** the Credits/About toggle, the height of the dialog and the button line, the wording of the
  original's copyright line, the original's list of authors.
- **Not part of this decision:** the connect dialog header (`connect_header_qb.png`, still the ADR-0030
  placeholder), the main window's picture top right, the application icon and a busy animation. Each can use the
  artwork later; this ADR settles only the About dialog.

## Consequences

Positive:

- The About dialog shows the product's own artwork instead of a placeholder on another vendor's gradient, and the
  texts read as part of it (under the wordmark) instead of a separate block.

Negative / costs:

- A further visible deviation from the original (size, layout, colours of the dialog), on top of ADR-0030's.
- The dialog is 222 pixels wider than the original; the splash code (`ShowSplashScreen`, unused) would show the
  picture with the version only, in the old place.
- The column's position and the text colours are numbers in code that belong to the picture: a new artwork with
  the wordmark elsewhere needs them changed (the script's comment says so).
- The column is narrow: the hand-set lines only fit as long as each line fits 242 pixels; a translation or a wider
  font wraps them again (still readable, but no longer tidy). The credits view is the fullest (two headings and
  about 10 lines); there is room left above the button line, but not much. Checked under Linux (GTK2, Wine's Tahoma at -10); the Windows layout with Microsoft's Tahoma at
  -11 is not verified yet.

## Alternatives considered

- **Keep the 444-pixel dialog, artwork on top.** Rejected: at 171 pixels height the wordmark and the mole are too
  small to read.
- **The first artwork with the wordmark painted in (720x341, a band below it).** Replaced by the owner: the wordmark
  could not be moved or kept sharp, and the picture needed a band to reach the dialog's height.
- **560-pixel dialog, texts in the dark band below the artwork** (implemented first). Works, but the texts stand
  apart from the artwork and the empty area under the wordmark stays empty; the owner preferred the column.
- **Column with the texts as wrapped paragraphs** (first version of the column). Rejected: the version line broke
  inside "MySQL Query Browser" and the licence note was a six-line block.
- **Licence note in the dark band at the bottom, over the full width.** Airier, but splits the texts into two places.
- **Artwork at the full height of the dialog (887x341).** More room for the column, but a very wide dialog.
- **Crop the artwork to the dialog's proportions.** Rejected: either the mole or the wordmark is cut.

## Related

- ADR-0030 — the rename; the About placeholder and the deferred logo.
- ADR-0031 — the maintainer's copyright line in the About dialog.
- ADR-0026 — the revival's credits and licence note in the About dialog; amended here (two credits sections,
  shorter licence note).
- ADR-0001 — no UX changes without an ADR.
