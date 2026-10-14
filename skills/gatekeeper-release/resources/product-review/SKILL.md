---
name: product-review
description: 360-degree readiness review of an entire software product or codebase — completeness and missing code, open ends, dead code, engineering debt, redundant and duplicate implementations of the same thing, inconsistencies, misunderstood product intent, misguided UX, convoluted implementations, security vulnerabilities, and testing/performance/ops/doc gaps — ending in an evidence-backed, severity-ranked readiness verdict. Use whenever the user asks to review, audit, or assess a whole product, app, or codebase for readiness or problems (NOT a single PR or diff). Triggers include "review this product", "is this ready to ship?", "audit this codebase", "what's incomplete, broken, or dead in this app?", "find debt and security holes", "360 review of my product".
---

# Product Review — the 360° Readiness Audit

Answer one question, with evidence: **is this product complete and ready — and if not, exactly what stands between it and ready?**

This is a whole-product audit, not a diff review. A PR review asks "is this change safe to merge?". This asks "is this *product* fit to ship?" — across everything from product intent to security posture to whether the README setup even works.

## The 360° model

Four layers, thirteen lenses, one cross-layer pass:

```
┌───────────────────────────────────────────────────────┐
│ LAYER 1 · PRODUCT & EXPERIENCE    why it exists for   │
│ (outcome · intent · complete · UX) a human, what it   │
│                                    claims, what users │
│                                    actually hit       │
├───────────────────────────────────────────────────────┤
│ LAYER 2 · CODE & STRUCTURE        how it's built      │
│ (architecture · health · consistency)                 │
├───────────────────────────────────────────────────────┤
│ LAYER 3 · RISK & RESILIENCE       how it fails        │
│ (security · error handling · data integrity)          │
├───────────────────────────────────────────────────────┤
│ LAYER 4 · CONFIDENCE & OPERATIONS how we know it works│
│ (testing · performance · release readiness)           │
└───────────────────────────────────────────────────────┘
          ↑ Phase 5 cross-checks run across all layers ↑
   (duplicate paths · drift · seam failures · orphans ·
    intent contradictions)
```

The cross-layer pass is where the most serious findings usually live: two parallel implementations of validation that have drifted apart, a security check present on one route but forgotten on its sibling, a feature wired in the UI but orphaned in the backend, an outcome that spans features but belongs to none of them.

## Stance

Five rules that keep the audit honest:

1. **Evidence or it didn't happen.** Every finding cites `file:line` (or a command's output). "Seems fragile" is not a finding; "the catch block at `api/orders.ts:41` swallows payment failures" is.
2. **Report, don't repair.** The deliverable is the assessment. Don't fix code unless explicitly asked. Fix-direction notes are welcome; patches are out of scope.
3. **Judge against the product's own intent.** A demo-grade auth flow may be fine for an internal tool and a P0 for a public SaaS. Establish the readiness bar (Phase 1) before grading anything.
4. **Severity over volume.** One verified P0 outweighs fifty style nits. Cluster related findings; never pad the report.
5. **State what you didn't review.** A readiness verdict is only honest with a coverage statement: what was read deeply, what was scanned, what was never opened.

## Workflow

| Phase | Purpose | Output |
|---|---|---|
| 1 · Frame | What is this product, for whom, to what outcome — and what does "ready" mean? | Product brief + outcome statements + readiness bar |
| 2 · Map | What exists, and is each surface complete? | Surface inventory with status |
| 3 · Segment | What gets reviewed, how deeply? | Review plan |
| 4 · Deep-dive | Run the lenses over each segment | Evidence-backed findings |
| 5 · Cross-check | 360° synthesis across segments | Cross-cutting findings |
| 6 · Verdict | Score, prioritize, report | Readiness report |

### Phase 1 — Frame the product

Read the README, docs/, landing copy, package manifests, entry points, and route tables. Write a 5–10 sentence product brief: what it is, who it's for, the stack, and the stated goals.

Then reconstruct the **outcome statements** — for the product and each flagship feature, complete: "A [user] uses [feature] so that [outcome]" — and name the two to four **experience qualities** the product promises to project (fast, safe, effortless, in control…). These anchor lens L0 and sharpen every judgment downstream: a claim that contradicts an outcome matters more than a claim that merely lacks code.

Then set the **readiness bar**. "Ready" for a demo, an internal tool, an MVP with friendly early users, and a production SaaS are different thresholds — infer the bar from the product's own docs and the user's framing; ask only if truly undecidable.

If the docs and the code disagree about what the product even *is*, that is finding #1.

