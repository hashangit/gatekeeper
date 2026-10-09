#!/usr/bin/env bash
# gatekeeper configuration — the one file you fill in to adapt this skill to your repo.
# Mirror the same values in SKILL.md § Configuration (that copy is what the gate agent reads).
# "<set-me>" = required. Empty = optional feature, off.

# --- paths ------------------------------------------------------------------
# Folder where gate review receipts are written.
REVIEW_FOLDER_PATH="<set-me>"
# Folder where the implementation specs and planning documentation live.
IMPLEMENTATION_SPEC_PATH="<set-me>"
# Where work orders live or are created, e.g.
# "$IMPLEMENTATION_SPEC_PATH/<spec>/<work-order>/tasks.md".
WORK_ORDER_PATH="<set-me>"

# --- package & gates --------------------------------------------------------
# The package this skill releases (its name in the manifest / registry).
PACKAGE_NAME="<set-me>"
# Optional second package released in lockstep (core + root monorepo split).
CORE_PACKAGE_NAME=""
# Phase 0 deterministic gates — run verbatim by the gate and by publish.sh.
GATE_TEST_CMD="<set-me>"
GATE_BUILD_CMD="<set-me>"
GATE_PROBES_CMD=""
GATE_EXAMPLES_CMD=""

# --- release plumbing -------------------------------------------------------
# Tag-triggered CI workflow that publishes (file name under .github/workflows/).
RELEASE_CI_WORKFLOW="release.yml"
# Optional custom release-notes command; empty = bundled scripts/generate-release-notes.mjs.
RELEASE_NOTES_CMD=""
# Optional Homebrew tap as "owner/repo"; empty = no tap step.
HOMEBREW_TAP_REPO=""
