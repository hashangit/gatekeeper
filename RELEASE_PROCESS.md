# Release Gatekeeper

This repository ships a Claude Code plugin and Agent Skills folders. It has no npm
package. The release pipeline validates all skills and creates a GitHub Release from
a `vX.Y.Z` tag. It does not publish to a package registry.

## Maintainer gate configuration

Use these values when running Gatekeeper Release on this repository. The packaged
`skills/gatekeeper/config.sh` remains a generic install template; install the release
skill into an isolated working copy and mirror these values into that copy's
Configuration section before starting Phase 0.

```text
REVIEW_FOLDER_PATH=Reviews
IMPLEMENTATION_SPEC_PATH=specs
WORK_ORDER_PATH=work-orders/<work-order>/tasks.md
PACKAGE_NAME=gatekeeper
CORE_PACKAGE_NAME=
GATE_TEST_CMD=python3 scripts/check-skills.py && skills-ref validate skills/gatekeeper && skills-ref validate skills/gatekeeper-review && skills-ref validate skills/gatekeeper-release
GATE_BUILD_CMD=python3 scripts/sync-skills.py --check
GATE_PROBES_CMD=
GATE_EXAMPLES_CMD=
RELEASE_CI_WORKFLOW=release.yml
RELEASE_NOTES_CMD=
HOMEBREW_TAP_REPO=
```

The test gate checks isolated-install links, config mirrors, and all three skill
manifests. `GATE_BUILD_CMD` verifies that standalone bundles match the canonical
workflow sources. The release workflow repeats these checks from the tagged tree.
All seven reviewer switches are Enabled.

## Release steps

1. Use Gatekeeper Release on the committed candidate. Require the receipt to say
   PASS before making the version bump or cutting a tag.
2. Pick the semver bump based on scope and update both
   `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` descriptions
   only as needed. The plugin version must match the tag.
3. Generate `RELEASE_NOTES-vX.Y.Z.md` with
   `node skills/gatekeeper/scripts/generate-release-notes.mjs X.Y.Z`. Edit the notes
   before the release commit. Include the Gatekeeper receipt with the release change.
4. Commit the release change, create the matching annotated tag, and push the branch
   and tag to `origin`. User consent must cover those actions and this repository.
5. The tag triggers `.github/workflows/release.yml`, which validates the tagged tree
   and creates the GitHub Release using the committed release notes. The workflow
   needs only GitHub's built-in `GITHUB_TOKEN`; it does not use npm or tap secrets.

Never treat the gate PASS as consent to bump, commit, tag, push, or publish. If the
workflow fails, inspect and rerun the existing tag workflow; do not create another
version to retry it.
