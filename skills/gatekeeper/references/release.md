# Gatekeeper Release

One rule above all: **nobody grades their own exam.** The agent that implemented a work order never runs this gate on it, and every reviewer runs fresh — a new session that has never seen the implementer's reasoning, summaries, or apologies. If an independent fresh gatekeeper session is unavailable, report BLOCKED.
Never review your own implementation or substitute another pass in the same context.

This is the full release workflow. Read each phase when you reach it. Reviewer
mandates and source methods are bundled locally; no external skill is required.

## User consent

Enter this workflow only when the user explicitly requests Gatekeeper Release or a
release operation. If the model proposes Release, it MUST ask for explicit user
confirmation and wait for the reply before entering this workflow. A repository
rule requiring a gate before push, version bump, or release is a prerequisite,
never consent to enter Release or perform those operations.

Invoking Release authorizes verification only unless the user also explicitly
requests the mutations. Before committing, bumping versions, tagging, pushing,
publishing, or retrying release CI, check that the user's explicit request covers
those actions and the target. Otherwise present the concrete release plan, ask for
confirmation, and wait. Silence, elapsed time, a PASS, and implementation completion
are never consent. Never answer the publishing script's confirmation on the user's
behalf without that consent. Review-only requests never enter this workflow.

## Configuration

The skill adapts to any repo through these variables. **Set each value twice**: in this workflow's Configuration section (what the gate agent reads) and in `config.sh` (what the scripts source). A human follows [setup instructions](setup.md). `<set-me>` = required, resolve before Phase 0; empty = optional feature, off.

Paths:

- `REVIEW_FOLDER_PATH` (the folder where gate review receipts are written) = `Reviews`
- `IMPLEMENTATION_SPEC_PATH` (the folder where the implementation spec and planning documentation are) = `specs`
- `WORK_ORDER_PATH` (where work orders live or are created; may contain `<spec>`/`<work-order>` placeholders) = `work-orders/<work-order>/tasks.md`

Package and gates:

- `PACKAGE_NAME` (the package this skill releases) = `gatekeeper`
- `CORE_PACKAGE_NAME` (optional second package released in lockstep) = ``
- `GATE_TEST_CMD` (the full test gate) = `python3 scripts/check-release-safety.py && python3 scripts/check-skills.py && skills-ref validate skills/gatekeeper && skills-ref validate skills/gatekeeper-review && skills-ref validate skills/gatekeeper-release`
- `GATE_BUILD_CMD` (the build gate) = `python3 scripts/sync-skills.py --check`
- `GATE_PROBES_CMD` (optional probe/deep-check gate) = ``
- `GATE_EXAMPLES_CMD` (optional examples/docs gate) = ``

Release plumbing:

- `RELEASE_CI_WORKFLOW` (tag-triggered workflow under `.github/workflows/`) = `release.yml`
- `RELEASE_NOTES_CMD` (optional custom notes generator) = ``
- `HOMEBREW_TAP_REPO` (optional Homebrew tap as `owner/repo`) = ``

A developer adapting this skill can change any value — that is the whole point. Resolve all of them before Phase 0; the gate never silently assumes values.

- **First install in a new repo?** Read [FIRST_INSTALL.md](../FIRST_INSTALL.md) once — it wires up the tag-triggered CI release workflow this gate hands off to. Skip it afterwards.

## Inputs

- Mode = `RELEASE`. Shared phases use this value for receipt scope.
- Branch + sealed HEAD SHA (recorded in Phase 1; if HEAD moves mid-gate, discard and restart)
- The work order: `WORK_ORDER_PATH` (and the parent spec's requirements/acceptance-criteria list, under `IMPLEMENTATION_SPEC_PATH`)
- A clean candidate tree; dirty implementation changes block the gate without committing them.
- The diff range: work-order base SHA → sealed HEAD (`git diff <base>..<head>`)

## The gate, in order

| Phase | File | One line |
|---|---|---|
| 0 | [steps/phase-0-deterministic-checks.md](../steps/phase-0-deterministic-checks.md) | Run the configured gates; record output; any red is FAIL |
| 1 | [steps/phase-1-seal.md](../steps/phase-1-seal.md) | Freeze the SHA; grade everything against the committed tree |
| 2 | [steps/phase-2-task-truth.md](../steps/phase-2-task-truth.md) | Grade every `[x]` TRUE/PARTIAL/FALSE against the seal |
| 3 | [steps/phase-3-fleet.md](../steps/phase-3-fleet.md) | Dispatch fresh reviewer subagents with their mandates |
| 4 | [steps/phase-4-findings-verification.md](../steps/phase-4-findings-verification.md) | Gate keeper re-runs every load-bearing finding first-hand; Architect joins |
| 5 | [steps/phase-5-verdict-and-receipt.md](../steps/phase-5-verdict-and-receipt.md) | Computed verdict + receipt to `REVIEW_FOLDER_PATH` |

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
| Red Team | [reviewers/red-team.md](../reviewers/red-team.md) | The burglar and the examiner — exploits it, and finds what the implementation got wrong |
| Code Reviewer | [reviewers/code-reviewer.md](../reviewers/code-reviewer.md) | Correctness, races, test honesty — reads code, not summaries |
| Security Reviewer | [reviewers/security-reviewer.md](../reviewers/security-reviewer.md) | The white hat — known vulnerability classes, patterns, and dependency CVEs |
| Scrutinizer | [reviewers/scrutinizer.md](../reviewers/scrutinizer.md) | Docs-as-written first hour — never sees code |
| Repo Auditor | [reviewers/repo-auditor.md](../reviewers/repo-auditor.md) | Duplicates, drift, orphans, claims truth — reads across |
| Ponytail Reviewer | [reviewers/ponytail-reviewer.md](../reviewers/ponytail-reviewer.md) | The lazy senior dev — what to cut from the diff, over-engineering only |
| Architect | [reviewers/architect.md](../reviewers/architect.md) | The premise — joins after findings verification |

Switches above gate this table: a disabled reviewer never wakes, whatever the risk class.

- Docs-only change: Scrutinizer + Repo Auditor
- Tooling/CI: Code Reviewer + Repo Auditor
- Engine, permissions, auth, providers, dependencies, anything security-reachable: full fleet (all seven)
- Any code-bearing change where the Ponytail Reviewer is enabled: it rides along — over-engineering hides everywhere

## Loop control

One bounded loop: findings go back for repair, repairs re-enter the FULL gate on a new seal. Maximum two repair attempts, then call the owner. The implementer cannot edit tests, baselines, or the work order's verify lines to make a gate pass — flag any such edit as a finding.

## Scripts

The cut itself lives here too. After a PASS verdict and explicit user consent for the release operations: `scripts/publish.sh` (this folder) requires exactly one PASS receipt sealed to the current HEAD, guards the tree, runs both configured gates, bumps the package manifest, drafts notes via `RELEASE_NOTES_CMD` or the bundled `scripts/generate-release-notes.mjs`, tags, pushes, and watches the workflow run for that commit. It supports npm packages and Claude Code plugin manifests. Try `publish.sh patch --dry-run` first. A dry run does not authorize the real cut.

Commit, versioning, and publishing practice — conventional-commit format, lockstep semver, registry ordering, tap mechanics, failure recovery — is documented in [PUBLISHING.md](../PUBLISHING.md). Read it before your first cut.

Keep `.claude-plugin/plugin.json` version in sync with the release tag when that
manifest exists. Inspect the publisher before use; adapt its manifest handling for
non-npm packages rather than pretending it supports them.
