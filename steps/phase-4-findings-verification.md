# Phase 4 — findings verification

The gate-keeper (the orchestrating agent, itself not the implementer) merges and
deduplicates the fleet's findings, then **re-runs every load-bearing P1/P2
reproduction first-hand.**

- A second opinion cannot clear a demonstrated defect; a generic pass can never
  refute a specific one.
- Refuted allegations stay visible in the report but do not block.
- If a material conflict cannot be resolved, the verdict is **BLOCKED** — yellow stops
  the line; no guessing.
- Now the **Architect** joins (`../reviewers/architect.md`): it sees the verified
  findings and judges the premise and the shape of the system the change sits in.
