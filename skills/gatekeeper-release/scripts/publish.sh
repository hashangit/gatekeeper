#!/usr/bin/env bash
# Publish: lockstep version bump (optional core package), tag, and push to trigger
# the tag-triggered release workflow (RELEASE_CI_WORKFLOW).
#
# The workflow then publishes to your registry, optionally your Homebrew tap
# (HOMEBREW_TAP_REPO), and creates a GitHub Release. See PUBLISHING.md for practice.
#
# Agents: invoke only after RELEASE PASS and explicit user consent covering
# version bumps, commits, tags, pushes, and publishing for the target. Never infer
# consent from a receipt or answer the interactive confirmation autonomously.
#
# Usage:
#   ./publish.sh                  # interactive: pick patch/minor/major
#   ./publish.sh patch            # 0.3.0 -> 0.3.1
#   ./publish.sh minor            # 0.3.0 -> 0.4.0
#   ./publish.sh major            # 0.3.0 -> 1.0.0
#   ./publish.sh 1.2.3            # explicit version
#   ./publish.sh patch --dry-run  # show what would happen, change nothing
#
# Requires: git, gh (authenticated), npm (for registry checks), jq
set -euo pipefail

# --- color helpers --------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  CYAN=$'\033[36m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; DIM=""; RESET=""
fi

info()  { printf "${CYAN}ℹ${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}✓${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${RESET}  %s\n" "$*"; }
err()   { printf "${RED}✗${RESET}  %s\n" "$*" >&2; }
die()   { err "$*"; exit 1; }

# --- path setup -----------------------------------------------------------
# The repo being released is the one the user runs from; fall back to the repo
# containing the skill (for the in-repo install layout).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[[ -n "$REPO_ROOT" ]] || die "Not inside a git repository. Run publish.sh from the repo root (or install the skill inside the repo)."
# shellcheck source=../config.sh
source "$SKILL_DIR/config.sh"
cd "$REPO_ROOT"

# --- required configuration ------------------------------------------------
require_var() {
  local name="$1"
  [[ -n "${!name:-}" && "${!name}" != "<set-me>" ]] || { err "config.sh: $name is not set (still '<set-me>' or empty). Fill it in — see references/setup.md."; exit 1; }
}
require_var PACKAGE_NAME
require_var GATE_TEST_CMD
require_var GATE_BUILD_CMD
require_var WORK_ORDER_PATH
require_var REVIEW_FOLDER_PATH
CORE="${CORE_PACKAGE_NAME:-}"

# --- preflight checks -----------------------------------------------------
[[ -f package.json ]] || die "Not in the release repo root: no package.json at $REPO_ROOT"

command -v git >/dev/null || die "git is required"
command -v gh  >/dev/null || die "gh CLI is required (https://cli.github.com)"
command -v jq  >/dev/null || die "jq is required"
gh auth status >/dev/null 2>&1 || die "gh CLI is not authenticated. Run: gh auth login"

PKG_NAME=$(jq -r .name package.json)
[[ "$PKG_NAME" == "$PACKAGE_NAME" ]] || die "config.sh PACKAGE_NAME ('$PACKAGE_NAME') does not match package.json ('$PKG_NAME'). Re-align them."

CURRENT_VERSION=$(jq -r .version package.json)
if [[ -n "$CORE" ]]; then
  CORE_VERSION=$(jq -r .version "$CORE/package.json")
  [[ "$CURRENT_VERSION" == "$CORE_VERSION" ]] || die "Manifests drifted out of lockstep: root=$CURRENT_VERSION core=$CORE_VERSION. Re-align them first (lockstep releases)."
fi
DEFAULT_BRANCH="main"

info "Repo:        $(git remote get-url origin 2>/dev/null || echo "(no origin remote)")"
if [[ -n "$CORE" ]]; then
  info "Packages:    $PKG_NAME + $CORE (lockstep)"
else
  info "Package:     $PKG_NAME"
fi
info "On branch:   $(git rev-parse --abbrev-ref HEAD)"
info "Local ver:   $CURRENT_VERSION"
echo

# --- guard 1: must be on the default branch -------------------------------
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
  die "Must be on '$DEFAULT_BRANCH' (currently on '$CURRENT_BRANCH').
       Merge your feature branch first: git checkout $DEFAULT_BRANCH && git merge $CURRENT_BRANCH"
fi

# --- guard 2: working tree must be clean ----------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
  die "Working tree is dirty. Commit or stash changes first:
       git status
       git stash   # or git commit -am '...'"
fi

# --- guard 3: local default branch must match origin ----------------------
git fetch origin "$DEFAULT_BRANCH" --quiet
LOCAL_MAIN=$(git rev-parse "$DEFAULT_BRANCH")
REMOTE_MAIN=$(git rev-parse "origin/$DEFAULT_BRANCH")
if [[ "$LOCAL_MAIN" != "$REMOTE_MAIN" ]]; then
  die "Local '$DEFAULT_BRANCH' ($LOCAL_MAIN) is out of sync with origin ($REMOTE_MAIN).
       Run: git pull --ff-only   (or git push if local is ahead)"
