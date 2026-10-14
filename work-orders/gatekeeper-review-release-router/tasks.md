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
- [x] Reject shell execution through Git tags and reject symlinks in generated skill sources.
  Verify: `python3 scripts/check-release-safety.py` passes hostile-tag and outside-symlink probes.
- [x] Require the sealed Release PASS receipt and both configured gates before publisher mutations.
  Verify: `skills/gatekeeper/scripts/publish.sh` checks the current HEAD receipt, runs `GATE_TEST_CMD` and `GATE_BUILD_CMD`, and stages the receipt with the release commit.
- [x] Make release validation read-only, require the matching receipt and notes, and isolate write permission to GitHub Release creation.
  Verify: `.github/workflows/release.yml` has a read-only validation job, receipt-parent check, pinned actions, and a separate write-only release job.
- [x] Configure Gatekeeper for this repository and document fresh-session validator setup.
  Verify: `python3 scripts/check-skills.py` reports identical router, workflow, and `config.sh` values; `RELEASE_PROCESS.md` documents the pinned `skills-ref` install.
