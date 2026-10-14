---
name: gatekeeper-review
description: Run the full adversarial Gatekeeper review after implementation or for a work order, branch, diff, or PR. Includes deterministic checks, task truth, fresh reviewers, findings verification, verdict, receipt, and bounded repairs. Ends before any commit or release operation.
license: MIT
---

# Gatekeeper Review

One rule above all: **nobody grades their own exam.** The agent that implemented a work order never runs this gate on it, and every reviewer runs fresh — a new session that has never seen the implementer's reasoning, summaries, or apologies. If an independent fresh gatekeeper session is unavailable, report BLOCKED.
Never review your own implementation or substitute another pass in the same context.

This is the complete review workflow. Read each phase when you reach it. Reviewer
mandates and source methods are bundled locally; no external skill is required.

## Scope and permissions

Use after implementing changes, or for a work-order, branch, diff, or PR review.
Run the entire six-phase gate, including task truth and the complete eligible fleet.
This workflow ends with a verdict and receipt. It never creates commits, bumps
versions, generates release notes, tags, pushes, publishes, or retries release CI.
A PASS authorizes none of those actions. If Release is proposed, ask for explicit
user confirmation and wait before entering it. For an explicitly requested Release,
load the installed Gatekeeper Release or router workflow. If neither is available,
report the missing skill; never reconstruct publishing instructions inside Review.

The seal remains committed HEAD. Do not create a commit to satisfy it. If the
requested implementation exists only in the working tree, report BLOCKED and ask
the owner to supply a committed candidate. Review does not require release CI,
registry credentials, a package name, or publishing configuration.

## Configuration

The skill adapts to any repo through these variables. **Set each value twice**: in this workflow's Configuration section (what the gate agent reads) and in `config.sh` (what the scripts source). A human follows [setup instructions](references/setup.md). `<set-me>` = required, resolve before Phase 0; empty = optional feature, off.

Paths:

- `REVIEW_FOLDER_PATH` (the folder where gate review receipts are written) = `<set-me>`
- `IMPLEMENTATION_SPEC_PATH` (the folder where the implementation spec and planning documentation are) = `<set-me>`
- `WORK_ORDER_PATH` (where work orders live or are created; may contain `<spec>`/`<work-order>` placeholders) = `<set-me>`

Gates:

- `GATE_TEST_CMD` (the full test gate) = `<set-me>`
- `GATE_BUILD_CMD` (the build gate) = `<set-me>`
- `GATE_PROBES_CMD` (optional probe/deep-check gate) = ``
- `GATE_EXAMPLES_CMD` (optional examples/docs gate) = ``

A developer adapting this skill can change any value — that is the whole point. Resolve all of them before Phase 0; the gate never silently assumes values.

## Inputs

- Mode = `REVIEW`. Shared phases use this value for receipt scope.
- Branch + sealed HEAD SHA (recorded in Phase 1; if HEAD moves mid-gate, discard and restart)
- The work order: `WORK_ORDER_PATH` (and the parent spec's requirements/acceptance-criteria list, under `IMPLEMENTATION_SPEC_PATH`)
- A clean candidate tree; dirty implementation changes block the gate without committing them.
- The diff range: work-order base SHA → sealed HEAD (`git diff <base>..<head>`)

## The gate, in order

| Phase | File | One line |
|---|---|---|
| 0 | [steps/phase-0-deterministic-checks.md](steps/phase-0-deterministic-checks.md) | Run the configured gates; record output; any red is FAIL |
| 1 | [steps/phase-1-seal.md](steps/phase-1-seal.md) | Freeze the SHA; grade everything against the committed tree |
| 2 | [steps/phase-2-task-truth.md](steps/phase-2-task-truth.md) | Grade every `[x]` TRUE/PARTIAL/FALSE against the seal |
| 3 | [steps/phase-3-fleet.md](steps/phase-3-fleet.md) | Dispatch fresh reviewer subagents with their mandates |
| 4 | [steps/phase-4-findings-verification.md](steps/phase-4-findings-verification.md) | Gate keeper re-runs every load-bearing finding first-hand; Architect joins |
| 5 | [steps/phase-5-verdict-and-receipt.md](steps/phase-5-verdict-and-receipt.md) | Computed verdict + receipt to `REVIEW_FOLDER_PATH` |

## Reviewer switches

Each reviewer is a boolean. **Enabled** = it wakes in Phase 3 per the risk table; **Disabled** = it is skipped entirely, and the receipt says so. Override these in your repo's AGENTS.md or state them when invoking the gate — the defaults below are all-on.

- Red Team = Enabled
- Code Reviewer = Enabled
- Security Reviewer = Enabled
- Scrutinizer = Enabled
- Repo Auditor = Enabled
- Ponytail Reviewer = Enabled
- Architect = Enabled

At least one reviewer must stay enabled — a gate with zero reviewers is not a gate. When enabled, the Architect only joins in Phase 4.

## The fleet — who wakes

| Reviewer | Mandate | Judges |
|---|---|---|
| Red Team | [reviewers/red-team.md](reviewers/red-team.md) | The burglar and the examiner — exploits it, and finds what the implementation got wrong |
| Code Reviewer | [reviewers/code-reviewer.md](reviewers/code-reviewer.md) | Correctness, races, test honesty — reads code, not summaries |
| Security Reviewer | [reviewers/security-reviewer.md](reviewers/security-reviewer.md) | The white hat — known vulnerability classes, patterns, and dependency CVEs |
| Scrutinizer | [reviewers/scrutinizer.md](reviewers/scrutinizer.md) | Docs-as-written first hour — never sees code |
| Repo Auditor | [reviewers/repo-auditor.md](reviewers/repo-auditor.md) | Duplicates, drift, orphans, claims truth — reads across |
| Ponytail Reviewer | [reviewers/ponytail-reviewer.md](reviewers/ponytail-reviewer.md) | The lazy senior dev — what to cut from the diff, over-engineering only |
| Architect | [reviewers/architect.md](reviewers/architect.md) | The premise — joins after findings verification |

Switches above gate this table: a disabled reviewer never wakes, whatever the risk class.

- Docs-only change: Scrutinizer + Repo Auditor
- Tooling/CI: Code Reviewer + Repo Auditor
- Engine, permissions, auth, providers, dependencies, anything security-reachable: full fleet (all seven)
- Any code-bearing change where the Ponytail Reviewer is enabled: it rides along — over-engineering hides everywhere

## Loop control

One bounded loop: findings go back for repair, repairs re-enter the FULL gate on a new seal. Maximum two repair attempts, then call the owner. The implementer cannot edit tests, baselines, or the work order's verify lines to make a gate pass — flag any such edit as a finding.
