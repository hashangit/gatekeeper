# Phase 0 — deterministic checks

Before checks, require a clean candidate tree. Record `git rev-parse HEAD` as the
candidate SHA and inspect `git status --porcelain`, including untracked files. If
implementation changes are uncommitted, report BLOCKED; never commit or stash them
on the user's behalf. Run checks in a clean checkout of that candidate. Ignored
build outputs may be produced, but tracked changes or new non-ignored files require
investigation and a new clean candidate before proceeding.

Run the gates and record their output verbatim. Agents never self-report these.

The gate commands come from `config.sh`:

```bash
source <skill-dir>/config.sh
bash -c "$GATE_TEST_CMD"      # required — the full suite
bash -c "$GATE_BUILD_CMD"     # required — the build
bash -c "$GATE_PROBES_CMD"    # if set — probes / deep checks
bash -c "$GATE_EXAMPLES_CMD"  # if set — examples / docs build or tests
```

Rules:

- Any red here is **FAIL** before a single reviewer wakes.
- The numbers (tests passed, files, probes N/N) go straight into the receipt header in
  Phase 5 — capture them now, don't reconstruct them later.
- If a gate is flaky, re-run once and record both runs. Adjudicate a timing flake only
  with evidence (green isolated + green full re-run); never by wishing.
