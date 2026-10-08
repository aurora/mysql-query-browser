# ADR-0012 — SQL editor: a UniCodeEditor-compatible layer over SynEdit

- Status: Accepted; visual differences to the original still to be reviewed
- Date: 2026-10-08
- Deciders: Harald Lapp (project owner)

## Context

ADR-0007 replaced the third-party editor `UniCodeEditor` (Mike Zinner / Mike
Lischke, ~8.8k lines, plus ~5k lines of highlighters and key commands) with
SynEdit. A closer look at the sources shows the shape of the work:

- The Query Browser's command area is not a plain editor but a
  **console**: `TUniCodeConsole` (`UniCodeConsole.pas`, ~880 lines, derived from
  `TCustomUniCodeEdit`) adds a prompt, command history, multi-line commands,
  output lines, `OnExecuteCommand` / `OnIsMultilineCommand`.
- The shared GUI library uses the plain editor, SQL highlighter
  (`TUCESQLHighlighter`) and HTML highlighter in several forms (field viewer,
  routine/view/table editors, the Query Browser's script panel).
- A scan of the sources finds a small, concrete API surface in use: `Content`
  (the text lines), `Options`, `CaretX`/`CaretY`, `OffsetY`, `GutterWidth`,
  `CharWidth`, `MaxUndo`, `InsertCaret`, `Font`/`Color`, a few events, and the
  console members (`ConsoleCommand`, `ConsoleCommandExcludeDelim`,
  `ConsolePrompt`, `ConsoleDelimiter`, `PrepareNextConsoleCommand`, `AddOutput`,
  `ReadScriptInput`, `OnExecuteCommand`). The scan only follows declared
  variables and under-counts; the compiler will report the rest.
- `UniCodeEditor` is released under the **MIT licence** with the request to
  credit its authors in product documentation or the about box.

The project owner confirmed the direction (SynEdit) on 2026-10-08.

## Decision

- Provide units named `UniCodeEditor`, `UCEHighlighter`, `UCESQLHighlighter`,
  `UniCodeConsole` in `app/compat/` (or `app/src/` where they carry ported
  logic) that expose the API the ported code uses, implemented on **SynEdit**
  (`TSynEdit`, `TSynSQLSyn`). The original console logic (prompt handling,
  history, multi-line commands) is ported on top of that layer.
- The compatibility classes cover **only what the code uses**; members are added
  when the compiler asks for them, not speculatively.
- Highlighter token colours and key bindings are set to the original's defaults
  and reviewed against the original's behaviour; differences are bugs to fix,
  not features.
- Credit to the UniCodeEditor authors and the MIT notice are added to `NOTICE`
  as soon as code derived from `UniCodeConsole.pas` is committed.

## Consequences

Positive:

- The ~35k lines of ported UI code keep talking to `TUniCodeEdit`/`TUniCodeConsole`
  and need few edits.
- SynEdit is maintained, ships with Lazarus and works on all target
  platforms; no Windows-only Uniscribe/IME code is carried.
- Only ~900 lines of console logic need an actual port.

Negative / costs:

- Subtle editing behaviour differs from the original: selection and caret
  rules, word wrap, undo grouping, scrolling and rendering of the gutter,
  tab/indent handling. "Looks and behaves like the original" is a review task
  against the real thing, for which no reference installation is at hand
  (ADR-0008).
- SQL highlighting must reproduce the original's token classes and colours;
  SynEdit's `TSynSQLSyn` has its own keyword sets and needs adjustment (e.g.
  MySQL keywords/functions from `mysqlqb_functions.xml`).
- A compatibility layer is another piece of code to maintain and may hide
  SynEdit features that would be natural to use directly.

## Alternatives considered

- **Port UniCodeEditor itself.** Exact original behaviour, but ~14k lines that
  rely on Windows text and input APIs (Uniscribe, IME), tying the UI to
  Windows. Rejected for the cross-platform goal; kept as a fallback if SynEdit
  cannot be made to behave acceptably.
- **Use SynEdit directly in the ported code.** Fewer layers, but every use
  site (hundreds of references across forms) would be rewritten and diverge
  from the original source. Rejected for now; individual units can migrate
  later.
- **A different editor component (e.g. Scintilla via a Lazarus wrapper).**
  Not evaluated; SynEdit ships with Lazarus and was already chosen in
  ADR-0007.

## Related

- ADR-0007 (the replacement decision this refines), ADR-0008 (no reference
  screenshots to compare against), ADR-0011 (MIT-licensed code credited in
  `NOTICE`).
