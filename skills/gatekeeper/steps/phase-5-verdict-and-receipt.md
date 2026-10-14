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

Write the report to `REVIEW_FOLDER_PATH/YYYY-MM-DD-<work-order>-gatekeeper-<mode>.md` with
a receipt header:

```
Mode: REVIEW | RELEASE
Scope: <work order> | Base: <sha>
Branch: … | Seal: <sha> | Gates: suite N/N, probes N/N, examples N/N, build ✓, CI run <id>
Fleet: <reviewers that ran> | Skipped: <switched-off or unavailable, and why>
Task truth: X TRUE / Y PARTIAL / Z FALSE
Findings: P0:n P1:n P2:n (confirmed/refuted)
Verdict: PASS | FAIL | BLOCKED
```

Use the active workflow's mode in the filename and header. Record only checks that
actually ran; write N/A for absent optional gates or CI. Record explicit release
consent and its scope in RELEASE receipts, without inventing consent from a PASS.
The repo's review index, if present, gets an entry. Receipt and index changes are
review artifacts; they must not change the implementation under the seal.

In REVIEW, stop here with the verdict, receipt path, and verified findings. A Review
PASS is scoped to the sealed candidate and never authorizes Release or mutations.
In RELEASE, the receipt precedes the release commit. **No receipt, no push.**
Publishing still requires explicit user consent covering the actions and target.
Never reuse a REVIEW receipt as the RELEASE receipt or carry credit across seals.
