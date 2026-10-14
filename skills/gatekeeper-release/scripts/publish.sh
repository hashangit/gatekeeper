#!/usr/bin/env bash
# Publish: lockstep version bump (optional core package), tag, and push to trigger
# the tag-triggered release workflow (RELEASE_CI_WORKFLOW).
#
# The workflow can publish configured registries or taps and create a GitHub
# Release. See PUBLISHING.md for practice.
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
# Requires: git, gh (authenticated), jq; npm is needed for registry packages.
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
REPO_ROOT=$(cd "$REPO_ROOT" && pwd -P)
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
command -v git >/dev/null || die "git is required"
command -v gh  >/dev/null || die "gh CLI is required (https://cli.github.com)"
command -v jq  >/dev/null || die "jq is required"
gh auth status >/dev/null 2>&1 || die "gh CLI is not authenticated. Run: gh auth login"

PACKAGE_KIND=""
PACKAGE_MANIFEST=""
if [[ -f package.json ]]; then
  PACKAGE_KIND="npm"
  PACKAGE_MANIFEST="package.json"
elif [[ -f .claude-plugin/plugin.json ]]; then
  PACKAGE_KIND="claude-plugin"
  PACKAGE_MANIFEST=".claude-plugin/plugin.json"
else
  die "No supported package manifest found (expected package.json or .claude-plugin/plugin.json)."
fi

PKG_NAME=$(jq -r .name "$PACKAGE_MANIFEST")
[[ "$PKG_NAME" == "$PACKAGE_NAME" ]] || die "config.sh PACKAGE_NAME ('$PACKAGE_NAME') does not match $PACKAGE_MANIFEST name ('$PKG_NAME'). Re-align them."

CURRENT_VERSION=$(jq -r .version "$PACKAGE_MANIFEST")
SEMVER_REGEX='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
[[ "$CURRENT_VERSION" =~ $SEMVER_REGEX ]] || die "$PACKAGE_MANIFEST has an invalid semver version: '$CURRENT_VERSION'."
if [[ -n "$CORE" ]]; then
  [[ "$PACKAGE_KIND" == "npm" ]] || die "CORE_PACKAGE_NAME is supported only for npm package releases."
  CORE_VERSION=$(jq -r .version "$CORE/package.json")
  [[ "$CURRENT_VERSION" == "$CORE_VERSION" ]] || die "Manifests drifted out of lockstep: root=$CURRENT_VERSION core=$CORE_VERSION. Re-align them first (lockstep releases)."
fi
if [[ "$PACKAGE_KIND" == "npm" ]]; then
  command -v npm >/dev/null || die "npm is required for registry package releases"
fi
DEFAULT_BRANCH="main"

if git remote get-url origin >/dev/null 2>&1; then
  info "Origin:      configured"
else
  info "Origin:      not configured"
fi
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

