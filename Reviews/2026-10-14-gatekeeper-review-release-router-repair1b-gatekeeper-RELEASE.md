Mode: RELEASE
Scope: gatekeeper-review-release-router | Base: `3bfc6aeb3e2cdb389d6de8616d870ea865054add`
Branch: main | Seal: `03dbe96b2967b1d1438392e4a748f3db8dcfb124` | Gates: suite 5/5, probes N/A, examples N/A, build 1/1, CI run N/A
Fleet: Red Team, Code Reviewer, Security Reviewer, Scrutinizer, Repo Auditor, Ponytail Reviewer, Architect | Skipped: none
Task truth: 8 TRUE / 0 PARTIAL / 1 FALSE
Findings: P0:0 P1:3 P2:7 (10 verified; one stale-public-HEAD report refuted)
Verdict: FAIL

# Gatekeeper Release review

## Phase 0 — deterministic checks

Configuration was read from `skills/gatekeeper/config.sh`. The pinned validator was available after prepending `/Users/hash/Developer/personal/gatekeeper/.venv/bin` to `PATH`.

`GATE_TEST_CMD` exited 0:

```text
Release safety checks passed.
Standalone skill bundles are current.
All three isolated installations have complete links and matching configuration.
Valid skill: skills/gatekeeper
Valid skill: skills/gatekeeper-review
Valid skill: skills/gatekeeper-release
```

`GATE_BUILD_CMD` exited 0:

```text
Standalone skill bundles are current.
```

The configured probe and example commands are empty, so both are N/A. Release CI was not run; this review did not publish or push a release.

## Phase 1 — seal

Reviewed only committed HEAD `03dbe96b2967b1d1438392e4a748f3db8dcfb124`, based on `origin/main` at `3bfc6aeb3e2cdb389d6de8616d870ea865054add`. The branch was `main`, ahead of `origin/main` by three commits. The candidate worktree was clean at gate start. HEAD remained at the seal throughout review; this receipt is the only review artifact added afterward.

## Phase 2 — task truth

| # | Result | Evidence |
|---|---|---|
| 1 | TRUE | `scripts/check-skills.py` validates all three isolated bundles. |
| 2 | TRUE | The seven reviewer mandates are present in canonical and generated skills; all three `skills-ref validate` checks pass. |
| 3 | TRUE | The router and both standalone entrypoints describe explicit Release consent; configured skill checks pass. |
| 4 | TRUE | The release workflow checks bundle drift, metadata, syntax, and tag/plugin version equality. |
| 5 | TRUE | `RELEASE_PROCESS.md` documents the configured values and README links to it. |
| 6 | FALSE | The direct canonical-reference read follows a symlink outside the source tree; a hostile Git-valid tag also reaches Git option parsing in release-notes generation. See Phase 4. |
| 7 | TRUE | The publisher checks Mode, Verdict, and matching current seal, runs both configured gates, and stages the receipt with the release commit. The receipt schema mismatch with CI is recorded separately as P2. |
| 8 | TRUE | The workflow separates read-only validation from the write-enabled release job, with pinned actions and a receipt-parent check. |
| 9 | TRUE | Repository configuration matches the workflow values, and `RELEASE_PROCESS.md` records the pinned validator setup. |

## Phase 3 — fresh reviewer fleet

All seven enabled reviewers ran in fresh contexts against this seal and the specified base.

- **Red Team** reported the arithmetic command execution, Git tag option injection, and reference-symlink bypass.
- **Code Reviewer** reported those release-tool defects, the unstaged npm lockfile, and conflicting release instructions.
- **Security Reviewer** corroborated the command and tag risks, and identified the mutable-tag write-job gap and missing untrusted-brief boundary.
- **Scrutinizer** found the missing workflow-template source in the standalone first-install bundle and release-document inconsistencies. Its observation that the README's public `npx` install resolved to pre-candidate public HEAD was refuted as a defect in this sealed tree.
- **Repo Auditor** found the documented existing-tag retry does not match the workflow's unconditional release creation; it found no configuration drift relevant to this gate.
- **Ponytail Reviewer** reported no unnecessary implementation to cut.
- **Architect**, dispatched after Phase 4 verification, judged the release trust chain and confirmed the three P1 issues below as verdict-changing.

## Phase 4 — first-hand verification

All dynamic reproductions ran in isolated temporary repositories/copies. No source, tests, work-order lines, version, tag, or remote were changed in the sealed worktree.

