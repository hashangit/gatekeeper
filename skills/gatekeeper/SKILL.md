---
name: gatekeeper
description: >-
  Route Gatekeeper requests to the full adversarial review flow or the release
  flow. Use after implementation or when asked for Gatekeeper. Default to Review;
  enter Release only on an explicit user request or after explicit confirmation.
license: MIT
---

# Gatekeeper

Select one workflow and read only that workflow's instructions. Both are bundled
inside this skill, so routing works even when this is the only installed skill.

| Request | Workflow |
|---|---|
| Review implemented changes, a work order, a branch, a diff, or a PR | [Gatekeeper Review](references/review.md) |
| "Gatekeeper", with no explicit release request | [Gatekeeper Review](references/review.md) |
| User explicitly asks for Gatekeeper Release, release verification, or a release operation | [Gatekeeper Release](references/release.md) |
| Model recommends Release, or repo policy calls for it | Ask for explicit user confirmation and wait before entering Release |

Default to Review when the user's intent is ambiguous. Finishing implementation,
passing Review, or a policy requiring a gate before push does not request Release.
Do not enter Release speculatively and ask afterward. Silence is not confirmation.

Entering Release authorizes its checks only. Commit creation, version bumps, tags,
pushes, publishing, and release CI retries require explicit user consent covering
those actions and the target. Carry existing explicit consent forward within its
scope; never infer it from a PASS. Review performs none of these operations.

Both workflows keep the original gate's six phases, seven reviewer mandates,
fresh-session rule, committed-HEAD seal, verdict rules, receipts, and two-repair
limit. The implementer must hand the gate to an independent fresh session without
their reasoning or summaries. If that isolation is unavailable, report BLOCKED;
do not grade your own implementation.

Configuration is in `config.sh`, mirrored in the workflow references. For setup,
read [references/setup.md](references/setup.md). Unresolved required values block
the applicable workflow, but release configuration never blocks Review.

## Configuration

- `REVIEW_FOLDER_PATH` (the folder where gate review receipts are written) = `Reviews`
- `IMPLEMENTATION_SPEC_PATH` (the folder where the implementation spec and planning documentation are) = `specs`
- `WORK_ORDER_PATH` (where work orders live or are created; may contain `<spec>`/`<work-order>` placeholders) = `work-orders/<work-order>/tasks.md`
- `PACKAGE_NAME` (the package this skill releases) = `gatekeeper`
- `CORE_PACKAGE_NAME` (optional second package released in lockstep) = ``
- `GATE_TEST_CMD` (the full test gate) = `python3 scripts/check-release-safety.py && python3 scripts/check-skills.py && skills-ref validate skills/gatekeeper && skills-ref validate skills/gatekeeper-review && skills-ref validate skills/gatekeeper-release`
- `GATE_BUILD_CMD` (the build gate) = `python3 scripts/sync-skills.py --check`
- `GATE_PROBES_CMD` (optional probe/deep-check gate) = ``
- `GATE_EXAMPLES_CMD` (optional examples/docs gate) = ``
- `RELEASE_CI_WORKFLOW` (tag-triggered workflow under `.github/workflows/`) = `release.yml`
- `RELEASE_NOTES_CMD` (optional custom notes generator) = ``
- `HOMEBREW_TAP_REPO` (optional Homebrew tap as `owner/repo`) = ``
