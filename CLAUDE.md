@AGENTS.md

# Claude Code notes

Everything about the project is in `AGENTS.md` (imported above). Additions
that are specific to working with Claude Code here:

- **Writing files with quotes or many heredocs:** large `bash` commands that mix
  heredocs, Python and many quote characters have been rejected by the shell
  hook before running anything. Use the `Write`/`Edit` tools for source files,
  and keep inline scripts short.
- **Searching:** if the `grep` command is rewritten by a token-saving proxy and
  returns nothing or a different format, use the `Grep` tool or
  `rtk proxy grep ...`.
- **Long jobs** (server matrix, full form conversion): run them and report the
  summary table; do not paste container pull logs.
- **Before a commit:** make sure generated files were regenerated (not edited),
  and that `git status` shows no `app/bin`, `app/lib`, `app/res`, `backend/build`
  or `tests/bin` (they are git-ignored; if they appear, the ignore list broke).
- Commit messages: imperative summary line, body explains *why*, as in the
  existing history.
