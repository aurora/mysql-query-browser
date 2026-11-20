<!-- SPDX-License-Identifier: GPL-2.0-or-later -->
# ADR-0049 — JSON and JSON Lines export of result sets

- Status: Proposed (implemented on branch `export-json`; Windows build not checked)
- Date: 2026-11-20
- Deciders: Harald Lapp (project owner)

## Context

The original exports a result set from **File > Export Resultset** and the grid's context menu in five formats:
CSV, HTML, XML, Excel (SpreadsheetML 2003) and PLIST. The formats come from the backend's exporter list
(`myx_exporter.c`). The menu entries are built from that list (`TQueryBrowserForm.AddResultsetExporterMenuItems`,
caption "Export As %s File..."), and so is the save dialog's file filter. None of these formats suits the tools
people now feed result sets into: scripts, `jq`, document stores, log pipelines and notebooks read JSON, and large
data sets travel as JSON Lines (one object per line, so a reader can stream it).

The owner suspected that the exporters were slow or partly broken. A review with measurements
(`docs/export-review.md`) found the exporters fast and linear, but found real bugs: Excel crashed on an empty
string, HTML and PLIST wrote `(null)` for one, the XML and PLIST files were not well-formed for many column names
and for NULL values, and the GUI export raced the thread that still fetches rows. These are fixed as bugs (ADR-0047:
the original was wrong); this ADR records the one visible addition and the output changes that come with the fixes.

ADR-0047 allows new features that are additive, in the original's style, written down before they are built, and
tested on the server matrix.

## Decision

