#!/usr/bin/env bash
# gatekeeper configuration — the one file you fill in to adapt this skill to your repo.
# Mirror values in the active workflow Configuration section.
# Router: references/review.md + references/release.md; standalone: SKILL.md.
# "<set-me>" = required. Empty = optional feature, off.

# --- paths ------------------------------------------------------------------
# Folder where gate review receipts are written.
REVIEW_FOLDER_PATH="Reviews"
# Folder where the implementation specs and planning documentation live.
IMPLEMENTATION_SPEC_PATH="specs"
# Where work orders live or are created, e.g.
# "$IMPLEMENTATION_SPEC_PATH/<spec>/<work-order>/tasks.md".
WORK_ORDER_PATH="work-orders/<work-order>/tasks.md"

# --- gates -------------------------------------------------------------
GATE_TEST_CMD="python3 scripts/check-release-safety.py && python3 scripts/check-skills.py && skills-ref validate skills/gatekeeper && skills-ref validate skills/gatekeeper-review && skills-ref validate skills/gatekeeper-release"
GATE_BUILD_CMD="python3 scripts/sync-skills.py --check"
GATE_PROBES_CMD=""
GATE_EXAMPLES_CMD=""