### Phase 2 — Map the surface

Inventory every user-reachable surface: routes/screens/endpoints/commands, data models, external integrations, background jobs, and admin surfaces. For each, record a status: **complete / partial / stub / dead / missing**.

Use `references/detection-techniques.md` for fast inventory commands (route greps, env-var surface, dependency list, git archaeology). This map is the backbone — every lens is applied *to something in it*, and the map itself already yields L1/L2 findings.

### Phase 3 — Segment

Carve the product along two axes:

- **Vertical slices** (feature areas): "checkout", "auth", "admin", "search"…
- **Horizontal slices** (cross-cutting): API layer, data layer/schema, shared UI components, jobs/queues, config.

Assign a depth per segment:

- **Deep** (read every relevant file): anything involving money, authentication, authorization, data loss or corruption, and whatever the product brief calls core.
- **Scan** (tooling plus targeted reads): everything else. Record it as scanned in the coverage statement.

For large codebases (roughly >50k LOC), delegate deep-dives to subagents — one per segment, each given the relevant lens checklist from `references/` — then spot-verify their claims before including them. Never report a subagent finding you haven't confirmed.

### Phase 4 — Deep-dive

Apply the lenses segment by segment, reading the checklist files on demand:

| Reference | Lenses |
|---|---|
| `references/lenses-product.md` | L0 outcome & experience · L1 intent · L2 completeness · L3 UX |
| `references/lenses-code.md` | L4 architecture · L5 code health · L6 consistency |
| `references/lenses-risk.md` | L7 security · L8 error handling · L9 data integrity |
| `references/lenses-confidence.md` | L10 testing · L11 performance · L12 release readiness |

You don't need every lens on every segment — e.g. L0 outcome concentrates on flagship features and moments of truth, L9 data integrity on the data layer, L3 UX on user-facing slices. The lens catalog below says where each lens bites hardest.

Every finding from this phase carries: lens · segment · evidence (`file:line`) · why it matters · severity · confidence.

### Phase 5 — Cross-check (the 360° pass)

The checks that only exist *between* segments. Budget real time for this phase; it is the skill's core value.

- **Duplicate paths.** For each core concern (validation, auth checks, API wrappers, date/money math, error shaping, logging), find every implementation. If behavior has diverged, that's a P1 — divergence between two live paths of the same concern guarantees a future "but it worked there" bug.
- **Drift.** Same concept handled differently in different segments: error responses shaped one way in `/api/orders`, another way in `/api/users`; timestamps UTC here, local there. Systematic differences are fine; ad hoc ones are findings.
- **Seam integrity.** Trace 3–5 flows end-to-end across segment boundaries (UI → API → DB, webhook → queue → side effect). Do the pieces agree on error contracts, auth, data shapes, and idempotency at each hand-off? Seams are where checks silently go missing.
- **Orphans.** Features reachable on one side but not the other: backend endpoints nothing calls, UI screens nothing links to, events published nothing consumes, jobs enqueued nothing processes.
- **Intent contradictions.** Places where behavior contradicts the Phase 1 brief — the strongest signal of misunderstood product intent. Collect them as owner-questions, not accusations.
- **Unowned outcomes.** Trace each outcome statement across feature boundaries: every feature works in isolation, but the outcome falls into the gap between them — the product ends at "export" while the user's outcome was "get reimbursed". Confirm L0's suspicions here, at the seams.
- **The rebuild question.** If the team rebuilt this product tomorrow using only its docs, what would surprise them? Surprises = doc rot + unstated intent.
- **Fossil history** (if git is available): long-lived parallel branches, recently deleted then re-added features, files with the highest churn (most fragile), panic-commit clusters near release dates.

### Phase 6 — Verdict and report

Produce the report using `references/report-template.md`. Lead with the verdict, then top findings, then the lens-by-lens detail, then the action plan. Always include the coverage statement and the owner-questions list.

## Lens catalog