fi

# --- guard 4: previous release completed ----------------------------------
# A package ABSENT from the registry with a free tag is "ready", not half-finished
# (first-release bootstrap). A half-finished state is diagnosed by NAME.
registry_latest() {
  npm view "$1" version 2>/dev/null || echo ""
}
NPM_LATEST=$(registry_latest "$PKG_NAME")
if [[ -z "$NPM_LATEST" ]]; then
  die "Could not reach npm registry for $PKG_NAME. Check network/VPN."
fi
if [[ "$CURRENT_VERSION" != "$NPM_LATEST" ]]; then
  die "Version mismatch ($PKG_NAME): package.json=$CURRENT_VERSION but registry latest=$NPM_LATEST.
       The previous release did not complete for this package. Either:
         - publish $CURRENT_VERSION manually, OR
         - the publish step in the last release workflow failed (re-run the job on the tag)."
fi
if [[ -n "$CORE" ]]; then
  CORE_LATEST=$(registry_latest "$CORE")
  if [[ -n "$CORE_LATEST" && "$CORE_VERSION" != "$CORE_LATEST" ]]; then
    die "Version mismatch ($CORE): $CORE/package.json=$CORE_VERSION but registry latest=$CORE_LATEST.
         Re-run the release workflow job on the existing tag (skip-if-exists heals the half state)."
  fi
  if [[ -z "$CORE_LATEST" ]]; then
    warn "$CORE is not on the registry yet — first release (bootstrap: absent + free tag = ready)"
  else
    ok "Local $CURRENT_VERSION matches registry latest for both packages (root $NPM_LATEST, core $CORE_LATEST)"
  fi
else
  ok "Local $CURRENT_VERSION matches registry latest ($NPM_LATEST)"
fi

# --- resolve target version ------------------------------------------------
bump_version() {
  # arithmetic bump — npm version MUTATES package.json, which would break
  # dry-run purity
  local maj=$1 min=$2 pat=$3 kind=$4
  case "$kind" in
    patch) echo "$maj.$min.$((pat+1))" ;;
    minor) echo "$maj.$((min+1)).0" ;;
    major) echo "$((maj+1)).0.0" ;;
  esac
}

if [[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  BUMP="$1"; TARGET_VERSION="$BUMP"
elif [[ "${1:-}" == "patch" || "${1:-}" == "minor" || "${1:-}" == "major" ]]; then
  BUMP="$1"
  TARGET_VERSION=$(bump_version "$(echo "$CURRENT_VERSION" | cut -d. -f1)" "$(echo "$CURRENT_VERSION" | cut -d. -f2)" "$(echo "$CURRENT_VERSION" | cut -d. -f3)" "$BUMP")
elif [[ -z "${1:-}" ]]; then
  # no argument -> interactive prompt
  MAJ=$(echo "$CURRENT_VERSION" | cut -d. -f1)
  MIN=$(echo "$CURRENT_VERSION" | cut -d. -f2)
  PAT=$(echo "$CURRENT_VERSION" | cut -d. -f3)
  echo "${BOLD}Current version:${RESET} $CURRENT_VERSION"
  echo "Pick a bump:"
  echo "  ${CYAN}1${RESET}) patch  -> $MAJ.$MIN.$((PAT+1))"
  echo "  ${CYAN}2${RESET}) minor  -> $MAJ.$((MIN+1)).0"
  echo "  ${CYAN}3${RESET}) major  -> $((MAJ+1)).0.0"
  echo "  ${CYAN}q${RESET}) quit"
  read -r -p "Choice [1-3]: " choice </dev/tty
  case "$choice" in
    1) BUMP="patch" ;;
    2) BUMP="minor" ;;
    3) BUMP="major" ;;
    *) die "Aborted." ;;
  esac
  TARGET_VERSION=$(bump_version "$MAJ" "$MIN" "$PAT" "$BUMP")
else
  die "Invalid version argument: '$1'
       Expected: patch | minor | major | <semver> | (nothing for interactive)"
fi

# --- guard 5: target version must not already exist -----------------------
if git rev-parse -q --verify "refs/tags/v$TARGET_VERSION" >/dev/null; then
  die "Tag v$TARGET_VERSION already exists. Pick a higher version."
fi
if npm view "$PKG_NAME@$TARGET_VERSION" version >/dev/null 2>&1; then
  die "$PKG_NAME@$TARGET_VERSION already exists on npm. Pick a higher version."
fi
if [[ -n "$CORE" ]] && npm view "$CORE@$TARGET_VERSION" version >/dev/null 2>&1; then
  die "$CORE@$TARGET_VERSION already exists on npm. Pick a higher version."
fi

