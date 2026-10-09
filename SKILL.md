---
name: gatekeeper
description: The adversarial release-verification step for any repo that ships from work orders. Runs between "all tasks ticked" and push/release: verifies every [x] against the committed HEAD (task truth), then a fresh-session reviewer fleet (Red Team, Code Reviewer, Security Reviewer, Scrutinizer, Repo Auditor, Ponytail Reviewer, Architect) with mandate cards, findings verified first-hand, and a deterministic verdict computed from evidence. Trigger on /gatekeeper, and mandatorily before any work-order push, version bump, or release cut — nobody grades their own exam.
---

# Gatekeeper

One rule above all: **nobody grades their own exam.** The agent that implemented a work order never runs this gate on it, and every reviewer runs fresh — a new session that has never seen the implementer's reasoning, summaries, or apologies. Context bleed is how work orders ship real engineering with false checkboxes.

This file is the entry point and orchestrator. Each step and each reviewer is its own file in this folder; this skill is self-contained and depends on no external skill.

```
gatekeeper/
├── SKILL.md          ← you are here: routing, configuration, loop control
├── config.sh         ← the variable values (scripts source this file)
├── README.md         ← human setup guide + the flow as one diagram
├── AGENTS.md         ← instructions for an agent adapting this skill to a repo
├── FIRST_INSTALL.md  ← first-time CI setup (once per repo)
├── PUBLISHING.md     ← commit practice, versioning, registry/Homebrew/GitHub Release
├── steps/            ← the six phases, in order
├── reviewers/        ← the seven reviewer mandates
├── resources/        ← source skills the reviewers were adapted from (credited)
└── scripts/          ← publish.sh + generate-release-notes.mjs (the cut itself)
```

## Configuration — the variable family

The skill adapts to any repo through these variables. **Set each value twice**: here (what the gate agent reads) and in `config.sh` (what the scripts source). A human follows [README.md](README.md) § Setup; an agent follows [AGENTS.md](AGENTS.md). `<set-me>` = required, resolve before Phase 0; empty = optional feature, off.

Paths:

- `REVIEW_FOLDER_PATH` (the folder where gate review receipts are written) = `<set-me>`
- `IMPLEMENTATION_SPEC_PATH` (the folder where the implementation spec and planning documentation are) = `<set-me>`
- `WORK_ORDER_PATH` (where work orders live or are created; may contain `<spec>`/`<work-order>` placeholders) = `<set-me>`

Package and gates:

- `PACKAGE_NAME` (the package this skill releases) = `<set-me>`
- `CORE_PACKAGE_NAME` (optional second package released in lockstep) = ``
- `GATE_TEST_CMD` (the full test gate) = `<set-me>`
- `GATE_BUILD_CMD` (the build gate) = `<set-me>`
- `GATE_PROBES_CMD` (optional probe/deep-check gate) = ``
- `GATE_EXAMPLES_CMD` (optional examples/docs gate) = ``

Release plumbing:

- `RELEASE_CI_WORKFLOW` (tag-triggered workflow under `.github/workflows/`) = `release.yml`
- `RELEASE_NOTES_CMD` (optional custom notes generator) = ``
- `HOMEBREW_TAP_REPO` (optional Homebrew tap as `owner/repo`) = ``

A developer adapting this skill can change any value — that is the whole point. Resolve all of them before Phase 0; the gate never silently assumes values.

- **First install in a new repo?** Read [FIRST_INSTALL.md](FIRST_INSTALL.md) once — it wires up the tag-triggered CI release workflow this gate hands off to. Skip it afterwards.

## Inputs

- Branch + sealed HEAD SHA (recorded in Phase 1; if HEAD moves mid-gate, discard and restart)
- The work order: `WORK_ORDER_PATH` (and the parent spec's requirements/acceptance-criteria list, under `IMPLEMENTATION_SPEC_PATH`)
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

Each reviewer is a boolean. **Enabled** = it wakes in Phase 3 per the risk table; **Disabled** = it is skipped entirely, and the receipt says so. Flip these in your repo's AGENTS.md or state them when invoking the gate — the defaults below are all-on.

- Red Team = Enabled
- Code Reviewer = Enabled
- Security Reviewer = Enabled
- Scrutinizer = Enabled
- Repo Auditor = Enabled
- Ponytail Reviewer = Enabled
- Architect = Enabled

At least one reviewer must stay enabled — a gate with zero reviewers is not a gate. The Architect only ever joins in Phase 4, switch or no switch.

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

## Scripts

The cut itself lives here too. After a PASS verdict: `scripts/publish.sh` (this folder) — guards the tree, runs `GATE_TEST_CMD`, bumps the version (plus `CORE_PACKAGE_NAME` in lockstep if set), drafts notes via `RELEASE_NOTES_CMD` or the bundled `scripts/generate-release-notes.mjs`, tags, pushes, and watches `RELEASE_CI_WORKFLOW` publish. Try `publish.sh patch --dry-run` first.

Commit, versioning, and publishing practice — conventional-commit format, lockstep semver, registry ordering, tap mechanics, failure recovery — is documented in [PUBLISHING.md](PUBLISHING.md). Read it before your first cut.
