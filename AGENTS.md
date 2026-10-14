# Working on Gatekeeper

This repository distributes three skills, rather than an npm package. Repo-specific
configuration remains a template until a skill is installed into a target repo.

## Ownership and checks

- Edit `skills/gatekeeper/`, the canonical router and workflow source.
- `skills/gatekeeper-review/` and `skills/gatekeeper-release/` are generated bundles.
  Run `python3 scripts/sync-skills.py` after changing canonical content.
- Run `python3 scripts/sync-skills.py --check` and
  `python3 scripts/check-skills.py` before completing changes. CI also validates
  all three entrypoints against the Agent Skills specification.
- Preserve bundled third-party source skills and their credits.

## Review and release policy

The gate is mandatory before any push, version bump, or release cut. This is a
prerequisite, never user consent. Gatekeeper defaults to Review. Enter Release only
when the user explicitly requests it; if the model proposes Release, ask for explicit
confirmation and wait. Commit creation, version bumps, tags, pushes, publishing,
and release CI retries need explicit consent covering those actions and target.
A passing review never authorizes a release.

Review includes the entire original six-phase review gate and all seven reviewer
mandates. All switches default to Enabled. Preserve the verdict rules, fresh-session
rule, committed-HEAD seal, and two-repair limit. The implementing agent cannot run
its own gate; lack of fresh independent sessions is BLOCKED.

When cutting an explicitly authorized release, keep `.claude-plugin/plugin.json`
version in sync with the tag. Do not bump it merely for local skill edits.
For this repository's release config and GitHub Release flow, follow
[RELEASE_PROCESS.md](RELEASE_PROCESS.md). The packaged `skills/gatekeeper/config.sh`
stays generic for installs into other repos.

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
