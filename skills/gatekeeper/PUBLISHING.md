# Commit & publishing practice

How this project commits, versions, and publishes. `scripts/publish.sh` executes the
mechanics; this page is the practice — read it before your first cut, skim it after.

## Explicit user consent

This practice applies only inside Gatekeeper Release. The user must explicitly
request Release or confirm the model's proposal before it starts. Verification
consent does not authorize mutation. Require explicit user consent covering the
commit, bump, tag, push, publishing, or release CI retry being performed. A PASS,
repo policy, or completed implementation is never that consent. Keep plugin
manifest versions aligned with the tag when applicable.

## Commit practice

**Conventional commits, one concern per commit:**

```
type(scope): summary (work-order-tag)
```

- **Types**: `feat`, `fix`, `chore`, `docs`, `test`, `refactor`.
- **Scope**: the area touched — a module, a subsystem — or the review register being
  landed: `p1`, `p2`, `review-round-3`.
- **Work-order tag**: end the summary with the work order in parens — `(042 review)`.
  Anyone reading the log should trace a commit to its work order.
- **The release commit** is made by `publish.sh`: `chore(release): vX.Y.Z`, containing
  the manifest bumps and the drafted release notes. Never hand-roll it.
- **No push without a receipt.** The gate's PASS receipt precedes the release commit;
  that prerequisite lives in the Release workflow; it is not release consent.

## Versioning

- **Semver**, and lockstep when `CORE_PACKAGE_NAME` is set: both manifests always
  share one version. `publish.sh` refuses to run if they drift, and bumps them
  together (`patch` / `minor` / `major`, or an explicit `X.Y.Z`).
- **Compatibility policy**: decide it and document it (e.g. pre-1.0 = no shims,
  breaking changes land directly with migration notes; post-1.0 = deprecation
  window). The gate enforces claims, not the policy — but the release notes must
  never surprise users about which one is in force.
- **The tag is the baton**: pushing `vX.Y.Z` is what triggers CI. Nothing publishes
  without one.

## The registry (npm or equivalent)

Published by CI (the `publish-npm` job), never from a laptop:

- **Order: core package first, then root** — when `CORE_PACKAGE_NAME` is set. If the
  job dies after core published, re-run the job on the same tag; skip-if-exists
  heals it.
- **Provenance**: the job runs with `id-token: write` so packages get signed
  attestation. This only exists on CI — one reason local publishing is wrong.
- **Secret**: `NPM_TOKEN` (automation/granular token), set once in FIRST_INSTALL.md.

## Homebrew tap (optional)

Only when `HOMEBREW_TAP_REPO` is set. The `publish-homebrew` job (after the registry
succeeds):

1. Downloads the published tarball and computes its SHA256.
2. Clones the tap repo with `HOMEBREW_TAP_TOKEN`.
3. Rewrites the formula's `url` and `sha256` to the new version, commits as
   `github-actions[bot]`, pushes.

No tap? Delete the job and the token.

## GitHub Release

The `github-release` job picks notes by first match:

1. `RELEASE_NOTES-vX.Y.Z.md` — committed by `publish.sh` (drafted by
   `RELEASE_NOTES_CMD` or the bundled `scripts/generate-release-notes.mjs`,
   human-edited if you chose to).
2. The matching section extracted from `CHANGELOG.md`.
3. Auto-generated from commits — the fallback, not the practice.

## When a publish job fails

Re-run the failed CI job **on the existing tag**. Never re-run `publish.sh` — it bumps
a new version the preflight will refuse. If the registry published but a later job
failed, either re-run that job or unwind the half state deliberately; decide which
half-state you're in first.
