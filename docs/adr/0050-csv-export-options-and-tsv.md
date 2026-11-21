<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0050 — CSV export options and a TSV export format

- Status: Proposed (implemented on branch `export-csv-options`; Windows build not checked)
- Date: 2026-11-20
- Deciders: Harald Lapp (project owner)

## Context

The CSV export always writes `,` between values, quotes text and date columns but never numbers, starts with a row
of column names, writes no byte order mark and ends lines as the platform does (the file is opened in text mode:
LF on Linux, CR LF on Windows). Users with a German (or other `,`-decimal) Excel need `;`: Excel splits a
comma-separated file into columns only when the separator matches the list separator of the locale. Without a
byte order mark Excel also reads a UTF-8 file as the ANSI code page and shows umlauts wrongly. Other tools want no
header, quotes only where needed, or fixed LF.

The backend has had exporter options since the original (`MYX_TE_OPTION`; CSV has "Separator", default `,`), set
with `myx_set_table_exporter_option`, but the original never showed them anywhere. ADR-0049 recommended giving the
separator a UI. Tab-separated files are the other common exchange format (spreadsheets, `LOAD DATA INFILE`, Unix
tools).

ADR-0047: features are additive and off by default, in the original's style, written down before they are built;
stored settings stay readable by the previous release.

## Decision

1. **Settings in the Options dialog, not a prompt per export.** A new group **"CSV / TSV Export"** at the bottom of
   the **Browser** page (Tools > Options), below "Various", where the page has free room. It is built in code like
   the SSH row of ADR-0048 (the `.lfm` files are generated from the original's DFMs) and follows the page's style:
   group box, labels with right-aligned text, combo boxes, check boxes.

   ```
   CSV / TSV Export
     Separator: [Comma      v]  Quotes: [Text columns   v]  Line breaks: [System      v]
     [x] Column names in the first line      [ ] UTF-8 byte order mark (for Excel)
   ```

   ![The Browser page with the new group (Qt6, `--dialog optionpages`)](../mockups/csv-export/options-browser.png)

   | Control | Choices | Default (= output before) |
   |---|---|---|
   | Separator (CSV) | Comma, Semicolon, Tab, or any text typed in | Comma |
   | Quotes (CSV) | Text columns (text and date values in quotes, numbers not), Only when needed (a value that contains the separator, a quote, CR or LF, and the empty string), All values | Text columns |
   | Line breaks (CSV, TSV) | System (LF on Linux and macOS, CR LF on Windows), LF, CR LF | System |
   | Column names in the first line (CSV, TSV) | on/off | on |
   | UTF-8 byte order mark (CSV, TSV) | on/off | off |

   NULL stays an empty, unquoted CSV field in every quoting mode; "Only when needed" quotes the empty string (`""`)
   so that it still differs from NULL. A "Separator" text of more than one character is written as it is; an empty
   one means comma.

2. **The backend's exporter options carry the settings.** The CSV exporter gains the options "Header", "Quoting",
   "Line Breaks" and "BOM" next to the original's "Separator"; the TSV exporter has "Header", "Line Breaks" and
   "BOM". `SaveResultsetAs` sets them from the program's options before each export (an exporter ignores options it
   does not have). With "LF" or "CR LF" the file is opened in binary mode, so the line ending is exactly the one
   chosen on every platform; with "System" it is opened in text mode, as before.

3. **Stored in the options file** (`mysqlqb_options.xml` in the user data folder) in a new group "Export":
   `CSVSeparator` (`,` `;` `tab` or the text), `CSVQuoting` (`text`, `needed`, `all`), `ExportLineBreaks` (`system`,
   `lf`, `crlf`), `ExportHeader` (`1`/`0`), `ExportBOM` (`1`/`0`). Older releases ignore the group; a file without
   it gives the defaults.

4. **TSV as an export format** ("Export As TSV File...", `.tsv`, "Tab Separated Values File") after the original
   five and JSON/JSON Lines (ADR-0049), in both export menus. The format is the one `LOAD DATA INFILE` and
   `SELECT ... INTO OUTFILE` use by default, so a file goes back into a server unchanged:
   - values separated by one tab, rows by the chosen line break; no quoting;
   - in values (and column names) `\` is written as `\\`, tab as `\t`, LF as `\n`, CR as `\r`;
   - NULL is `\N`; the empty string is an empty field;
   - text as UTF-8, bytes unchanged (like CSV).

   Spreadsheets open it as columns in every locale; they show `\N` and the escapes literally.

## Consequences

Positive:
- German Excel users get columns and correct umlauts with two settings that stay set.
- Users who change nothing get byte for byte the old CSV output (checked by the tests).
- TSV round-trips through `LOAD DATA LOCAL INFILE ... ` with its defaults, NULLs included.

Negative:
- One more group on the Browser page and one more export menu entry than the original.
- The settings apply to every CSV export; a user who needs different separators for different targets changes the
  option in between (a per-export prompt was rejected, see below).
- New texts are English until translated.

## Alternatives considered

- **A dialog on every export** (separator, quoting, ...): one more click for everyone on every export, and a dialog
  the original never had in that place. Rejected in favour of settings.
- **A "CSV (semicolon)" menu entry** instead of a separator option: covers the German case only, not BOM, header or
  quoting.
- **TSV with CSV-style quotes** (as Excel writes it): common, but no standard either, and it loses the round trip
  through `LOAD DATA`; the backslash escapes are what MySQL itself uses. **TSV without any escaping** (IANA
  `text/tab-separated-values` forbids tabs and line breaks in fields): would write broken rows for such values.
- **An own "Export" options page**: more weight than five controls need; the Browser page already holds the
  export-related "Open resultset in associated application after export".

## Related

- ADR-0049 (JSON export; recommended the separator UI), ADR-0047 (rules for features), ADR-0048 (controls built in
  code on a generated form)
- `backend/src/base-library/source/myx_exporter.c`, `app/src/QueryBrowserOptionPages.pas`,
  `app/src/ApplicationDataModule.pas`, `tests/test_export.pas`
