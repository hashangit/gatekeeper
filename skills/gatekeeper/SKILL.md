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
