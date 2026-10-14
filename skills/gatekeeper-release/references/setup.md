# Configure an installed Gatekeeper skill

## Review setup

Fill the review variables in the installed skill's `config.sh` before Phase 0:

- `REVIEW_FOLDER_PATH`: the repo's review receipt folder.
- `IMPLEMENTATION_SPEC_PATH`: the specs and planning documentation folder.
- `WORK_ORDER_PATH`: checklist work orders with `[x]` rows and verify lines.
- `GATE_TEST_CMD` and `GATE_BUILD_CMD`: the exact full-suite and build commands.
- `GATE_PROBES_CMD` and `GATE_EXAMPLES_CMD`: set only if those checks exist.

Mirror values into the Configuration section of the installed Review entrypoint.
For the router, mirror them in `references/review.md` and `references/release.md`.
Report unresolved required values instead of guessing or silently skipping gates.
If a required gate or work order cannot work in this repo, surface the obstacle.

All seven reviewers are Enabled by default. Turn one off only at the user's request
or when the repo has no applicable surface, and explain why. Record overrides in
the repo's AGENTS.md and the receipt. Eligibility then follows the risk table.

Review setup requires no registry credentials or release workflow. Review keeps the
committed-HEAD seal and task-truth grading; it does not commit uncommitted work.

## Release setup

Only after the user explicitly requests Release, fill the release values too:
`PACKAGE_NAME`, optional `CORE_PACKAGE_NAME`, `RELEASE_CI_WORKFLOW`, optional
`RELEASE_NOTES_CMD`, and optional `HOMEBREW_TAP_REPO`. Mirror every value in the
Release entrypoint, or `references/release.md` for the router.

Configuration comes before CI; CI comes before the first release gate. Read the
bundled FIRST_INSTALL.md only for Release. Obtain consent for external CI changes
and never expose registry or tap credentials in output.

## Teach the target repo

Add a short AGENTS.md section pointing to this installation's configuration and
reviewer switches. State that the gate is mandatory before any push, version bump,
or release cut, and that this prerequisite does not authorize those actions or
allow the model to enter Release without explicit user consent. Review is the
default after implementation. Keep `.claude-plugin/plugin.json` version in sync
with the release tag when that manifest exists.

Configure the installed skill actually being invoked. Separate copied skills have
separate configurations; configuring one does not configure the others.

Never weaken the verdict, fresh-session, seal, or two-repair rules to adapt a repo.
