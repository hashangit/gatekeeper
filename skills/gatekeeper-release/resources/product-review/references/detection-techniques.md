# Detection Techniques — Fast Heuristics

High-signal commands for Phase 2 (mapping) and for triaging lenses L2/L5/L6/L7/L12. Two rules:

1. **In a git repo, prefer `git grep`** — it searches only tracked files, so node_modules/vendor noise disappears. Fallback: `grep -rn --exclude-dir={node_modules,venv,.venv,dist,build} .`
2. **Every hit is a lead, not a finding.** Confirm by reading before reporting. A tool hit reported unread is confidence **tool-flagged**; after you've read and traced it, upgrade to **verified**.

## Size & shape (Phase 2 warm-up)

```bash
git ls-files | wc -l                        # tracked file count
git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -rn | head   # language mix
git ls-files '*.ts' '*.tsx' | xargs wc -l | sort -rn | head -20    # size outliers (L4)
```

## Outcome & experience leads (L0)

Leads only — L0 verdicts (outcome test, moments of truth) come from the walkthrough, not from grep.

```bash
# Where the promises live — positioning/landing/onboarding copy:
git ls-files | grep -iE 'landing|marketing|hero|pricing|copy|onboard'
# Outcome language in the copy (the "so that" behind each feature):
git grep -niE 'in (seconds|minutes)|effortless|seamless|hassle[- ]free|faster|never (miss|lose|worry)|peace of mind|trusted' -- '*.md' '*.html' '*.tsx' '*.astro' | head -30
# Time-to-first-value evidence — count input fields on entry flows:
git grep -cE '<(input|Input|TextField|FormField|select|textarea)' -- 'src/**' 'app/**' | head
# Moments of truth — files where trust qualities are carried (or broken):
git grep -nE '(delete|remove|destroy|pay|charge|checkout|confirm)' -- ':!*test*' ':!*.md' | cut -d: -f1 | sort | uniq -c | sort -rn | head -15
```

## Debt markers census (L5)

```bash
git grep -nE '(^|[^A-Z])(TODO|FIXME|HACK|XXX|WORKAROUND)([^A-Z]|$)' | wc -l        # total count (word boundaries via char classes — git grep lacks \b)
git grep -nE '(^|[^A-Z])(TODO|FIXME|HACK|XXX)([^A-Z]|$)' | cut -d: -f1 | sort | uniq -c | sort -rn | head -15   # clustered by file
git log -S 'FIXME' --format=%as -- <file> | tail -1                # marker age (oldest appearance)
```

Report the count, the clusters, and the oldest markers. Age turns a TODO from "work in progress" into "a decision that was never made".

## Stubs & not-implemented (L2)

```bash
git grep -niE 'not implemented|unimplemented|coming soon|placeholder|for now|temporar'
git grep -nE 'throw new Error\([^)]*implement' -- '*.ts' '*.tsx' '*.js'
git grep -nE '^[[:space:]]*pass[[:space:]]*$' -- '*.py'
git grep -nE 'return (null|\[\]|\{\}|undefined);?[[:space:]]*(//|/\*)' -- '*.ts' '*.js' | head -40  # suspiciously empty returns — read each
```

## Silent fallbacks (L2 — the dangerous ones)

```bash
git grep -nE '\|\||\?\?|catch' -- 'src/**/services/*' 'api/*'    # then read: which fallbacks hide failures vs handle them?
git grep -niE '(mock|fake|demo|sample)(data|mode)?[[:space:]]*[:=][[:space:]]*true'  # mock flags that might default on (-i catches mockMode)
```

## Debug leftovers (L5)

```bash
git grep -nE 'console\.(log|debug)|debugger' -- ':!*.test.*' ':!*test*'  # \b is unsupported by git grep's POSIX regex — avoid it
git grep -nE '^[[:space:]]*print\(' -- '*.py' | grep -vE 'test|__main__'
git grep -nE '(^|[^A-Za-z])(dd|dump|var_dump|dpm)\('
```

## Dead code leads (L5)

```bash
# Unreferenced files: list tracked source files, grep for their basename as an import — anything with zero hits is a lead
git ls-files 'src/**' 'app/**' 'lib/**' | while read f; do
  base=$(basename "$f" | sed 's/\.[^.]*$//')
  [ "$(git grep -lw "$base" -- ':!'"$f" | wc -l)" -eq 0 ] && echo "UNREFERENCED? $f"
done

# Dead exports (TS) — dedicated tools are worth it:
npx knip 2>/dev/null || npx ts-prune 2>/dev/null
# Python:
pipx run vulture . 2>/dev/null | head -30

# Commented-out code blocks (census, don't read each):
git grep -cE '^[[:space:]]*//[[:space:]]*(const|let|function|return|if|for|import)' -- '*.ts' '*.tsx' '*.js' | grep -v ':0$'
git grep -cE '^[[:space:]]*#[[:space:]]*(def|return|if|for|import)' -- '*.py' | grep -v ':0$'
```