echo
echo "${BOLD}${CYAN}Release summary${RESET}"
echo "  ${DIM}from:${RESET} $CURRENT_VERSION"
echo "  ${DIM}to:${RESET}   $TARGET_VERSION"
echo "  ${DIM}bump:${RESET} $BUMP"
echo

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=true ;;
  esac
done
if [[ "$DRY_RUN" == true ]]; then
  info "${BOLD}--dry-run${RESET}: no changes made (manifests byte-identical)."
  info "Would have: bumped package.json$( [[ -n "$CORE" ]] && echo " + $CORE/package.json" ) to $TARGET_VERSION, committed, tagged v$TARGET_VERSION, pushed."
  exit 0
fi

# --- confirm ---------------------------------------------------------------
read -r -p "Publish $TARGET_VERSION? [y/N] " confirm </dev/tty
[[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted."

# --- run the test gate -----------------------------------------------------
info "Running the test gate ($GATE_TEST_CMD)..."
if ! bash -c "$GATE_TEST_CMD" >/tmp/gatekeeper-test.log 2>&1; then
  err "Test gate failed. See /tmp/gatekeeper-test.log"
  tail -20 /tmp/gatekeeper-test.log
  die "Aborting release."
fi
ok "Test gate passed"

# --- execute: bump manifests, generate notes, commit, tag, push -----------
MANIFESTS="package.json"
info "Bumping package.json to $TARGET_VERSION..."
npm version "$TARGET_VERSION" --no-git-tag-version --silent >/dev/null
if [[ -n "$CORE" ]]; then
  info "Bumping $CORE/package.json to $TARGET_VERSION (lockstep)..."
  (cd "$CORE" && npm version "$TARGET_VERSION" --no-git-tag-version --silent >/dev/null)
  MANIFESTS="$MANIFESTS $CORE/package.json"
fi

# --- generate release notes ------------------------------------------------
NOTES_FILE="RELEASE_NOTES-v$TARGET_VERSION.md"
info "Generating release notes..."
NOTES_OK=false
if [[ -n "${RELEASE_NOTES_CMD:-}" ]]; then
  if bash -c "$RELEASE_NOTES_CMD" "$TARGET_VERSION"; then NOTES_OK=true; fi
elif command -v node >/dev/null; then
  if node "$SKILL_DIR/scripts/generate-release-notes.mjs" "$TARGET_VERSION"; then NOTES_OK=true; fi
else
  warn "node not found — cannot run the bundled notes generator."
fi
if [[ "$NOTES_OK" == true && -f "$NOTES_FILE" ]]; then
  ok "Generated $NOTES_FILE"
  echo
  echo "${DIM}--- preview ---${RESET}"
  head -20 "$NOTES_FILE" | sed 's/^/  /'
  echo "${DIM}--- end preview ---${RESET}"
  echo
  read -r -p "Edit $NOTES_FILE before publishing? [y/N] " edit_notes </dev/tty
  if [[ "$edit_notes" =~ ^[Yy]$ ]]; then
    ${EDITOR:-vi} "$NOTES_FILE"
  fi
else
  warn "Release notes not generated. The GitHub Release will use notes from CHANGELOG.md or auto-generated ones."
fi

info "Committing..."
git add $MANIFESTS
[[ -f "$NOTES_FILE" ]] && git add "$NOTES_FILE"
git commit -m "chore(release): v$TARGET_VERSION" --quiet

info "Tagging v$TARGET_VERSION..."
git tag "v$TARGET_VERSION"

info "Pushing commit + tag to origin..."
git push origin "$DEFAULT_BRANCH" --quiet
git push origin "v$TARGET_VERSION" --quiet
ok "Pushed. CI ($RELEASE_CI_WORKFLOW) will now publish."

# --- watch the workflow ----------------------------------------------------
echo
info "Watching $RELEASE_CI_WORKFLOW (Ctrl-C to stop watching; the release continues)..."
sleep 3  # let the workflow register
if gh run list --workflow="$RELEASE_CI_WORKFLOW" --limit=1 --json databaseId,status -q '.[0].databaseId' \
    | xargs -I{} gh run watch {} --exit-status; then
  ok "${BOLD}Release workflow succeeded.${RESET}"
  echo
  echo "  ${DIM}release:${RESET}  $(gh repo view --json url -q .url)/releases/tag/v$TARGET_VERSION"
  if [[ -n "${HOMEBREW_TAP_REPO:-}" ]]; then
    echo "  ${DIM}tap:${RESET}      https://github.com/$HOMEBREW_TAP_REPO/commits/main"
  fi
  exit 0
else
  err "${BOLD}Release workflow FAILED.${RESET} Investigate:"
  echo "  gh run list --workflow=$RELEASE_CI_WORKFLOW --limit=1"
  echo
  echo "  ${DIM}Note:${RESET} re-run the failed job on the EXISTING tag (skip-if-exists heals"
  echo "  the half state). Do NOT re-run this script — it bumps a new version."
  exit 1
fi
