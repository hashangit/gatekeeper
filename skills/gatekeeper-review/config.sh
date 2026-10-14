#!/usr/bin/env bash
# gatekeeper configuration — the one file you fill in to adapt this skill to your repo.
# Mirror values in the active workflow Configuration section.
# Router: references/review.md + references/release.md; standalone: SKILL.md.
# "<set-me>" = required. Empty = optional feature, off.

# --- paths ------------------------------------------------------------------
# Folder where gate review receipts are written.
REVIEW_FOLDER_PATH="<set-me>"
# Folder where the implementation specs and planning documentation live.
IMPLEMENTATION_SPEC_PATH="<set-me>"
# Where work orders live or are created, e.g.
# "$IMPLEMENTATION_SPEC_PATH/<spec>/<work-order>/tasks.md".
WORK_ORDER_PATH="<set-me>"

# --- gates -------------------------------------------------------------
GATE_TEST_CMD="<set-me>"
GATE_BUILD_CMD="<set-me>"
GATE_PROBES_CMD=""
GATE_EXAMPLES_CMD=""