## Secrets (L7)

```bash
# Working tree (heuristic — verify before claiming):
git grep -niE '(api[_-]?key|secret|passwd|password|access[_-]?token|private[_-]?key)["'\'']?[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{12,}'

# History (secrets "deleted" in a later commit are still there):
git log --all --diff-filter=A --name-only --format='%h %as' -- '*.env' '*.pem' '*.p12' '*credentials*' '*secret*' | head -20

# Client bundle exposure: build the frontend, then grep the OUTPUT (anything there is public):
grep -rniE '(api[_-]?key|secret|token)' dist/ build/ 2>/dev/null | grep -vE 'csrf|public' | head
```

## Hardcoded values & magic (L5/L6)

```bash
git grep -nE 'https?://' -- ':!*.md' ':!*lock*' ':!*.json' | grep -vE 'localhost|127\.0\.0\.1|0\.0\.0\.0|example\.|schemas\.|w3\.org' | head -30
git grep -nE '(setTimeout|sleep|timeout)[^)]*[0-9]{3,}' | head -20    # timeout values — same value twice, differently?
```

## Empty & swallowed error handling (L8)

```bash
git grep -nE 'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}' -- '*.ts' '*.tsx' '*.js'
git grep -nE '\.catch\([[:space:]]*(\(\)[[:space:]]*=>[[:space:]]*)?[a-z]*[[:space:]]*\{[[:space:]]*\}[[:space:]]*\)' -- '*.ts' '*.js'
git grep -nB1 -A1 'except.*:' -- '*.py' | grep -B2 'pass' | head -30
```

## Duplicate-path leads (L6 / Phase 5)

```bash
# Same concern, multiple filenames:
git ls-files | grep -iE '(util|helper|format|validate|money|date|fetch|api-client|http)'
# Near-duplicate blocks — paste one block into a search, or use jscpd if available:
npx jscpd --min-tokens 70 --reporters consoleFull src/ 2>/dev/null | tail -20
```

## Surface inventory (Phase 2)

```bash
# Backend routes (express/koa style):
git grep -nE '(app|router|server)\.(get|post|put|patch|delete)\(' -- ':!*test*'
# Decorator-style (nest/tsx):
git grep -nE '@(Get|Post|Put|Patch|Delete|Controller)\('
# Python frameworks:
git grep -nE '@(app|bp|router|api)\.(route|get|post|put|delete)|@api_view|path\(' -- '*.py'
# Frontend routes (react-router style):
git grep -nE '<Route |path="' -- 'src/**' 'app/**' | head -40
# Background work:
git grep -nE 'cron|schedule|@periodic|setInterval|queue|worker' -- ':!*test*' ':!*.md' | head -30
```

## Env surface (L2/L12)

```bash
git grep -hoE 'process\.env\.[A-Z0-9_]+' | sort -u
git grep -hoE 'os\.(environ|getenv)[^)]*' -- '*.py' | sort -u
# Compare against .env.example and README — read-but-undocumented and documented-but-unread are both findings
```

## Dependency health (L5/L7/L12)

```bash
npm audit --omit=dev 2>/dev/null | tail -10            # JS runtime vulns
npm ls --depth=0 2>&1 | grep -E 'UNMET|invalid|empty'  # broken installs
npx knip --dependencies 2>/dev/null | head -20          # unused deps
pip list --outdated 2>/dev/null | head -10; pipx run pip-audit 2>/dev/null | tail -10
cargo audit 2>/dev/null | tail -8
```

## Git archaeology (Phase 5 — fossil history)

```bash
git log --oneline -30                       # recent mood: panic clusters near releases?
git branch -a --sort=-committerdate | head  # long-lived parallel branches = fossilized parallel approaches
git log --diff-filter=D --name-only --format='%as' | head -40   # deleted features (re-implemented elsewhere?)
# Highest-churn files = most fragile, review them first:
git log --format= --name-only | sort | uniq -c | sort -rn | head -15
# Revert/rework patterns:
git log --oneline --grep -iE 'revert|rollback|revert' | head
```

## Stack-specific extras

- **Rails**: `rails routes` for the true route table; `bundle exec rubocop` if configured; `brakeman` for security static analysis.
- **Django**: `python manage.py show_urls` (django-extensions) or read `urls.py`; `python manage.py check --deploy` for prod-readiness warnings — genuinely useful, run it.
- **Next.js**: check `app/` vs `pages/` coexistence (duplicate routing approaches); `next build` output for bundle warnings.
- **Monorepos**: inventory per package first; the *dependency graph between packages* is where duplicate paths hide (two packages implementing the same util).
