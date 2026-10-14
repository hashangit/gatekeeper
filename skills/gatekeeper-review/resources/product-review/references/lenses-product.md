# Layer 1 — Product & Experience Lenses (L0–L3)

## L0 · Human Outcome & Experience

**Core question:** what human outcome is this product built to produce — and does using it, as built, actually produce that outcome?

Every product and feature exists on a chain of intent:

```
WHY   · the outcome       what the human walks away with
                          ("clients pay me faster", "I never miss a renewal")
WHAT  · the functionality  what the product does to produce it
                          (invoices, reminders, payment tracking)
FEEL  · the experience     the quality the product must project while doing it
                          (fast, safe, effortless, in control, professional)
```

A product can have aligned docs (L1 ✓), complete features (L2 ✓), and polished interaction mechanics (L3 ✓) and still fail here: the expense tracker that records everything perfectly but makes retrieving totals for reimbursement a slog. Functionality complete, outcome undelivered. This lens exists to catch that class of failure — code-centric review misses it by construction.

### Checks

1. **Reconstruct the outcome statements.** For the product and each flagship feature, complete: "A [user] uses [feature] so that [outcome]." Sources in order of trust: positioning/landing copy, onboarding copy, the problem statement in docs/issues; infer from what the code optimizes for only as a last resort, and mark inferred statements as inferred. A feature whose statement *cannot* be completed — no positioning reference, no dependent feature, no problem it visibly solves — is a **purpose orphan**: finding plus owner question.
2. **Run the outcome test.** For each statement, walk the implementation and ask not "does the feature work?" (that's L2) but "does the user get the outcome?" Trace the outcome *past the feature's last screen*: an invoicing product's outcome is "get paid", not "send invoice" — so what supports the past-the-send-button half (payment tracking, reminders, reconciliation)? A mechanically complete feature that stops short of its outcome fails this test. On a flagship feature, that is **P0**: the product doesn't do the thing it exists to do, no matter how well-built its parts are.
3. **Name the experience qualities and audit their carrying moments.** From the positioning, list the 2–4 qualities the product promises to project — fast, safe/trustworthy, effortless, in control, professional, delightful. Each quality is carried by specific moments in the product; audit those moments in code:
   - *fast*: perceived speed on the core action is the product's speed signature, whatever benchmarks say — the slowest step of the main flow is the moment that defines it;
   - *safe*: login, payment, deletion, sharing — do they project safety (confirmation, transparency, undo) or undermine it (silent actions, jargon errors, no way back)?
   - *effortless*: time-to-first-value — count screens, inputs, and decisions from entry to first realized outcome, and compare the count against what the promise implies ("effortless" + 12-field signup + email verification + workspace setup = a contradiction the walkthrough can prove);
   - *in control*: can users see what the product did on their behalf, and reverse it?
   Grade contradictions against the *named* quality, not against a generic ideal — an unexplained wait is a P2 hygiene issue in most products and a P1 intent failure in one whose pitch is "fast".
4. **Map the moments of truth.** Identify the 3–5 moments that decide adoption and trust: first run, first success, first failure, first payment, first "where did my data go?". Walk each through the code and grade it against the outcome statement and named qualities. First failure deserves extra attention — it's where trust is won or lost, and where experience design is most often an afterthought.
5. **The alternative test.** For each flagship feature: what does the user do *instead* of this product (spreadsheet, manual process, doing nothing)? Does the implementation beat that alternative on the outcome, or merely digitize it? A digitized-but-not-better flagship is a product-thesis problem — surface it as an owner question with evidence, not as a verdict.
6. **Classify what you find** with the outcome breakage taxonomy:
   - **unstated** — no one can articulate the outcome; every downstream judgment is guesswork (owner question, and P1 on a flagship feature);
   - **undelivered** — functionality works, the outcome doesn't materialize (P0/P1 by centrality to the product);
   - **contradicted** — the product actively undermines its own outcome: heavy setup in an "effortless" product, alarming UX in a "trust" product;
   - **unowned** — the outcome spans features but no feature owns the last mile: everything works, and the outcome falls into the gap between them (flag here, confirm across seams in Phase 5);
   - **unmeasured** — no signal anywhere, product-side or code-side, that would reveal whether users achieve the outcome (ties into L10/L12: at a production bar, outcome attainment needs instrumentation).

### Output of this lens

An outcome table: statement → evidence (positioning copy, `file:line`) → outcome-test verdict → qualities carried or contradicted → breakage class. Every *unstated* outcome goes on the owner-questions list; every *unowned* one goes to Phase 5.

### Boundaries (so the lenses don't blur)

L0 judges whether the product delivers its outcomes and named experience qualities; L1 whether the code matches the written claims; L2 whether what's reachable is fully built; L3 whether the interaction mechanics are executed well. When a finding in L3 contradicts a quality named here, tag both lenses — contradiction with stated intent raises the severity.

## L1 · Product Intent Alignment

**Core question:** does the code serve the product the docs claim — or a different one?

Misunderstood product intent is the most expensive defect class because it ships *working* code that solves the wrong problem. It hides in the gap between what is written down and what is built. Run L0 first: the human purpose (outcomes, experience qualities) is the ground truth — L1 audits whether the written claims serve it, and whether the code serves the claims.

### Checks

1. **Extract the claims.** From README, docs/, landing copy, specs, issue references, list each as "the product claims X". This is the claim list — the ground truth you audit against.
2. **Trace every claim to implementation.** Classify each: `implemented` / `partial` / `stub` / `absent` / `contradicted`.
   - `absent` with a confident claim (marketing site sells it, code doesn't have it) is a P0-level intent failure.
   - `contradicted` (code does the opposite or something incompatible) is worse — something was misunderstood, and where it's misunderstood once, look nearby for more.
3. **Effort–attention mismatch.** Where does the code spend its complexity? A product claiming "simple invoicing" with a hand-rolled rules engine but no PDF export has inverted attention. Map: the three things the brief emphasizes vs the three biggest modules. Misalignment is a finding with evidence on both sides.
4. **Vocabulary drift.** Domain terms in code vs user-facing copy (`workspace` in UI, `team` in API, `org` in DB). A consistent rename history is hygiene; three *live* concepts for one idea signals the team never settled what the product means — and unsettled vocabulary produces unsettled logic.
5. **Orphan features.** Fully-built functionality that nothing in the product story references. Either dead code (L5) or evidence the intent drifted after the feature was built. Both go to the owner-questions list.
6. **Audience mismatch.** Features tuned for a different user than the stated one: admin-grade knobs in a consumer product, consumer simplifications in a power-tool, enterprise assumptions (SSO, roles) bolted onto a solo-user product.

### Output of this lens

- A claim-by-claim traceability table (claim → status → evidence).
- An owner-questions list. Intent findings are confirmable only by the product owner — present the divergence with evidence on both sides; never assert misunderstanding as fact when a charitable reading exists.

## L2 · Feature Completeness

**Core question:** for everything reachable, does it actually work end-to-end? (L0 then asks the harder question: does the user get the *outcome*? A feature can pass here and fail there.)

Incomplete isn't always "not built" — the dangerous form is *looks built*. A UI that renders, a route that returns 200, a button that fires an event… into a handler that does nothing.

### Checks

1. **Stub census.** Functions returning hardcoded or mock data; `throw new Error("not implemented")`; empty event handlers; "coming soon" UI shipped enabled. Rate by surface: a stub on a core flow is P1 (P0 if the UI hides that it's a stub — users will trust it).
2. **Half-wired flows.** Four directions, each a finding: frontend exists / backend missing; backend exists / frontend missing; event published / nothing consumes; handler registered / nothing triggers it.
3. **Partial CRUD.** Create without edit or delete; list without pagination or filter; detail page showing actions that don't exist; delete that skips confirmation of cascade effects ("delete the org" — what happens to its data?).
4. **Branch gaps.** `switch`/`if` chains with missing or `TODO` cases; permission matrices with empty cells; settings that render but don't persist.
5. **Background surfaces.** Cron/scheduled jobs declared but never registered; webhooks received but unhandled (or handled but unverified); queue consumers defined but not started; emails templated but never sent.
6. **Config orphans.** Env vars read but undocumented; documented but never read; feature flags referenced in code but absent from config. Each is an open end.
7. **Migration leftovers.** New flow added while the old flow remains fully reachable — flag here, and duplicate-path it in Phase 5 (which path is real?).
8. **Silent fallbacks — the most dangerous incompleteness.** Code that "works" by falling back to default or mock data when the real path fails. Demos pass, tests pass, production quietly does the wrong thing. Grep for fallback patterns on data-fetching paths and trace each: is failure ever surfaced?

### Method

Walk the Phase 2 surface inventory top to bottom. For each surface marked `partial` or `stub`, find where the incompleteness lives (`file:line`) and what it would take to finish — that estimate belongs in the report's action plan.

## L3 · UX & Interaction

**Core question:** where does the product fight, confuse, or abandon the user?

UX review from code is a walkthrough discipline, not a skim: pick the 3 core journeys from the Phase 1 brief and walk each one keystroke by keystroke through the implementation. Findings come from walking. L0 names the experience qualities the product must project; this lens verifies the mechanics — when a finding here contradicts a quality named in L0, tag both lenses, because contradiction with intent raises severity.

### Checks

1. **The state triangle.** Every async surface needs loading / empty / error / success states. Missing error state on a core flow = P1 (users see nothing or a crash). Missing empty or loading state = P2. A list that shows stale data as if current is P1 on money/data surfaces.
2. **Action feedback.** Every user action produces a visible response within perception time; async actions show progress and prevent double-submit. The test: for each button/handler, what tells the user "it worked" or "it failed"? "Nothing" is a finding.
3. **Form quality.** Validation timing (inline before submit vs. all-at-once after); error messages that say *what to fix*, not "Invalid input"; values preserved when submission fails; required-field honesty (marked required, actually required).
4. **Flow integrity.** Screens reachable in both directions; destructive actions confirmed or undoable; multi-step flows surviving refresh and back-button (state in URL vs component memory); deep links working for shareable things.
5. **Misguided flows.** Steps the user didn't ask for; confirmations that don't match consequences ("OK" deleting data); navigation that resets user context mid-task; wizards that trap (no exit without finishing).
6. **Pattern consistency.** Same operation, same pattern: modals vs pages for equivalent actions; one primary button per view; date/number/currency formatting uniform across screens (drift here feeds an L6 finding — same root cause, user-visible symptom).
7. **Accessibility.** Form labels associated; a complete keyboard path (every action reachable and operable, no focus traps); focus management on route/modal changes; contrast on text *and disabled states*; alt text; ARIA only where semantics are genuinely missing.
8. **Responsive behavior.** Primary breakpoints usable; tap target sizes; horizontal-scroll leaks; tables at mobile widths.
9. **Copy quality.** Errors that blame the user; internal jargon leaking to UI ("entity 402"); placeholder text shipped to production; inconsistent tone between screens.
10. **Trust moments.** What does refresh mid-checkout do? Back button after save? Two tabs on the same account? Every answer that involves silent data loss is P1.

### Method

Per core journey, write the walkthrough as a numbered step list in the report only where it *breaks* — the report documents the breaks, not the happy walk. Where a UX problem traces to a code-level cause (state management, race, missing handler), cross-reference the L-lens so the reader sees one problem, not two.
