# Release Gatekeeper

This repository ships a Claude Code plugin and Agent Skills folders. The release
pipeline validates all skills and creates a GitHub Release from a `vX.Y.Z` tag. It
does not publish to a package registry.

## Maintainer gate configuration

Use these values when running Gatekeeper Release on this repository. They are also
set in `skills/gatekeeper/config.sh` and mirrored in all workflow Configuration
sections.

```text
REVIEW_FOLDER_PATH=Reviews
IMPLEMENTATION_SPEC_PATH=specs
WORK_ORDER_PATH=work-orders/<work-order>/tasks.md
PACKAGE_NAME=gatekeeper
CORE_PACKAGE_NAME=
GATE_TEST_CMD=python3 scripts/check-release-safety.py && python3 scripts/check-skills.py && skills-ref validate skills/gatekeeper && skills-ref validate skills/gatekeeper-review && skills-ref validate skills/gatekeeper-release
GATE_BUILD_CMD=python3 scripts/sync-skills.py --check
GATE_PROBES_CMD=
GATE_EXAMPLES_CMD=
RELEASE_CI_WORKFLOW=release.yml
RELEASE_NOTES_CMD=
HOMEBREW_TAP_REPO=
```

The test gate exercises hostile tag and source-symlink cases, checks isolated-install
links and config mirrors, and validates all three skill manifests. `GATE_BUILD_CMD`
verifies that standalone bundles match the canonical workflow sources. The release
workflow repeats these checks from the tagged tree and requires a PASS receipt sealed
to the release commit's parent. All seven reviewer switches are Enabled.

Install the Agent Skills reference validator before starting a fresh gate session:

```bash
# Use Python 3.11+; replace python3 with a newer installed interpreter if needed.
python3 -m venv .venv
.venv/bin/python -m pip install 'git+https://github.com/agentskills/agentskills.git@69ef37e9424c0a7ea9dd2293b559e43ec8176379#subdirectory=skills-ref'
export PATH="$PWD/.venv/bin:$PATH"
```

The checks also need `git`, `node`, `jq`, and Bash. The publisher needs an
authenticated `gh` CLI.

## Release steps

1. Run Gatekeeper Release on the committed candidate. Require a PASS receipt sealed
   to that exact HEAD before any release push or version bump.
2. If the reviewed candidate is not yet on `origin/main`, push that sealed commit
   to `main` after the PASS. Keep the receipt uncommitted so it remains sealed to
   the candidate; the publisher includes it in the release commit.
3. Preview the authorized release through
   `bash skills/gatekeeper-release/scripts/publish.sh X.Y.Z --dry-run` (replace
   `X.Y.Z` with the chosen version). The publisher checks the receipt, current
   remote state, and target tag before proposing changes; the real cut reruns the gates.
4. After explicit user consent covers the version bump, release commit, tag, branch
   and tag pushes, and GitHub Release creation, run
   `bash skills/gatekeeper-release/scripts/publish.sh X.Y.Z`. It generates the notes,
   bumps `.claude-plugin/plugin.json`, commits the PASS receipt and notes, creates
   the matching annotated tag, pushes, and watches the exact workflow run.
   `.claude-plugin/marketplace.json` has no version field.
5. The tag triggers `.github/workflows/release.yml`. Its read-only job validates the
   tagged tree, matching receipt, and tag-to-commit identity; a separate write-enabled
   job creates or updates the GitHub Release from committed notes using GitHub's
   built-in `GITHUB_TOKEN`.

Never treat the gate PASS as consent to bump, commit, tag, push, or publish. The
user's release request must cover the target and each of those actions. If the
workflow fails, inspect and rerun the existing tag workflow; do not create another
version to retry it.
