# Phase 1 — the seal

Freeze the SHA.

```bash
SEAL=$(git rev-parse HEAD)       # record this; every claim is graded against it
```

From here on, every claim is graded against the **committed tree**
(`git show <sha>:<path>`), never the working tree — twice now a real fix sat
uncommitted while its checkbox said done.

If anything lands on the branch mid-gate, the review is **discarded** and restarts on
the new seal. No partial credit across seals.
