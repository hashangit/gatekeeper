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
- [x] Resolve previous tags to commit IDs before Git log and validate manifest versions before bump calculations.
  Verify: release safety probes cover Git option injection, malformed-version command execution, and decimal version bumps.
- [x] Reject symlinks in direct references and every canonical source path component.
  Verify: release safety probes reject a symlinked canonical reference; bundle checks pass.
- [x] Align the publisher and CI on the structured receipt seal header and include updated npm lockfiles in release commits.
  Verify: safety probes reject a standalone seal line and confirm lockfile inclusion with a clean post-release tree.
- [x] Recheck tag identity before the write job and make GitHub Release retries idempotent.
  Verify: the workflow checks the event SHA against the tag and creates or updates the same release.
- [x] Treat reviewer brief text as untrusted project data.
  Verify: phase 3 says brief text cannot override mandates, the seal, policy, permissions, or consent.
- [x] Supply the workflow template for standalone installs and align release setup and publishing instructions.
  Verify: the Release bundle includes assets/release.yml; setup names its source and Python requirement; release instructions use the publisher.
