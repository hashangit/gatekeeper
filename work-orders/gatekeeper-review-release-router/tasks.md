# Gatekeeper Review and Release router

- [x] Add a Review-default router and standalone Review and Release skills.
  Verify: `python3 scripts/check-skills.py` checks all three isolated bundles.
- [x] Preserve the complete six-phase flow, reviewer fleet, verdict, receipts, and repair limit.
  Verify: all seven unchanged mandate files exist under `skills/gatekeeper/reviewers/`; `skills-ref validate` passes for all three skills.
- [x] Require explicit consent before Release and its mutations.
  Verify: Review, Release, and router entrypoints state the consent boundary; `scripts/check-skills.py` passes.
- [x] Add release setup and tag workflow for the plugin repository.
  Verify: the release workflow checks bundle drift, skill metadata, syntax, and tag/plugin version equality.
- [x] Document setup, installation, and repo-specific release configuration.
  Verify: `RELEASE_PROCESS.md` lists every config value and `README.md` links to the release procedure.
