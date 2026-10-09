# Phase 5 — the verdict and the receipt

## The referee

The verdict is computed, not negotiated:

- Confirmed P0 or P1 → **FAIL**
- Any FALSE task-truth row → **FAIL**
- Unresolvable material conflict → **BLOCKED** (call the owner)
- Otherwise → **PASS**

PARTIAL task rows are adjudicated here: they block only if the missing half is the
point of the task.

## The receipt

Write the report to `REVIEW_FOLDER_PATH/YYYY-MM-DD-<work-order>-gatekeeper.md` with
a receipt header:

```
Branch: … | Seal: <sha> | Gates: suite N/N, probes N/N, examples N/N, build ✓, CI run <id>
Fleet: <reviewers that ran> | Skipped: <switched-off or unavailable, and why>
Task truth: X TRUE / Y PARTIAL / Z FALSE
Findings: P0:n P1:n P2:n (confirmed/refuted)
Verdict: PASS | FAIL | BLOCKED
```

The receipt precedes the release commit; the repo's review index (if it keeps one)
gets the entry in the same change. **No receipt, no push.**
