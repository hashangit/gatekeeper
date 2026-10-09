# Report Template

The report is the deliverable. Writing rules: lead with the verdict; every finding carries evidence and severity; no filler; strengths get named — an audit that only lists problems misrepresents the product. Write to a file (e.g. `PRODUCT-REVIEW.md` in the repo root) when the user wants an artifact, otherwise inline.

---

```markdown
# Product Review — <product name>

**Verdict:** 🔴 Not ready / 🟡 Ready with conditions / 🟢 Ready
**Readiness bar applied:** <demo MVP / internal tool / production SaaS — state which, and why>
**Reviewed at:** <commit hash + date>
**Scope:** <path(s) reviewed>

## Executive summary

3–6 sentences. The verdict, the one-line reason, and the 2–3 findings that
dominate the decision. A reader who stops here still knows what to do.

## Outcome statements

What this product exists to do for people — the human lens the verdict is
graded through (from Phase 1 / L0):

- "A freelancer uses Invoicely so that clients pay them faster" —
  outcome test: **fails** (flow ends at "sent"; nothing supports payment
  after it — see Top findings #1)
- Experience qualities promised: *effortless, trustworthy* —
  onboarding **contradicts** effortless (12 fields + email verify before
  first value); payments **carry** trustworthy (confirmation + undo window)

## Coverage statement

| Segment | Depth | Notes |
|---|---|---|
| auth | deep | every file read |
| checkout + payments | deep | every file read |
| admin UI | scan | tooling + spot reads |
| background jobs | not covered | queue infra unreachable in this environment |

Be blunt here. The verdict is only as trustworthy as this table.

## Readiness scorecard

| Layer | Score /10 | One-line basis |
|---|---|---|
| Product & experience (L0–L3) | 5 | flagship outcome undelivered past "send"; journeys otherwise solid |
| Code & structure (L4–L6) | 7 | clean layering; 3 duplicate paths, 1 divergent |
| Risk & resilience (L7–L9) | 4 | IDOR on two endpoints; no ownership checks |
| Confidence & ops (L10–L12) | 5 | happy-path tests only; no rollback path |

## Top findings

The prioritized shortlist — typically 3–8 items. Full detail lives below;
this section is what gets acted on first.

1. **[P0 · Verified · L7]** IDOR on order history —
   `api/orders/list.ts:22` filters by the query param's user ID, not the
   session user; user A can read user B's orders by changing `?userId=`.
2. **[P1 · Verified · L6]** Duplicate currency rounding (web vs refund service)…
3. …

## Findings by layer

### Layer 1 · Product & experience

**[P0 · Verified · L0 × flagship]** Outcome failure —
positioning promises "get clients paid faster" (`src/pages/Landing.tsx:31`),
but the flow ends at send: no payment tracking, reminders, or
reconciliation past the send button (last state change is
`src/invoice/Send.tsx:88`). Functionality complete; outcome undelivered.

**[P1 · Verified · L1 × docs]** Claimed feature absent —
the README promises CSV export (`README.md:14`); no export code exists
anywhere in `src/` (surface inventory, Phase 2).

**[P2 · Verified · L3 × settings]** No error state on profile save —
`src/pages/Settings.tsx:88` catches the fetch error and renders nothing;
users see a frozen spinner. Loading and empty states are present; error is missing.

…(one block per finding, in every layer reviewed)

### Layer 2 · Code & structure
### Layer 3 · Risk & resilience
### Layer 4 · Confidence & operations

## What's genuinely good

- <evidence-backed strengths: "single validation module used by all 14
  endpoints — the one concern with zero duplication", "auth has complete
  ownership checks on 21 of 23 routes — the 2 misses look like oversights,
  not a missing pattern">
- Strengths anchor the report's credibility and tell the team what to
  keep doing — and what to spread further.

## Questions for the product owner

Intent-level findings only the owner can settle. Present divergence with
evidence on both sides; never as accusations.

- UI says "notifications", API says "alerts", table is `user_messages`
  (`app/notifications/page.tsx:8`, `api/alerts/list.ts:21`,
  `migrations/0007.sql:3`). Which name is the product's?
- The old upload flow (`/upload-v1`) is still fully reachable beside the
  new one (`/uploads`). Is v1 pending removal or still needed by
  integrations?
- What outcome is the tags feature meant to deliver? No positioning
  reference, no dependent feature in the surface inventory, no outcome
  statement (L0). Purpose orphan — remove it, or did we lose the thread?

## Action plan

### Before any release (P0/P1)
1. <fix + verification step, smallest sufficient action first>

### Short-term (P2)
1. …

### Housekeeping (P3)
1. …

## Appendix

- Debt-marker census: <count, clusters, oldest>
- Dependency audit output summary
- Duplicate-path matrices (from L6)
- Commands run and tools used (so the audit is reproducible)
```

---

## Finding format (reference)

```
**[Severity · Confidence · Lens × segment]** One-line title —
evidence `file:line`, what it means, why it matters, fix direction.
```

Every finding must be able to answer five questions in two sentences:
*Where is it? What does it do? What goes wrong because of that? How bad
is it? What direction fixes it?* If a finding can't, it isn't ready to
report — either sharpen it or drop it.

## Tone calibration

- Report observations, not judgments about people: "the check is missing
  on these two routes", never "the developer forgot".
- Prefer the charitable reading when intent is ambiguous — route those to
  the owner-questions list instead of the findings list.
- Never soften a P0. Never inflate a P3 to look thorough. The report's
  value is its calibration.