1. **P1 — canonical reference symlink bypass; reproduced.** In an archived temporary copy, replaced `skills/gatekeeper/references/review.md` with a symlink to an outside file containing `GATEKEEPER_OUTSIDE_SENTINEL`. `python3 scripts/sync-skills.py` exited 0 and the sentinel appeared in generated `skills/gatekeeper-review/SKILL.md`. `files_under()` checks symlinks at `scripts/sync-skills.py:19-29`, but `expected_files()` reads the reference directly at lines 32-41. This disproves work-order task 6's symlink-rejection claim.

2. **P1 — Git option injection through a tag; reproduced.** In a temporary repository, `git check-ref-format refs/tags/--output=<temp>/git-log-output` exited 0. After setting that tag, `git describe --tags --abbrev=0 HEAD~1` returned `--output=<temp>/git-log-output`. Running `node skills/gatekeeper/scripts/generate-release-notes.mjs 2.0.0` exited 0 and Git created the outside path `<temp>/git-log-output..HEAD` with the commit subjects. The tag is passed as the range argument at `skills/gatekeeper/scripts/generate-release-notes.mjs:36-46`; one argv element avoids shell parsing but not Git option parsing.

3. **P1 — command execution through malformed manifest version; reproduced.** In a temporary repo with a local bare origin and fake `gh`, set the plugin version to `1.BASH_VERSINFO[$(touch <temp-marker>)].0`, then ran `skills/gatekeeper/scripts/publish.sh minor --dry-run`. It exited 0, created the marker, calculated target `1.6.0`, and left HEAD unchanged. The version fields reach Bash arithmetic through `bump_version` at `skills/gatekeeper/scripts/publish.sh:206-221`. No real bump, commit, tag, or push occurred.

4. **P2 — publisher/CI receipt contract mismatch; reproduced.** In an isolated temporary repo, a receipt containing only `Mode: RELEASE`, a standalone matching `Seal: 03dbe96b2967b1d1438392e4a748f3db8dcfb124`, and `Verdict: PASS` was accepted by `publish.sh 1.0.1 --dry-run` (exit 0). The workflow's structured-header expression at `.github/workflows/release.yml:72-73` did not match it. Thus the publisher can pass its receipt preflight for a receipt CI rejects. Only a dry run was performed; no release mutation occurred.

5. **P2 — npm lockfile omitted from release commit; reproduced.** In an isolated package repo, `npm version 1.0.1 --no-git-tag-version --silent` changed both `package.json` and `package-lock.json`. The publisher stages only `package.json` (and optional core `package.json`) at `skills/gatekeeper/scripts/publish.sh:327-349`; the lockfile remained modified but unstaged.

6. **P2 — tag-to-SHA race in release workflow; statically confirmed, impact conditional on tag mutability.** The write job checks out `github.sha` but invokes `gh release create` using the mutable event tag and never compares that tag's resolved commit with the validated SHA (`.github/workflows/release.yml:90-101`). Repository tag-protection settings were not inspected.

7. **P2 — reviewer brief trust boundary is unspecified.** `skills/gatekeeper/steps/phase-3-fleet.md:3-8` sends work-order/spec text to reviewers without saying to treat it as untrusted data. No reviewer-directed injection exists in the current work order or spec; this is a design gap, not an observed exploit.

8. **P2 — standalone first-install workflow source is missing.** `skills/gatekeeper-release/FIRST_INSTALL.md:28-32` tells users to copy `.github/workflows/release.yml`, but the generated standalone bundle does not include that workflow or name a source for it.

9. **P2 — release procedures conflict.** `RELEASE_PROCESS.md:50-59` tells maintainers to update, commit, tag, and push the release change; `skills/gatekeeper/PUBLISHING.md:28-32` says `publish.sh` creates that release commit and says not to hand-roll it.

10. **P2 — documented tag retry is not idempotent.** `RELEASE_PROCESS.md:61-63` recommends rerunning the existing tag workflow, while `.github/workflows/release.yml:95-101` unconditionally runs `gh release create`; a rerun after a Release exists can fail.

The public `npx` result was stale pre-release content, not a defect in this sealed candidate, and is excluded from the finding counts. The two especially requested paths are both present in this seal: the minimal-receipt acceptance mismatch and the direct reference-symlink bypass were reproduced independently against temporary copies of the sealed candidate.

## Phase 5 — verdict and scope

The computed verdict is **FAIL** because three confirmed P1 findings exist and task-truth row 6 is FALSE. No unresolved material conflict blocks the verdict.

Release consent scope for this run: verification and this receipt only. No version bump, release commit/tag, push, publishing, or CI retry was authorized or performed.
