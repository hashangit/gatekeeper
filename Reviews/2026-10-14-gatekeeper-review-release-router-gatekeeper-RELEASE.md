# Gatekeeper Release verification

Mode: RELEASE  
Scope: gatekeeper-review-release-router | Base: `3bfc6aeb3e2cdb389d6de8616d870ea865054add` (`HEAD^`, `origin/main`)  
Branch: `main` | Seal: `7137175c7b657c779c7f8ce6bc857bc8f5e04b66` | Gates: suite PASS (no count emitted), probes N/A, examples N/A, build PASS, CI run N/A  
Fleet: Red Team, Code Reviewer, Security Reviewer, Scrutinizer, Repo Auditor, Ponytail Reviewer, Architect | Skipped: none  
Task truth: 5 TRUE / 0 PARTIAL / 0 FALSE  
Findings: P0:0 P1:2 P2:9 confirmed, 0 refuted  
Verdict: FAIL

Consent scope for this run: Release verification and this receipt only. This reviewer was not authorized to bump versions, create a release commit or tag, push, publish, or retry release CI.

## Phase 0 outputs

Candidate was clean at Phase 0 and remained clean after checks. `HEAD` matched the requested seal. The commands ran with `PATH=/tmp/gatekeeper-skill-validation-20261014/bin:$PATH`.

`GATE_TEST_CMD`:

```text
python3 scripts/check-skills.py && skills-ref validate skills/gatekeeper && skills-ref validate skills/gatekeeper-review && skills-ref validate skills/gatekeeper-release
```

Exit: 0

```text
Standalone skill bundles are current.
All three isolated installations have complete links and matching configuration.
Valid skill: skills/gatekeeper
Valid skill: skills/gatekeeper-review
Valid skill: skills/gatekeeper-release
```

`GATE_BUILD_CMD`:

```text
python3 scripts/sync-skills.py --check
```

Exit: 0

```text
Standalone skill bundles are current.
```

`GATE_PROBES_CMD` and `GATE_EXAMPLES_CMD` are empty, so they were N/A. No tag was pushed and no GitHub Actions run was started; CI is N/A.

## Task truth

1. TRUE — All three bundles passed `scripts/check-skills.py` and `skills-ref validate`; see Phase 0 output.
2. TRUE — The seven files under `skills/gatekeeper/reviewers/` exist and are byte-identical to the original `reviewers/` files at the base. `sync-skills.py --check` passed, and all three skill validations passed.
3. TRUE — The router and Review/Release entrypoints state the explicit Release consent boundary; `scripts/check-skills.py` passed.
4. TRUE — `.github/workflows/release.yml` checks bundle drift, Agent Skills metadata, publisher/generator syntax, and plugin-version/tag equality.
5. TRUE — `RELEASE_PROCESS.md` lists all configured values, and `README.md:133-134` links to it.

## Confirmed findings

### P1 — Git tag can execute shell commands during release-note generation

`skills/gatekeeper/scripts/generate-release-notes.mjs:31-43` places `prevTag`, obtained from `git describe`, directly into a string passed to `execSync`. In an isolated temporary repository, `git check-ref-format` accepted `v1.0.0$(touch${IFS}<marker>)`; running the sealed generator created the marker before `git log` failed. The same generator is bundled for Release, and `skills/gatekeeper/scripts/publish.sh:246` invokes it during a release. This permits command execution as the user running the documented release flow. Code Reviewer, Security Reviewer, Red Team, and Gatekeeper reproduced or independently verified this issue.

### P1 — Bundle generation follows source symlinks and copies outside files

`scripts/sync-skills.py:19,32-34` treats symlinks to files as files and reads their targets without checking containment. In a temporary archive of the seal, Gatekeeper added a symlink from the canonical source tree to an outside temporary file and ran the sealed script. It exited 0 and copied that payload into `skills/gatekeeper-review/resources/`. A malicious source symlink can disclose a maintainer's local file through the generated distributable bundle. Red Team and Gatekeeper reproduced this. Security Reviewer rated the same confirmed behavior Medium; it is classified P1 here because the copied file can contain local credentials or other secrets.

### P2 — Release mutation paths do not enforce all gate prerequisites

`skills/gatekeeper/config.sh:21-25` says the test and build gates run through `publish.sh`. The publisher requires `GATE_BUILD_CMD` at line 58 but executes only `GATE_TEST_CMD` at lines 220-227 before version, commit, tag, and push mutations at lines 231-275. It also does not require a Release PASS receipt. Phase 5 says “No receipt, no push” (`skills/gatekeeper/steps/phase-5-verdict-and-receipt.md:38-39`), while `.github/workflows/release.yml:3-9,40-45` creates a release for a `v*` tag without checking a receipt. The Architect confirmed the end-to-end contract gap.