| # | Lens | Core question | Bites hardest in |
|---|---|---|---|
| L0 | Human Outcome & Experience | Does using it, as built, deliver the outcomes and experience it exists to provide? | Positioning copy, flagship features, moments of truth |
| L1 | Product Intent Alignment | Does the code serve the product the docs claim — or a different one? | Docs vs code, naming, orphan features |
| L2 | Feature Completeness | Is everything reachable actually implemented end-to-end? | Stubs, half-wired flows, partial CRUD |
| L3 | UX & Interaction | Where does the product fight, confuse, or abandon the user? | User-facing slices, flows |
| L4 | Architecture & Boundaries | Is the structure a map or a maze? | Module boundaries, big files |
| L5 | Code Health | How much of the codebase is dead, owed, or rotting? | Everywhere; horizontal slices |
| L6 | Consistency & Coherence | How many wrong ways are there to do the same thing? | Between segments (Phase 5) |
| L7 | Security | What can an attacker or a curious user reach? | Auth, money, data surfaces |
| L8 | Error Handling & Resilience | What happens when something fails halfway? | Seams, external calls |
| L9 | Data Integrity | Can the data silently become wrong? | Data layer, migrations |
| L10 | Testing & Verification | What would break without us knowing? | CI, critical paths |
| L11 | Performance & Scalability | What falls over first at 10× load? | Hot paths, lists, frontend |
| L12 | Release Readiness | Can this be deployed, observed, and rolled back? | Config, deploy, docs |

## Severity model

| Level | Name | Definition | Examples |
|---|---|---|---|
| **P0** | Blocker | Ships broken, insecure, or lossy. Unacceptable in any release. | Auth bypass/IDOR on real data; secret in the client bundle; partial-failure data loss on a core flow; core journey crashes; flagship feature fails its outcome test — mechanically complete, but doesn't deliver what it exists to deliver |
| **P1** | Major | Feature incomplete, security risk with preconditions, or core-flow confusion. Blocks the *stated* readiness bar. | Divergent duplicate paths; ownership check missing on one route; no error state on checkout; no pagination on a growing list |
| **P2** | Minor | Debt and inconsistency that misleads maintainers or degrades UX at the edges. | Convention drift; comment-code mismatch; swallowed errors on non-core paths; doc rot |
| **P3** | Hygiene | Cleanliness and polish. | Dead exports; naming; console.log leftovers; TODO census items |

Judge severity *against the readiness bar*: the same gap can be P1 for a production SaaS and P3 for an internal demo. Say which bar you used.

## Confidence model

Tag every finding:

- **Verified** — you read the code and traced the behavior yourself.
- **Suspected** — pattern strongly suggests it; you could not fully confirm. State what would confirm it.
- **Tool-flagged** — a grep/audit produced the signal; you have not read the context. These must be labeled as such (and ideally upgraded before reaching the report's top section).

## Scoring and verdict

Score each layer /10 based on the severity and density of its findings:

- **9–10** — production-hardened; remaining findings are polish.
- **7–8** — solid; no P0s, P1s are few and bounded.
- **5–6** — functional core with real gaps; readiness requires conditions.
- **3–4** — significant incompleteness or risk; core flows affected.
- **1–2** — prototype; structure or safety not yet established.

Verdict rules:

- 🔴 **Not ready** — any P0, or three or more P1s concentrated in a single layer.
- 🟡 **Ready with conditions** — P1s exist but are bounded; the conditions are the listed fixes.
- 🟢 **Ready** — no P0/P1; remaining items are a P2/P3 backlog.

## Scaling

- **Small (< ~5k LOC):** single pass, all thirteen lenses, deep everywhere. Skip subagents; run Phases 1–3 lightly (an hour of framing for a day of reviewing is a bad trade).
- **Medium (~5k–50k):** full workflow as written. Deep on core + risk segments, scan the rest.
- **Large (> ~50k):** full workflow plus subagent delegation per segment. Triage lenses per segment ruthlessly; an explicit not-covered list matters most here.

## Example finding format

```
**[P1 · Verified · L6 × checkout]** Duplicate currency rounding
`web/src/lib/money.ts:14` rounds half-up; `api/src/services/refund.ts:88`
truncates. A refund can differ from its charge by one cent, and the
discrepancy is invisible in either file alone. Canonical implementation:
money.ts (newer, tested). Fix direction: share one rounding rule.
```

Owner-question format (for intent-level findings only the owner can settle):

```
- The UI says "notifications", the API says "alerts", and the table is
  `user_messages` (`app/notifications/page.tsx:8`, `api/alerts/list.ts:21`,
  `migrations/0007.sql:3`). Which name is the product's? The other two are
  drift that will compound.
```

## Output requirements

Every run of this skill ends with:

1. The structured readiness report (per `references/report-template.md`), written to a file if the user wants an artifact, otherwise inline.
2. The outcome statements and experience qualities the verdict was graded through.
3. Findings as clickable `file:line` references.
4. The coverage statement — deep / scanned / not-covered per segment.
5. The owner-questions list for every intent-level uncertainty.
6. An honest scorecard: never inflate a layer you only scanned.
