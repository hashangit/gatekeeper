# Layer 2 — Code & Structure Lenses (L4–L6)

## L4 · Architecture & Boundaries

**Core question:** is the structure a map or a maze?

The test of architecture is whether a new engineer can predict where code lives. Convoluted implementations are local symptoms; boundary problems are why they keep appearing.

### Checks

1. **Draw the layer map.** Can you state the intended layers (UI → application/services → domain → data/access)? Then find violations: UI importing DB clients directly; domain types importing framework types; skip-layer calls that make the middle layer decorative. Violations that appear once are a note; a *pattern* of them means the architecture is fiction.
2. **Feature cohesion.** Does related code live together? One "user" feature scattered across six directories by *kind* (all controllers together, all models together) is a choice — judge it by consistency. Scattered *by accident* (some features vertical, some horizontal, shared code in a junk drawer) is a P2 structure finding.
3. **Coupling signals.** Shared mutable state; hidden globals (process.env reads deep in domain code, singletons); modules reaching into each other's internals; a "context" object threaded through every function that is really a god-parameter. Each coupling found is debt that makes the next change harder.
4. **Convoluted implementations — flag each occurrence, not the general vibe:**
   - functions over ~100 lines or doing more than one job;
   - nesting deeper than 4 levels;
   - indirection that adds nothing: A→B→C pass-through where B is pure relay;
   - data ping-ponging between shapes (entity → DTO → form → DTO → entity, each slightly lossy);
   - premature abstraction: interface + factory + registry for exactly one implementation;
   - heavy machinery for a two-case job (reflection, plugin systems, codegen for a handful of variants).
   Convolution on a core path is P2; convolution on a money/auth path is P1 (it hides bugs from reviewers).
5. **Cyclic dependencies** at module level. TS: `madge --circular`; Python: cycles surface as partial-import bugs. Every cycle is a boundary that dissolved.
6. **Framework fit.** Code fighting its framework: manual DOM manipulation next to declarative state; raw SQL beside an ORM for the same table; hand-rolled routing/serialization replacing the framework's. Each is a future "why doesn't this behave normally" confusion.
7. **Size outliers.** Files or modules 5× the median size — read them. They concentrate mixed responsibilities and hide both convolution and dead branches.

## L5 · Code Health

**Core question:** how much of the codebase is dead, owed, or rotting?

### Checks

1. **Dead code, in order of confidence:**
   - unreferenced files (nothing imports/executes them — verify across *all* entry points, including scripts and configs, before claiming);
   - unimported exports (knip/ts-prune for TS; vulture for Python — tool-flagged until verified);
   - unreachable branches after constant conditions (`if (FLAG)` where FLAG is compile-time false);
   - commented-out code blocks (census them with grep; don't read each one — the count and clustering is the finding);
   - feature-flag remnants: flag checked in exactly one stale place, or flag always true/false but still gating code;
   - old API/feature versions still served beside their replacements;
   - dead routes: endpoints in the codebase that no client calls (cross-check the Phase 2 map against actual UI/API usage).
2. **Debt markers census.** TODO/FIXME/HACK/WORKAROUND/TEMP. Count, cluster by area, and — if git is available — date them (`git log -S '<marker text>'`). Age matters: a three-year-old FIXME on a core path is a decision that never got made; fresh TODOs are just work in progress.
3. **Copy-paste drift.** Near-identical blocks that differ subtly — a regex here, a constant there. The *divergence* is the finding (P1/P2); identical duplication alone is P3. This check feeds directly into L6 and Phase 5.
4. **Dependency health.**
   - unused dependencies (knip/depcruise for JS, `pipdeptree`/manual for Python);
   - two dependencies for one job (moment *and* date-fns; axios *and* fetch; two validation libs) — pick-one findings;
   - deprecated or renamed packages still in use;
   - majors behind current;
   - audit results (npm audit / pip-audit / cargo audit) — see detection-techniques.md.
5. **Debug & test leftovers.** `console.log`/`debugger`/`print`/`dd`/`dump` on non-dev paths; mock flags defaulting on in production paths; test backdoors (auth bypass "for testing"); seed/demo data reachable in production flows. Test backdoors reachable in prod are P0; the rest is P3 unless it leaks data (then L7 decides).
6. **Magic values.** Hardcoded URLs, tenant/user IDs, timeouts, currency amounts, plan limits — especially the same value hardcoded twice with one differing (that's L6 drift with a blast radius).
7. **Permanent temporaries.** `temp`/`new`/`final`/`v2`/`old` in names; migration shims still in place after the migration ended; `NewFoo` and `Foo` both alive. Each pair is a duplicate-path question: which one is real?

## L6 · Consistency & Coherence

**Core question:** how many wrong ways are there to do the same thing here?

This lens is the engine behind the user's "duplicate paths and approaches that lead to confusion". It runs within segments but does its real damage *between* them — run it again in Phase 5.

### Checks

1. **Duplicate paths inventory.** For each core concern, find every implementation:
   - validation, auth/permission checks, API/fetch wrappers, date & time handling, money math, error shaping, logging, env/config access, pagination.
   Determine the canonical one (newest? most used? blessed in docs?) and classify:
   - no canonical + divergent behavior between paths → **P1** (a future "but it worked there" bug is now guaranteed);
   - canonical exists but routinely bypassed → **P2** (the bypasses are the finding — why do they exist? often the canonical path is missing something);
   - multiple paths, identical behavior → **P3** (cleanup, low urgency).
2. **Naming drift.** Same concept, different names across modules (`fetchUser`/`getUser`/`loadProfile`); same name, different meanings (a `user` that is sometimes the account, sometimes the profile row). Trace one entity through every layer and list what it's called — the list *is* the finding.
3. **Convention drift.** Error handling styles (exceptions vs result objects vs error codes) mixed; async patterns mixed (callbacks beside promises); file-naming casing mixed; component patterns mixed (class and function components, or two state-management styles); import style mixed (deep relative paths beside aliases). Drift within one contributor's files is noise; drift across the same file is the strongest signal — someone didn't know which convention applied.
4. **API coherence.** Response envelope shape uniform? Status-code semantics consistent (any 200-with-error-body)? One pagination style? Error body contract stable? Casing (snake/camel) systematic or ad hoc? Judge by *contract stability*: a client can be written against consistent rules; ad hoc responses force per-endpoint special-casing forever.
5. **Data shape coherence.** Same entity shaped differently across layers without a mapping boundary — frontend re-guessing backend fields, or two endpoints returning different shapes of the same entity. Systematic transforms at boundaries are architecture; field-by-field improvisation is drift.
6. **Config coherence.** Some features env-driven, some hardcoded, some both (env var *with* a hardcoded default that differs from the documented default). Enumerate the config surface and grade its uniformity.
7. **Comment truthfulness.** Comments, tests, or docs describing behavior the code no longer has. Each stale comment is a P2 landmine: the next reader trusts it and mis-reasons the code. A comment contradicting adjacent code is the single strongest "someone misunderstood something here" signal — always stop and investigate those.

### Method

For concerns in check 1, build a small matrix per concern: implementation → location → behavior difference → canonical? The matrices go in the report; they are the most actionable artifact this skill produces.
