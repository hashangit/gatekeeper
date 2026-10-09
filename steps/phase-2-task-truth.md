# Phase 2 — task truth

One fresh reviewer session reads the work order's tasks.md and grades **every `[x]`**
against the seal.

- **TRUE** — the claim holds at HEAD, with `file:line` or `git show` evidence.
- **PARTIAL** — real work landed but part of the task is missing. Say what's missing.
- **FALSE** — the claim is not true at HEAD.

Distinguish what is claimed from what is at HEAD. Banner numbers are checked too:
counts, gate numbers, CI run IDs.

**Any FALSE row blocks the release.** A release may not claim what is not true.
PARTIAL rows block only if the missing half is the point of the task (adjudicated in
Phase 5's verdict rules).
