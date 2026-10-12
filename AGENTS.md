# AGENTS.md — adapting gatekeeper to this repo

You are an agent setting up the gatekeeper skill for the repository you are in.
Follow these steps in order. Do not skip the ordering: configuration before CI, CI
before the first gate.

## 1. Fill the variable family

Open `config.sh` in this skill folder and replace every `<set-me>`:

- `REVIEW_FOLDER_PATH` — pick (or create) the folder where release review receipts
  are written. Inside the repo (e.g. `Reviews/`) or a docs store both work; pick what
  this repo already uses for review records.
- `IMPLEMENTATION_SPEC_PATH` — where this repo keeps specs and planning docs. If it
  keeps none, propose a folder and create it when the first spec lands.
- `WORK_ORDER_PATH` — where work-order task files live or should be created. The
  convention this skill grades against is a checklist file with `[x]` rows and a
  verify line per task; if the repo's work orders live elsewhere, point at that path.
- `PACKAGE_NAME` — the released package's name from the manifest. For a monorepo
  releasing two packages in lockstep (core + root), also set `CORE_PACKAGE_NAME`;
  otherwise leave it empty.
- `GATE_TEST_CMD` / `GATE_BUILD_CMD` — the exact commands that run the full suite and
  the build in this repo (check `package.json` scripts, `Makefile`, `justfile`…).
  Set `GATE_PROBES_CMD` / `GATE_EXAMPLES_CMD` only if such gates exist.
- `RELEASE_CI_WORKFLOW` — the tag-triggered workflow's file name (default
  `release.yml`; confirm against `.github/workflows/`).
- `RELEASE_NOTES_CMD`, `HOMEBREW_TAP_REPO` — leave empty unless the repo has a notes
  generator / a tap.

Then **mirror every value** into the entry `SKILL.md` § Configuration — that copy is
what the gate agent reads at run time. The two places must never disagree.

Report any value you could not determine to the user instead of guessing.

## 2. Wire CI (once)

Follow [FIRST_INSTALL.md](FIRST_INSTALL.md): copy and adapt the release workflow,
set the registry secret (`NPM_TOKEN` or your registry's equivalent), add the tap
token only if `HOMEBREW_TAP_REPO` is set.

## 3. Set the reviewer switches

`SKILL.md` § Reviewer switches, one boolean per reviewer, all Enabled by default.
Turn a reviewer off only when the user asks or the repo has no surface for it (e.g.
no docs → the Scrutinizer has nothing to walk — say so, don't silently disable).

## 4. Teach the repo's AGENTS.md

Add a short section to the **repo's** AGENTS.md so future sessions know:

- the gate is mandatory before any push, version bump, or release cut;
- the variable values (or a pointer to this skill's `config.sh`);
- the reviewer switches in force;
- when cutting a release, keep `.claude-plugin/plugin.json` `version` in sync with
  the tag.

## 5. Do not change

The verdict rules, the fresh-session rule, the seal discipline, and the two-repair
loop are the gate's spine — adapt configuration, never these. If a step genuinely
cannot work in this repo, surface that; do not quietly rewrite the gate around the
obstacle.
