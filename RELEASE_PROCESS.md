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
# Use any installed Python 3.11+ interpreter (for example, python3.12).
python3.12 -m venv .venv
.venv/bin/python -m pip install 'git+https://github.com/agentskills/agentskills.git@69ef37e9424c0a7ea9dd2293b559e43ec8176379#subdirectory=skills-ref'
export PATH="$PWD/.venv/bin:$PATH"
```

The checks also need `git`, `node`, `jq`, and Bash. The publisher needs an
authenticated `gh` CLI.

## Release steps

1. Use Gatekeeper Release on the committed candidate. Require the receipt to say
   PASS before making the version bump or cutting a tag.
2. Choose the semver bump based on scope. Update `.claude-plugin/plugin.json`; keep
   its version in sync with the tag. `.claude-plugin/marketplace.json` has no version
   field and needs no version bump.
3. Generate and edit `RELEASE_NOTES-vX.Y.Z.md` before the release commit. Include the
   Gatekeeper receipt with the release change.
4. Commit the release change, create the matching annotated tag, and push the branch
   and tag to `origin`. User consent must cover those actions and this repository.
5. The tag triggers `.github/workflows/release.yml`. Its read-only job validates the
   tagged tree and receipt; a separate write-enabled job creates the GitHub Release
   from the committed notes. It uses only GitHub's built-in `GITHUB_TOKEN`.

Never treat the gate PASS as consent to bump, commit, tag, push, or publish. If the
workflow fails, inspect and rerun the existing tag workflow; do not create another
version to retry it.
