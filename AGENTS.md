# Working on Gatekeeper

This repo distributes three skills rather than an npm package. The current repo
configuration is filled in at `skills/gatekeeper/config.sh`; target repositories
must configure their installed skill separately.

## Ownership and checks

- Edit `skills/gatekeeper/`, the canonical router and workflow source.
- `skills/gatekeeper-review/` and `skills/gatekeeper-release/` are generated bundles.
  Run `python3 scripts/sync-skills.py` after changing canonical content.
- Run `python3 scripts/check-release-safety.py`,
  `python3 scripts/sync-skills.py --check`, and `python3 scripts/check-skills.py`
  before completing changes. CI also validates all three entrypoints against the
  Agent Skills specification.
- Preserve bundled third-party source skills and their credits.

## Review and release policy

The gate is mandatory before any push, version bump, or release cut. This is a
prerequisite, never user consent. Gatekeeper defaults to Review. Enter Release only
when the user explicitly requests it or confirms the model's proposal. Commit
creation, version bumps, tags, pushes, publishing, and release CI retries need
explicit consent covering those actions and target. A passing review never
authorizes a release.

Review includes the entire original six-phase review gate and all seven reviewer
mandates. All switches default to Enabled. Preserve the verdict rules, fresh-session
rule, committed-HEAD seal, and two-repair limit. The implementing agent cannot run
its own gate; lack of fresh independent sessions is BLOCKED.

When cutting an explicitly authorized release, keep `.claude-plugin/plugin.json`
version in sync with the tag. Do not bump it merely for local skill edits. For this
repository's release config and GitHub Release flow, follow
[RELEASE_PROCESS.md](RELEASE_PROCESS.md).

## Repository release configuration

- `REVIEW_FOLDER_PATH=Reviews`
- `IMPLEMENTATION_SPEC_PATH=specs`
- `WORK_ORDER_PATH=work-orders/<work-order>/tasks.md`
- `PACKAGE_NAME=gatekeeper`; `CORE_PACKAGE_NAME` is empty.
- `GATE_TEST_CMD` includes release safety probes, isolated bundle checks, and all
  three `skills-ref validate` commands.
- `GATE_BUILD_CMD=python3 scripts/sync-skills.py --check`; probe and example gates
  are empty.
- `RELEASE_CI_WORKFLOW=release.yml`; notes command and Homebrew tap are empty.
- Reviewer switches: `Red Team = Enabled`, `Code Reviewer = Enabled`,
  `Security Reviewer = Enabled`, `Scrutinizer = Enabled`, `Repo Auditor = Enabled`,
  `Ponytail Reviewer = Enabled`, and `Architect = Enabled`.

Install the pinned `skills-ref` validator as described in `RELEASE_PROCESS.md`
before running the configured gates.

## Adapting an installation to a target repo

Follow [the setup instructions](skills/gatekeeper/references/setup.md). Fill the
installed skill's `config.sh` and mirror every applicable value in its workflow
Configuration section. Report any value that cannot be determined instead of
guessing. For the router, mirror review values in both workflow references.

Review setup uses only review paths and gates. Release setup additionally follows
[FIRST_INSTALL.md](skills/gatekeeper/FIRST_INSTALL.md): configuration before CI,
CI before the first release gate. Never make Review depend on release setup.

Turn a reviewer off only at the user's request or when the repo has no applicable
surface, and explain why. Teach the target repo's AGENTS.md the gate prerequisite,
config location, reviewer switches, explicit release consent rule, and plugin/tag
version synchronization. Never rewrite gate rules around an adaptation obstacle.
