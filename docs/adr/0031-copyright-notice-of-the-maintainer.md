# ADR-0031 — Copyright notice of the project maintainer in NOTICE and the About dialog

- Status: Accepted
- Date: 2026-11-14
- Deciders: Harald Lapp (project owner)

## Context

ADR-0026 gave the About dialog the revival's credits but said "No copyright line is invented for the revival",
and AGENTS.md says "Copyright notices are never invented". Both were written to keep the project from putting a
holder's name where it has no basis: a "Copyright ... MySQL AB" line in new files, or a notice copied onto code
someone else wrote.

Since the rename (ADR-0030) the program is QueryMole, and its only copyright notice reads "© Copyright 2005, 2006
by MySQL AB. All rights reserved." That reads as if the fork had no author of its own. The project owner is the
author of the revival's work and wants that to be visible.

Facts the decision rests on:

- Copyright arises without a notice; a notice only names who claims it.
- The GPL requires existing notices to be kept (§1) and modified files to say that they were changed (§2a); it does
  not forbid additional notices, and forks commonly add one.
- A large part of the revival's code was written by an AI assistant (Claude Code) under the owner's direction
  (README, About credits). Whether, and how far, such code is protected is not settled (in Germany and the USA
  protection needs human authorship). The owner's own contribution (direction, selection, decisions, edits,
  documentation) is his. The notice claims his rights; it does not settle how far they reach.

## Decision

- `NOTICE` names the project's copyright: "QueryMole, Copyright (C) 2026 Harald Lapp and contributors", next to the
  original's notice, which stays as it is.
- The About dialog shows the original's copyright line unchanged and a second line below it:
  "QueryMole © 2026 Harald Lapp and contributors." (`CommonFuncs.CreateAboutForm`; the label becomes two lines,
  between the version line and the licence note).
- File headers are not changed: ported files keep the header from `legacy/`, new files keep only the SPDX line. One
  project-wide notice in `NOTICE` is easier to keep right than one per file once there are other contributors.
- AGENTS.md is made precise: inventing a holder (or copying a notice onto code the holder did not write) stays
  forbidden; the maintainer's notice in `NOTICE` and the About dialog is the one exception.
- This amends ADR-0026 in the one sentence about the copyright line; the rest of ADR-0026 stands.

## Consequences

Positive:

- The fork has a visible author and a named holder for its own work; the original's notice is untouched.
- The rule against invented notices stays, with its exception written down.

Negative / costs:

- Another visible change of the About dialog against the original (ADR-0001), like ADR-0026's credits.
- The extent of the claim is uncertain for AI-written code; the notice may suggest more protection than exists.
- "and contributors" leaves open who they are; contributions are attributed through the git history, not
  per-file notices. A contribution policy (ROADMAP, open questions) is still to be written.
- The year has to be kept up to date by hand (`2026`, later a range).

## Alternatives considered

- **No notice for the fork (ADR-0026 as it was).** Rejected: the program would name only a company that no longer
  exists as its copyright holder.
- **A notice in every new file.** Rejected: many files, easy to get wrong, and it adds nothing a project-wide
  notice does not say.
- **Replace the original's line by a combined one** ("© 2005-2006 MySQL AB, 2026 Harald Lapp"). Rejected: the
  original's notice is kept byte for byte (AGENTS.md, GPL §1).
- **The owner's name only, without "and contributors".** Rejected: the project accepts contributions; the notice
  should not have to change when the first one arrives.

## Related

- ADR-0026 — About dialog credits; amended here in the copyright sentence.
- ADR-0030 — the rename to QueryMole.
- ADR-0011 — licence GPL-2.0-or-later.
- AGENTS.md, "Conventions" — the rule on copyright notices.