# --- guard 2: require the current RELEASE PASS receipt --------------------
CURRENT_HEAD=$(git rev-parse HEAD)
if [[ "$REVIEW_FOLDER_PATH" = /* ]]; then
  REVIEW_DIR_INPUT="$REVIEW_FOLDER_PATH"
else
  REVIEW_DIR_INPUT="$REPO_ROOT/$REVIEW_FOLDER_PATH"
fi
[[ -d "$REVIEW_DIR_INPUT" ]] || die "Review receipt folder does not exist: $REVIEW_FOLDER_PATH"
REVIEW_DIR=$(cd "$REVIEW_DIR_INPUT" && pwd -P)
RELEASE_RECEIPT=""
receipt_matches=0
while IFS= read -r -d '' candidate; do
  [[ -f "$candidate" && ! -L "$candidate" ]] || continue
  [[ "$(grep -Ec '^Mode: RELEASE[[:space:]]*$' "$candidate" || true)" == "1" ]] || continue
  [[ "$(grep -Ec '^Verdict: PASS[[:space:]]*$' "$candidate" || true)" == "1" ]] || continue
  [[ "$(grep -Ec '^Branch: [^|]+ \| Seal: `?[[:xdigit:]]{40,64}`? \| Gates: .+$' "$candidate" || true)" == "1" ]] || continue
  candidate_seal=$(sed -nE 's/^Branch: [^|]+ \| Seal: `?([[:xdigit:]]{40,64})`? \| Gates: .+$/\1/p' "$candidate" | head -1)
  [[ "$candidate_seal" == "$CURRENT_HEAD" ]] || continue
  RELEASE_RECEIPT="$candidate"
  receipt_matches=$((receipt_matches + 1))
done < <(find "$REVIEW_DIR" -type f -name '*-gatekeeper-RELEASE.md' -print0)
[[ "$receipt_matches" -eq 1 ]] || die "Expected exactly one RELEASE PASS receipt sealed to $CURRENT_HEAD in $REVIEW_DIR; found $receipt_matches. Run Gatekeeper Release first."

RELEASE_RECEIPT_REL=""
case "$REVIEW_DIR/" in
  "$REPO_ROOT/"*) RELEASE_RECEIPT_REL="${RELEASE_RECEIPT#"$REPO_ROOT/"}" ;;
esac

check_only_receipt_change() {
  local entry status path
  while IFS= read -r -d '' entry; do
    status="${entry:0:2}"
    path="${entry:3}"
    if [[ -n "$RELEASE_RECEIPT_REL" && "$status" == "??" && "$path" == "$RELEASE_RECEIPT_REL" ]]; then
      continue
    fi
    die "Working tree has changes beyond the current RELEASE receipt. Commit or remove them before releasing: $path"
  done < <(git status --porcelain=v1 --untracked-files=all -z)
}
check_only_receipt_change

# --- guard 3: local default branch must match origin ----------------------
git fetch origin "$DEFAULT_BRANCH" --quiet
LOCAL_MAIN=$(git rev-parse "$DEFAULT_BRANCH")
REMOTE_MAIN=$(git rev-parse "origin/$DEFAULT_BRANCH")
if [[ "$LOCAL_MAIN" != "$REMOTE_MAIN" ]]; then
  die "Local '$DEFAULT_BRANCH' ($LOCAL_MAIN) is out of sync with origin ($REMOTE_MAIN).
       Run: git pull --ff-only   (or git push if local is ahead)"
fi

# --- guard 4: previous release completed ----------------------------------
if [[ "$PACKAGE_KIND" == "npm" ]]; then
  registry_latest() {
    npm view "$1" version 2>/dev/null || echo ""
  }
  NPM_LATEST=$(registry_latest "$PKG_NAME")
  if [[ -z "$NPM_LATEST" ]]; then
    die "Could not reach npm registry for $PKG_NAME. Check network/VPN."
  fi
  if [[ "$CURRENT_VERSION" != "$NPM_LATEST" ]]; then
    die "Version mismatch ($PKG_NAME): package.json=$CURRENT_VERSION but registry latest=$NPM_LATEST. The previous release did not complete."
  fi
  if [[ -n "$CORE" ]]; then
    CORE_LATEST=$(registry_latest "$CORE")
    if [[ -n "$CORE_LATEST" && "$CORE_VERSION" != "$CORE_LATEST" ]]; then
      die "Version mismatch ($CORE): $CORE/package.json=$CORE_VERSION but registry latest=$CORE_LATEST."
    fi
    if [[ -z "$CORE_LATEST" ]]; then
      warn "$CORE is not on the registry yet — first release (bootstrap: absent + free tag = ready)"
    else
      ok "Local $CURRENT_VERSION matches registry latest for both packages (root $NPM_LATEST, core $CORE_LATEST)"
    fi
  else
    ok "Local $CURRENT_VERSION matches registry latest ($NPM_LATEST)"
  fi
else
  CURRENT_TAG="v$CURRENT_VERSION"
  if git rev-parse -q --verify "refs/tags/$CURRENT_TAG" >/dev/null; then
    gh release view "$CURRENT_TAG" >/dev/null 2>&1 || die "Tag $CURRENT_TAG exists without a GitHub Release. Repair that release before cutting another version."
    ok "Previous GitHub Release $CURRENT_TAG is complete"
  else
    warn "No previous tag for $PKG_NAME $CURRENT_VERSION — treating this as the first release."
  fi
fi

# --- guard 5: receipt is the only allowed post-seal change ----------------
if [[ "$(git rev-parse HEAD)" != "$CURRENT_HEAD" ]]; then
  die "HEAD changed after the RELEASE receipt was sealed. Restart the Release gate."
fi

# --- resolve target version ------------------------------------------------
bump_version() {
  local version=$1 kind=$2 maj min pat
  IFS=. read -r maj min pat <<< "$version"
  case "$kind" in
    patch) printf '%s.%s.%s\n' "$maj" "$min" "$(increment_decimal "$pat")" ;;
    minor) printf '%s.%s.0\n' "$maj" "$(increment_decimal "$min")" ;;
    major) printf '%s.0.0\n' "$(increment_decimal "$maj")" ;;
  esac
}

increment_decimal() {
  local value=$1 result="" digit index carry=1
  for ((index=${#value}-1; index>=0; index--)); do
    digit=${value:index:1}
    if ((carry)); then
      if [[ "$digit" == "9" ]]; then
        digit="0"
      else
        digit=$((10#$digit + 1))
        carry=0
      fi
    fi
    result="$digit$result"
  done
  if ((carry)); then result="1$result"; fi
  printf '%s\n' "$result"
}

if [[ "${1:-}" =~ $SEMVER_REGEX ]]; then
  BUMP="$1"; TARGET_VERSION="$BUMP"
elif [[ "${1:-}" == "patch" || "${1:-}" == "minor" || "${1:-}" == "major" ]]; then
  BUMP="$1"
  TARGET_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP")
elif [[ -z "${1:-}" ]]; then
  # no argument -> interactive prompt
  PATCH_TARGET=$(bump_version "$CURRENT_VERSION" patch)
  MINOR_TARGET=$(bump_version "$CURRENT_VERSION" minor)
  MAJOR_TARGET=$(bump_version "$CURRENT_VERSION" major)
  echo "${BOLD}Current version:${RESET} $CURRENT_VERSION"
  echo "Pick a bump:"
  echo "  ${CYAN}1${RESET}) patch  -> $PATCH_TARGET"
  echo "  ${CYAN}2${RESET}) minor  -> $MINOR_TARGET"
  echo "  ${CYAN}3${RESET}) major  -> $MAJOR_TARGET"
  echo "  ${CYAN}q${RESET}) quit"
  read -r -p "Choice [1-3]: " choice </dev/tty
  case "$choice" in
    1) BUMP="patch" ;;
    2) BUMP="minor" ;;
    3) BUMP="major" ;;
    *) die "Aborted." ;;
  esac
  TARGET_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP")
else
  die "Invalid version argument: '$1'
       Expected: patch | minor | major | <semver> | (nothing for interactive)"
fi
[[ "$TARGET_VERSION" =~ $SEMVER_REGEX ]] || die "Invalid target version: '$TARGET_VERSION'."

# --- guard 5: target version must not already exist -----------------------
if git rev-parse -q --verify "refs/tags/v$TARGET_VERSION" >/dev/null; then
  die "Tag v$TARGET_VERSION already exists. Pick a higher version."
fi
if [[ "$PACKAGE_KIND" == "npm" ]] && npm view "$PKG_NAME@$TARGET_VERSION" version >/dev/null 2>&1; then
  die "$PKG_NAME@$TARGET_VERSION already exists on npm. Pick a higher version."
fi
if [[ -n "$CORE" && "$PACKAGE_KIND" == "npm" ]] && npm view "$CORE@$TARGET_VERSION" version >/dev/null 2>&1; then
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
  info "Would have: bumped $PACKAGE_MANIFEST$( [[ -n "$CORE" ]] && echo " + $CORE/package.json" ) to $TARGET_VERSION, committed, tagged v$TARGET_VERSION, pushed."
  exit 0
fi

# --- confirm ---------------------------------------------------------------
read -r -p "Publish $TARGET_VERSION? [y/N] " confirm </dev/tty
[[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted."

# --- run all configured gates before mutation -----------------------------
GATE_LOG=$(mktemp "${TMPDIR:-/tmp}/gatekeeper-gates.XXXXXX") || die "Could not create a private gate log."
trap 'rm -f "$GATE_LOG"' EXIT
info "Running the test gate ($GATE_TEST_CMD)..."
if ! bash -c "$GATE_TEST_CMD" >"$GATE_LOG" 2>&1; then
  err "Test gate failed. Output is in $GATE_LOG"
  tail -20 "$GATE_LOG"
  die "Aborting release."
fi
ok "Test gate passed"
info "Running the build gate ($GATE_BUILD_CMD)..."
if ! bash -c "$GATE_BUILD_CMD" >>"$GATE_LOG" 2>&1; then
  err "Build gate failed. Output is in $GATE_LOG"
  tail -20 "$GATE_LOG"
  die "Aborting release."
fi
ok "Build gate passed"
check_only_receipt_change
[[ "$(git rev-parse HEAD)" == "$CURRENT_HEAD" ]] || die "HEAD changed while the gates ran. Restart the Release gate."

# --- generate notes before changing the manifest --------------------------
NOTES_FILE="RELEASE_NOTES-v$TARGET_VERSION.md"
[[ ! -e "$NOTES_FILE" && ! -L "$NOTES_FILE" ]] || die "$NOTES_FILE already exists; inspect it before continuing."
info "Generating release notes..."
NOTES_OK=false
if [[ -n "${RELEASE_NOTES_CMD:-}" ]]; then
  if bash -c "$RELEASE_NOTES_CMD" _ "$TARGET_VERSION"; then NOTES_OK=true; fi
elif command -v node >/dev/null; then
  if node "$SKILL_DIR/scripts/generate-release-notes.mjs" "$TARGET_VERSION"; then NOTES_OK=true; fi
fi
if [[ "$NOTES_OK" != true || ! -s "$NOTES_FILE" ]]; then
  die "Release notes were not generated at $NOTES_FILE; no manifest change, release commit, or tag was created."
fi
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

is_release_path() {
  local changed_path=$1 allowed_path
  shift
  for allowed_path in "$@"; do
    [[ "$changed_path" == "$allowed_path" ]] && return 0
  done
  return 1
}

check_release_changes() {
  local entry path
  [[ "$(git rev-parse HEAD)" == "$CURRENT_HEAD" ]] || die "HEAD changed after review. Restart the Release gate."
  while IFS= read -r -d '' entry; do
    path="${entry:3}"
    is_release_path "$path" "$@" || die "Unreviewed change during release: $path. No release tag or push was created."
  done < <(git status --porcelain=v1 --untracked-files=all -z)
}

RELEASE_PATHS=("$NOTES_FILE")
[[ -z "$RELEASE_RECEIPT_REL" ]] || RELEASE_PATHS+=("$RELEASE_RECEIPT_REL")
check_release_changes "${RELEASE_PATHS[@]}"
[[ -f "$NOTES_FILE" && ! -L "$NOTES_FILE" && -s "$NOTES_FILE" ]] || die "Release notes must remain a nonempty regular file."

# --- bump manifest, commit, tag, and push ---------------------------------
MANIFESTS=("$PACKAGE_MANIFEST")
info "Bumping $PACKAGE_MANIFEST to $TARGET_VERSION..."
if [[ "$PACKAGE_KIND" == "npm" ]]; then
  npm version "$TARGET_VERSION" --no-git-tag-version --silent >/dev/null
  for lockfile in package-lock.json npm-shrinkwrap.json; do
    [[ -f "$lockfile" ]] && MANIFESTS+=("$lockfile")
  done
  if [[ -n "$CORE" ]]; then
    info "Bumping $CORE/package.json to $TARGET_VERSION (lockstep)..."
    (cd "$CORE" && npm version "$TARGET_VERSION" --no-git-tag-version --silent >/dev/null)
    MANIFESTS+=("$CORE/package.json")
    for lockfile in package-lock.json npm-shrinkwrap.json; do
      [[ -f "$CORE/$lockfile" ]] && MANIFESTS+=("$CORE/$lockfile")
    done
  fi
else
  manifest_tmp=$(mktemp "${PACKAGE_MANIFEST}.XXXXXX") || die "Could not create a temporary plugin manifest."
  cp -p "$PACKAGE_MANIFEST" "$manifest_tmp"
  if ! jq --arg version "$TARGET_VERSION" '.version = $version' "$PACKAGE_MANIFEST" >"$manifest_tmp"; then
    rm -f "$manifest_tmp"
    die "Could not update $PACKAGE_MANIFEST"
  fi
  mv "$manifest_tmp" "$PACKAGE_MANIFEST"
fi

RELEASE_PATHS+=("${MANIFESTS[@]}")
check_release_changes "${RELEASE_PATHS[@]}"
info "Committing..."
git add -- "${MANIFESTS[@]}"
if [[ -n "$RELEASE_RECEIPT_REL" ]]; then
  git add -f -- "$RELEASE_RECEIPT_REL"
fi
git add -- "$NOTES_FILE"
git commit --only -m "chore(release): v$TARGET_VERSION" --quiet -- "${RELEASE_PATHS[@]}"
[[ "$(git rev-parse HEAD^)" == "$CURRENT_HEAD" ]] || die "Release commit no longer follows the reviewed seal. No tag or push was created."
while IFS= read -r -d '' path; do
  is_release_path "$path" "${RELEASE_PATHS[@]}" || die "Release commit contains unreviewed path: $path. No tag or push was created."
done < <(git diff --name-only -z "$CURRENT_HEAD" HEAD)
[[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]] || die "Working tree changed during the release commit. No tag or push was created."

info "Tagging v$TARGET_VERSION..."
git tag -a "v$TARGET_VERSION" -m "Release v$TARGET_VERSION"
RELEASE_COMMIT=$(git rev-parse HEAD)

info "Pushing commit + tag to origin..."
git push origin "$DEFAULT_BRANCH" --quiet
git push origin "v$TARGET_VERSION" --quiet
ok "Pushed. CI ($RELEASE_CI_WORKFLOW) will now publish."

# --- watch the workflow run for this exact commit -------------------------
echo
info "Waiting for $RELEASE_CI_WORKFLOW on $RELEASE_COMMIT..."
RUN_ID=""
for attempt in {1..15}; do
  RUN_ID=$(gh run list --workflow="$RELEASE_CI_WORKFLOW" --commit="$RELEASE_COMMIT" --limit=20 --json databaseId,headSha \
    | jq -r --arg sha "$RELEASE_COMMIT" '[.[] | select(.headSha == $sha)] | first | .databaseId // empty')
  [[ -n "$RUN_ID" ]] && break
  sleep 2
done
if [[ -z "$RUN_ID" ]]; then
  err "Could not find a $RELEASE_CI_WORKFLOW run for pushed commit $RELEASE_COMMIT. The tag is already pushed; inspect Actions before retrying."
  exit 1
fi
if gh run watch "$RUN_ID" --exit-status; then
  ok "${BOLD}Release workflow succeeded.${RESET}"
  echo
  echo "  ${DIM}release:${RESET}  $(gh repo view --json url -q .url)/releases/tag/v$TARGET_VERSION"
  if [[ -n "${HOMEBREW_TAP_REPO:-}" ]]; then
    echo "  ${DIM}tap:${RESET}      https://github.com/$HOMEBREW_TAP_REPO/commits/main"
  fi
  exit 0
else
  err "${BOLD}Release workflow FAILED.${RESET} Investigate run $RUN_ID: gh run view $RUN_ID"
  echo "  Re-run the failed job on the EXISTING tag. Do NOT re-run this script; it bumps a new version."
  exit 1
fi
