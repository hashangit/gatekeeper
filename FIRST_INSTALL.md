# First install — wiring up the release workflow

Read this **once**, when installing the gatekeeper skill into a new repo. It connects
the last mile: the gate passes locally, the tag fires CI, CI publishes. After setup,
you never need this file again — the entry `SKILL.md` is the day-to-day flow.

Before starting: the variable family in `config.sh` + `SKILL.md` § Configuration
should already be filled in (README.md § Setup, or hand it to your agent with
[AGENTS.md](AGENTS.md)).

## What you're setting up

The release flow is a two-stage relay:

1. **Local** — the gate reviews, then `scripts/publish.sh` bumps the version, tags,
   and pushes.
2. **CI (GitHub Actions)** — the tag triggers `RELEASE_CI_WORKFLOW` (default
   `release.yml`), which builds and publishes: your package registry, optionally the
   Homebrew tap, and a GitHub Release.

Publishing lives on CI, not your laptop, for three reasons: the registry token stays
in GitHub secrets, packages get signed provenance (requires a CI OIDC token), and the
exact sealed commit is what gets built.

## Setup steps

1. **Copy the workflow.** Copy `.github/workflows/release.yml` (from the repo you
   took this skill from, or write one) into the target repo at the same path. Adapt:
   - Package name(s) in the publish job(s) — `PACKAGE_NAME` (and `CORE_PACKAGE_NAME`
     if lockstep; delete the core-first job if single-package).
   - Any build jobs you don't need (e.g. a native/Rust helper job — delete it and
     remove it from the publish job's `needs:`).
   - The Homebrew tap job — keep only if `HOMEBREW_TAP_REPO` is set.
2. **Add the registry secret.** Repo Settings → Secrets and variables → Actions → new
   repository secret `NPM_TOKEN`. Use an automation or granular token with publish
   rights for your package, nothing broader. Keeping the tap job? Add
   `HOMEBREW_TAP_TOKEN` too (write access to the tap repo, nothing more).
3. **Check the local toolchain** (whatever machine runs the gate and `publish.sh`):
   `git`, `gh` (authenticated — `gh auth login`), `jq`, `npm`, and whatever your
   gate commands need.
4. **First release bootstrap.** A package that has never been published is "ready",
   not broken: `publish.sh` treats absent-from-registry + unclaimed tag as a clean
   slate, so the first cut doesn't deadlock on the version-match guard.
5. **Dry run, then cut:**
   ```bash
   bash .agents/skills/gatekeeper/scripts/publish.sh patch --dry-run
   # ...run the gate first on the real thing, then:
   bash .agents/skills/gatekeeper/scripts/publish.sh patch
   ```
   The script watches the CI run and prints the release link on success.

## If a publish job fails mid-release

Don't re-run `publish.sh` — it bumps a new version. Re-run the failed CI job on the
**existing tag**; the skip-if-exists logic heals the half-published state.