### P2 — Publisher can watch a different Actions run

`skills/gatekeeper/scripts/publish.sh:282-283` selects only the latest run for the workflow and watches that run ID. It does not match the run to the tag or commit just pushed, so a delayed or concurrent run can produce the wrong release status.

### P2 — Custom release-notes command receives the version as `$0`

`skills/gatekeeper/scripts/publish.sh:243-244` invokes `bash -c "$RELEASE_NOTES_CMD" "$TARGET_VERSION"`. The direct probe returned `arg0=<1.2.3> arg1=<>`; a custom command expecting the version in `$1` receives an empty value. The publisher can continue after failing to create notes, while the release workflow requires `RELEASE_NOTES-${RELEASE_TAG}.md`.

### P2 — Tag-triggered workflow runs tag-controlled code with write permission

`.github/workflows/release.yml:3-9,15-44` starts for any `v*` tag, grants `contents: write`, checks out that tag, and runs repository scripts before comparing the tag to the plugin version. GitHub tag protections were not accessible in this local review, so the exposure is conditional on who can create matching tags and the repository's tag rules.

### P2 — Release workflow uses mutable action references

The write-capable workflow references `actions/checkout@v4`, `actions/setup-python@v5`, and `actions/setup-node@v4` (`.github/workflows/release.yml:15,18,21`) rather than immutable commit SHAs.

### P2 — Test output redirection follows a predictable `/tmp` path

`skills/gatekeeper/scripts/publish.sh:222` redirects output to `/tmp/gatekeeper-test.log`. A local symlink at that path can cause truncation or overwrite of another file writable by the publisher user; test output may also be exposed to other local users.

### P2 — Publisher prints the full origin URL

`skills/gatekeeper/scripts/publish.sh:81` prints `git remote get-url origin` without redacting credentials. A remote URL that embeds credentials would expose them in captured terminal or CI output.

### P2 — Release setup omits the `skills-ref` installation step

`RELEASE_PROCESS.md:20` requires `skills-ref` in the configured test gate, but README, setup, FIRST_INSTALL, and PUBLISHING docs do not explain how to install it. Scrutinizer reproduced `command not found` in its fresh environment. The configured Phase 0 gate passed here because the requested PATH supplied the validator; this is a setup documentation gap, not a Phase 0 failure.

### P2 — One duplicate syntax check can be removed

Ponytail identified `.github/workflows/validate-skills.yml:29` as a redundant `bash -n` check for the generated release publisher: `check-skills.py` checks bundle equality, and the canonical publisher is already syntax-checked on line 28. One line is removable (`net: -1 line possible`). This is an over-engineering finding only.

## Reviewer coverage and limitations

- Red Team confirmed the tag-injection and symlink-copy issues with probes. Its ambiguous-router and Review-only installation attacks survived.
- Code Reviewer attempted `coderabbit review --agent --base-commit 3bfc6aeb3e2cdb389d6de8616d870ea865054add -t committed`; CodeRabbit failed to start after its free-allowance setup. The reviewer completed a manual review. `skills-ref` and `actionlint` were unavailable in that reviewer's PATH; the gatekeeper ran the configured validator through the supplied PATH.
- Security Reviewer found no package manifest or lockfile, so `npm audit` did not apply. `pip-audit`, `osv-scanner`, `cargo-audit`, `skills-ref`, `semgrep`, and `shellcheck` were unavailable to that reviewer. Its tracked-file secret-pattern scan found no matches; the externally installed `skills-ref` dependency tree was not independently audited.
- Scrutinizer installed all three skills and Review alone from the sealed local source, and manual copy and local links worked. Its README command against the current public branch fetched the pre-candidate source; that remote lag was treated as a pre-release mismatch, not a sealed-tree defect. Claude Code UI was unavailable.
- Repo Auditor found no cross-layer drift or orphan finding.
- Ponytail found only the one redundant syntax-check line above.
- Architect confirmed the receipt-enforcement gap and found no contradiction that changes the verdict.

No reviewer modified the sealed implementation. Scrutinizer briefly created an untracked local install while executing a README command from the repository root, removed it immediately, and confirmed the working tree was clean. Gatekeeper rechecked `git status --porcelain` and `HEAD` after that cleanup.

## Verdict

FAIL. Two confirmed P1 findings trigger the computed verdict rule. Task truth is 5 TRUE / 0 PARTIAL / 0 FALSE. No repairs were attempted; the repair limit remains 0 of 2. The candidate remains sealed at `7137175c7b657c779c7f8ce6bc857bc8f5e04b66`.
