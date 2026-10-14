# Layer 4 — Confidence & Operations Lenses (L10–L12)

## L10 · Testing & Verification

**Core question:** what would break without anyone knowing?

Judge by risk coverage, not coverage percentages: 90% coverage that never touches failure paths is worth less than 40% coverage parked exactly on money, auth, and data loss.

### Checks

1. **Critical-path coverage.** For each P0 surface identified in Phase 3 (money, auth, data loss): do tests exist, and do they exercise the *scary* paths — failure mid-flow, concurrent operations, ownership boundaries, invalid input through the API — or only the happy path? Happy-path-only tests on a core flow give false confidence, which is worse than no tests (P2 finding: the suite certifies something it didn't check).
2. **Pyramid shape.** Only e2e tests: slow, flaky, nobody runs them locally — integration gaps hidden. Only unit tests: the seams (API↔DB, UI↔API) are untested. The missing middle (integration tests against real boundaries) is the most common gap — name it explicitly.
3. **Assertion quality.** Would this test fail if the behavior broke? Smoke tests asserting "a call happened"; mocks asserting mock behavior; snapshot tests as change-detectors nobody reads. Each style has a place; a suite *built* on them is a P2.
4. **Flakiness seeds.** `sleep()` instead of awaiting; order-dependent tests; shared mutable fixtures; time-dependent tests without clock injection; live network in unit tests. Flaky tests train the team to ignore red, which is a P1-level cultural hazard.
5. **Fixture realism.** Test data drifting from the real schema/enums (nullable fields always populated in fixtures — masks null-handling bugs; statuses that no longer exist still used). Diff fixture shapes against actual schema/seed data.
6. **Untested seams.** Webhooks (payload verification, replay, ordering), cron/scheduled jobs, error branches, migrations, permission boundaries. These fail in production precisely because they're awkward to test.
7. **CI discipline.** Does CI run on every PR? Does red block merge, or is it advisory? Are typecheck + lint + test all in the pipeline? Decorative CI (present, ignored) deserves calling out — it's the testing version of a security checkbox.
8. **The fresh-clone test.** Follow the README setup alone on a clean machine. Works? This is simultaneously an L10 and L12 check — missing steps, wrong versions, undocumented prerequisites. Each gap is P2 (P1 if a new teammate genuinely cannot onboard).

## L11 · Performance & Scalability

**Core question:** what falls over first at 10× the current load — and does anyone know?

### Checks

1. **N+1 patterns.** Queries or API calls inside loops; per-item lazy loads (each row fetching its owner). Find them by reading loops whose bodies `await`/fetch/query. On a list endpoint, N+1 is P1; elsewhere P2.
2. **Unbounded reads.** List endpoints without pagination or limits; whole-table loads; "load all then filter in memory". Growing-data guarantee: it works at demo scale and degrades on a curve — flag every endpoint where growth makes it slower *per request*, not just overall.
3. **Hot-path waste.** Per-request work that could be cached (config, session lookup, parsed templates); synchronous heavy work in the request path (email sending, PDF/image generation, webhooks fanning out) that belongs in a queue.
4. **Payload discipline.** API over-fetching (whole entities where one field suffices); frontend waterfalls (sequential awaits that could run in parallel); the same fetch repeated across components without sharing.
5. **Frontend weight.** Bundle size outliers (one dependency dominating); no code-splitting on fat routes; unoptimized images on core pages; effects refetching on every render; render loops.
6. **Memory in long-lived processes.** Unbounded caches/maps/arrays (no eviction); listeners never removed; large result sets held fully in memory when streaming would do.
7. **Index awareness** (heuristic if schema is inspectable): frequent filter/sort/join columns with no index evidence. Tool-flagged confidence unless you can benchmark — but the *absence* of any index on a foreign-key-ish column used in every query is worth reporting.
8. **First-break analysis.** Name the first component that breaks at 10× users/data/rate. If the honest answer after this review is "unknown — never load-tested, no metrics", that answer is itself a finding (feeds L12 observability).

## L12 · Release Readiness

**Core question:** can this be deployed, observed, and rolled back — by someone who didn't write it?

### Checks

1. **Fresh-clone test** (from L10): setup from the README alone works on a clean machine.
2. **Config surface.** Every env var documented (`.env.example` complete and current); defaults are prod-safe (no dev conveniences defaulting on: CORS wide open, seeded demo users, debug toolbars, verbose error pages); no config value meaningfully different between environments by *accident* (deliberate differences documented).
3. **Secrets & keys.** Per-environment secrets; a rotation story that exists at all; no production credentials reused in dev/staging.
4. **Deploy story.** Reproducible, ideally one command; migrations sequenced *into* the deploy (not "remember to run them"); build artifacts pinned (lockfiles committed, image digests, not floating tags).
5. **Rollback path.** What happens on a bad deploy: backward-compatible DB changes (expand/contract) or tested down-migrations? Feature flags as kill switches for risky new paths? If the only rollback is "restore from backup and pray", that's a P1 finding at a production bar.
6. **Observability.** Logs with levels and enough context to diagnose (request IDs, user IDs where appropriate); errors reaching a tracker rather than stdout alone; health endpoints; alerts on core metrics (error rate, queue depth, job failures). The test question: can you answer "is it working right now?" without SSH-ing into anything?
7. **Docs accuracy.** README matches reality; API docs spot-checked against 3 actual handlers (drift between docs and handlers is L6-flavored but lands here as user-facing); a runbook for the scariest operational task (restore, failover, purge); release notes or CHANGELOG habit exists.
8. **Data lifecycle.** Backups: configured, *restore-tested* (an untested backup is a hope, not a backup); retention policy on PII; a path for deletion requests — if the product stores user data, this drifts from hygiene into legal/compliance territory.
9. **Supply chain & licensing.** Dependency licenses compatible with the product's distribution model (copyleft in a closed-source product is a legal finding); versions pinned; lockfiles committed; any dependency pulled from a personal registry or git commit hash deserves a note.
