# Gatekeeper

[![skills.sh](https://skills.sh/b/hashangit/gatekeeper?style=for-the-badge)](https://skills.sh/hashangit/gatekeeper)

Gatekeeper reviews implemented changes through deterministic checks, task-truth
grading, independent fresh reviewers, verified findings, a computed verdict, and a
receipt. Release operations require explicit user consent.

| Skill | Use |
|---|---|
| [Gatekeeper](skills/gatekeeper/SKILL.md) | Router. Defaults to Review; Release requires an explicit user request or confirmation. |
| [Gatekeeper Review](skills/gatekeeper-review/SKILL.md) | The entire original review flow, ending with a verdict and receipt. |
| [Gatekeeper Release](skills/gatekeeper-release/SKILL.md) | The full review gate plus consent-controlled commit and release operations. |

"Nobody grades their own exam" applies to both workflows. The implementing agent
hands the gate to an independent fresh session. Each reviewer also starts fresh,
without the implementer's reasoning or summaries. If isolation is unavailable,
the gate reports BLOCKED.

## Install

Install all three skills:

```bash
npx skills add hashangit/gatekeeper --skill gatekeeper gatekeeper-review gatekeeper-release
```

Or install one skill by its name. Every skill is self-contained, including the
router, so a copied installation never depends on a sibling skill being present.

```bash
npx skills add hashangit/gatekeeper --skill gatekeeper-review
```

For the Claude Code plugin:

```text
/plugin marketplace add hashangit/gatekeeper
/plugin install gatekeeper@gatekeeper
```

For a manual installation, copy the chosen folder from `skills/` into the agent's
skills directory. Keep the folder name and its complete contents. For example,
copy `skills/gatekeeper-review/` to `.agents/skills/gatekeeper-review/`.

Existing installations of the old root skill must update to this layout. Configure
the installed skill you actually invoke; copied installations have separate configs.

## Usage and consent

- "Use Gatekeeper to review this implemented work order." selects Review.
- "Use Gatekeeper Review on this branch." runs the complete review gate.
- "Run Gatekeeper Release checks." authorizes release verification only.
- "Cut and publish version 1.2.3 with Gatekeeper Release." explicitly requests the
  named release operations, subject to the gate passing.

If the model wants to enter Release, it must ask for explicit user confirmation
and wait. A PASS, completed implementation, silence, or a repo policy requiring a
gate before push never authorizes Release. Commit creation, version bumps, tags,
pushes, publishing, and release CI retries require consent covering the actual
actions and target. A dry run never authorizes a real cut.

## Setup

These are reusable skills, so `<set-me>` values deliberately remain unresolved in
the distribution. Fill them for the target repo, never guess missing values.
Follow [the setup instructions](skills/gatekeeper/references/setup.md).

Review requires receipt/spec/work-order paths, the exact full-suite and build
commands, and any existing probe/examples gates. Mirror the values from `config.sh`
in the skill's Configuration section. For the router, mirror them in both workflow
references. All seven reviewer switches default to Enabled.

Release additionally requires package and release configuration. Configure those
values before [CI setup](skills/gatekeeper/FIRST_INSTALL.md), and wire CI before the
first release gate. Review requires neither release CI nor registry credentials.

Both modes retain the committed-HEAD seal and checklist work orders with verify
lines. Uncommitted implementation changes block the gate; Review never creates a
commit for you. If the repo cannot provide a required gate or work order, report the
obstacle instead of weakening the review.

## The complete review flow

1. Run the configured checks on a clean committed candidate and capture results.
2. Seal that same HEAD. A changed candidate invalidates the checks and review.
3. Grade every completed task TRUE, PARTIAL, or FALSE against the seal.
4. Dispatch independent fresh reviewers according to switches and change risk.
5. Verify material findings first-hand, then bring in the enabled Architect.
6. Compute PASS, FAIL, or BLOCKED and write a receipt identifying the mode and seal.

The seven mandates are Red Team, Code Reviewer, Security Reviewer, Scrutinizer,
Repo Auditor, Ponytail Reviewer, and Architect. Risk determines which enabled
reviewers run, exactly as in the original gate. Findings return to the implementer;
repairs re-enter the full gate on a new seal, with at most two repair attempts.

Review stops at the receipt. Release continues only within explicit user consent.
A Review receipt never substitutes for the full Release gate and its receipt.
Publishing mechanics are in [PUBLISHING.md](skills/gatekeeper/PUBLISHING.md).
The bundled publisher currently targets npm-style package manifests; other release
systems need an explicit adaptation.

## Maintaining this repo

The router folder owns the canonical workflows, phase files, reviewer mandates,
resources, and publishing scripts. The two standalone skills are generated copies
so they can be installed independently without runtime dependencies.

```text
skills/gatekeeper/           Canonical router and bundled workflow instructions
skills/gatekeeper-review/    Generated standalone review bundle
skills/gatekeeper-release/   Generated standalone release bundle
scripts/sync-skills.py       Generate bundles or check for drift
scripts/check-skills.py      Check isolated bundles, links, and config mirrors
```

Edit canonical files, then run:

```bash
python3 scripts/sync-skills.py
python3 scripts/sync-skills.py --check
python3 scripts/check-skills.py
```

CI checks release safety, bundle drift, isolated file references, configuration
mirrors, and the Agent Skills format. Shared content has one editable source.
Installed skill copies are configured locally and must not be regenerated using
this maintainer script. Source credits ship in
[resources/README.md](skills/gatekeeper/resources/README.md).

The layout follows the [Agent Skills specification](https://agentskills.io/specification)
and the [Claude Code plugin layout](https://code.claude.com/docs/en/plugins-reference).

This repo's release procedure, config values, and tag flow are in
[RELEASE_PROCESS.md](RELEASE_PROCESS.md). A `vX.Y.Z` tag creates a GitHub Release;
this repo does not publish an npm package.