1. **Two more exporters in the backend list**, after the original five, so they appear in both menus in the
   original's wording and the save dialog works unchanged:

   ```
   File > Export Resultset >  Export As CSV File...
                              Export As HTML File...
                              Export As XML File...
                              Export As Excel File...
                              Export As PLIST File...
                              Export As JSON File...          (new)
                              Export As JSON Lines File...    (new)
   ```

   `--menu-smoke list` shows both menus with these entries. No dialog, option or text is added; the captions use
   the existing translated string "Export As %s File...", the filter names ("JSON File (*.json)", "JSON Lines File
   (*.jsonl)") are, like the original's, not translated. Nothing is stored, so no file format changes.

2. **JSON** (`.json`): an array of objects, one row per line:

   ```
   [
   {"id":1,"name":"a,b\"c\nd","price":1.50,"created":"2026-01-02 03:04:05","note":null},
   {"id":2,"name":"","price":null,"created":null,"note":"<&>"}
   ]
   ```

   **JSON Lines** (`.jsonl`): the same objects, one per line, each line ending with `\n`, nothing else (an empty
   result is an empty file, for JSON `[` `]`).

   - Keys are the column names as the result set has them (duplicate names stay duplicate, as in the grid).
   - SQL NULL is `null`; the empty string is `""`.
   - Values of integer, decimal and floating-point columns are JSON numbers, written as the server sent them
     (`1.50` keeps its scale; BIGINT keeps all digits, even beyond what a double holds). A value that is not a valid
     JSON number (a ZEROFILL integer such as `007`) is written as a string.
   - Everything else is a string: dates and times as the server formats them, ENUM/SET, BIT as `b'101'` (as the
     grid shows it), JSON columns as their text.
   - Strings are UTF-8; `"`, `\` and control characters are escaped (`\n`, `\t`, `\u0001`), all other characters
     are written as they are. Bytes that are not UTF-8 (binary columns) become U+FFFD. A binary value ends at its
     first zero byte, as in every other exporter (the exporter interface passes C strings).
   - The file is written in binary mode: the same bytes on every platform, no CR LF on Windows.
   - Master-detail export stays HTML/XML only, as in the original.

3. **Output changes that come with the bug fixes** (all formats; each was wrong in the original):
   - DECIMAL columns (reported as NEWDECIMAL since MySQL 5.0) count as numbers: CSV writes them unquoted (as the
     original did for the old DECIMAL type), Excel as `Number`, PLIST as `<real>` (was `<integer>` for DECIMAL).
   - XML writes NULL as `<field name="x" xsi:nil="true" />` (as `mysqldump --xml` does) with the namespace on
     `<ROOT>` and the attribute in the DTD; it was `<x/>`, which is not well-formed for most column names and not in
     the DTD. Column names in XML, HTML, Excel and PLIST, and the HTML title, are escaped.
   - The markup formats replace bytes that are not UTF-8 by U+FFFD, and XML, Excel and PLIST also the control
     characters XML 1.0 forbids. CSV keeps writing the bytes unchanged.

## Consequences

Positive:
- Result sets go straight into current tools; JSON Lines streams for large exports (2 million rows in about
  0.7 s on the development machine, `docs/export-review.md`).
- The new formats live where the others do: one code path, one menu, one test unit (`tests/test_export.pas`) that
  checks every format with the same tricky values on the server matrix.
- The fixes make every format load in its target program (XML validates against its DTD, PLIST loads in Python's
  `plistlib`, Excel no longer crashes the program).

Negative:
- Two more menu entries than the original in both export menus, also for users who never use them (the "off by
  default" rule of ADR-0047 cannot hide a menu entry without an option; the entries change nothing else).
- XML, PLIST and HTML files differ from the original's where it was wrong (see 3.); a script that parsed the old
  `<column/>` NULL elements has to follow.
- Numbers that exceed a double's precision are valid JSON but some readers (JavaScript) round them; a string would
  have been safe but would make every number a string.

## Alternatives considered

- **Numbers as strings.** Simpler and lossless in every reader, but then every consumer converts types itself; the
  column type is known, so numbers are numbers.
- **Pretty-printed JSON (indented, one key per line).** Readable for small results, but triples the size of large
  ones; one object per line is still readable and diff-friendly.
- **Binary values as Base64.** Lossless, but needs the value lengths, which the exporter interface does not pass;
  the interface stays as the original's (it is in the generated Pascal bindings). Can follow if asked for.
- **De-duplicating column names (`a`, `a_2`).** Invents names the user did not write; the grid shows duplicates too.

### Further formats (not implemented; each needs its own decision)

- **SQL INSERT statements** — worth it: the most asked-for "export" of a query tool (copy rows to another server or a
  test fixture). Needs the table name (known for editable single-table results, `resultset->columns[].table`), and
  quoting per type (the escaping of the grid's edit statements, `myx_recordset.c`, can be reused). Medium effort.
- **CSV with the separator chosen** (semicolon for Excel in German locales, tab for TSV) — worth it and cheap in the
  backend: the CSV exporter has had a "Separator" option since the original, but the program never shows it. Needs a
  small UI decision (an option page entry, or "TSV" / "CSV (semicolon)" as extra formats).
- **Markdown table** — cheap (a CSV-like writer, `|` escaped), useful for pasting results into issues and wikis; low
  priority.
- **XLSX** — the Excel export writes SpreadsheetML 2003 into a `.xls` file, and current Excel warns that the content
  does not match the extension. A real `.xlsx` is a ZIP of XML parts; it needs a ZIP writer (zlib is already linked
  through the client library). Medium effort; worth it if users complain about the warning.
- **Parquet** — not worth it here: needs Apache Arrow/Parquet (large C++ libraries with their own dependencies, to
  build and ship on both platforms; Apache-2.0 is fine as for OpenSSL, `docs/licenses.md`), for a use case
  (analytics pipelines) that JSON Lines and CSV already serve as input to converters (DuckDB, pandas, Spark read
  both).

## Related

- ADR-0047 (rules for features after parity), ADR-0001 (the original as the blueprint)
- `docs/export-review.md` (review findings and measurements), `tests/test_export.pas`
- `backend/src/base-library/source/myx_exporter.c`, `myx_export_resultset` in `myx_recordset.c`
