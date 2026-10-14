# First install — wiring up the release workflow

Release only: read this **once**, when installing the gatekeeper skill into a new repo. It connects
the last mile: the gate passes locally, the tag fires CI, CI publishes. After setup,
you never need this file again — the active Release workflow is the day-to-day flow.

Only perform external CI changes with explicit user consent. Review never needs
this setup. Do not treat CI configuration or a successful dry run as release consent.

Before starting: the variable family in `config.sh` + the active workflow Configuration section
should already be filled in (see [setup instructions](references/setup.md)).

## What you're setting up

The release flow is a two-stage relay:

1. **Local** — the gate reviews, then `scripts/publish.sh` bumps the version, tags,
   and pushes.
2. **CI (GitHub Actions)** — the tag triggers `RELEASE_CI_WORKFLOW` (default
   `release.yml`), which validates the tagged source and creates a GitHub Release.
   Add registry or Homebrew publishing jobs only if the target repo needs them.

The write-enabled job only creates the GitHub Release after a read-only validation
job passes. Put any registry or tap credentials in narrowly scoped CI secrets.

## Setup steps

1. **Copy and adapt the workflow.** Copy `.github/workflows/release.yml` into the
   target repo. It is a minimal GitHub Release pipeline with read-only validation
   followed by a write-enabled release job. Add registry or tap publishing jobs only
   when the target repo needs them, and grant those jobs only the permissions and
   secrets they require.
2. **Add secrets only for configured publishing jobs.** The GitHub Release job uses
   the built-in `GITHUB_TOKEN`. A separate npm publishing job needs `NPM_TOKEN`; a
   Homebrew tap job needs `HOMEBREW_TAP_TOKEN`.
3. **Check the local toolchain** (whatever machine runs the gate and `publish.sh`):
   Python 3.11+, `git`, `gh` (authenticated — `gh auth login`), `jq`, `node`, and
   whatever the configured gate commands need. `npm` is required only for npm
   packages.
4. **Check publisher compatibility.** The bundled publisher supports npm
   `package.json` manifests and Claude Code plugin `.claude-plugin/plugin.json`
   manifests. Adapt it for other package types before use; report unsupported
   release plumbing rather than bypassing the guards.
5. **Dry run, then cut:**
   ```bash
   bash <this-skill-folder>/scripts/publish.sh patch --dry-run
   # After RELEASE PASS and explicit consent covering the release operations:
   bash <this-skill-folder>/scripts/publish.sh patch
   ```
   The script watches the CI run and prints the release link on success.

## If a publish job fails mid-release

Don't re-run `publish.sh` — it bumps a new version. Re-run the failed CI job on the
**existing tag**; the skip-if-exists logic heals the half-published state.
