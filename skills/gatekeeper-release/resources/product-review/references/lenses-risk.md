# Layer 3 — Risk & Resilience Lenses (L7–L9)

## L7 · Security

**Core question:** what can an attacker — or just a curious user with dev tools — reach?

Work trust boundaries first: every place input crosses from untrusted to trusted (HTTP handlers, webhook receivers, file uploads, queue messages, URL params). Then work outward.

### Checks

1. **Authentication.** How identity is established and maintained: token/session storage (`localStorage` tokens are readable by any XSS; httpOnly cookies are the bar for browser apps); expiry and refresh semantics; logout invalidating server-side state; password reset token entropy, expiry, and one-time use.
2. **Authorization — the IDOR sweep.** For every handler touching an entity by ID, is *ownership* checked server-side? Run the swap-ID mental test per route: user A requests user B's resource by changing the ID in the URL/body — what stops them? Do this exhaustively on list/get/update/delete. Then the admin sweep: is the admin check present on **every** admin route, or only on the menu that links to them? Missing ownership checks on real user data = P0.
3. **Injection.** Raw SQL or ORM escape hatches with interpolated input (`.raw(`, string-built queries, f-string SQL); command execution touching user input; template injection; path traversal on file access by user-supplied name (`../../`).
4. **XSS.** `dangerouslySetInnerHTML` / `v-html` / unescaped template output rendering user-controlled content; markdown/HTML rendering pipelines without sanitization; rich-text editors storing raw HTML.
5. **SSRF & redirects.** Server fetching user-supplied URLs (webhooks-by-URL, "import from URL" features, image-by-URL); redirects to user-controlled parameters.
6. **Input validation at the boundary.** Everything validated server-side (client-side validation is UX, not security); body/upload size limits; type-coercion surprises (string "0" vs number 0, array-vs-object params); mass-assignment (client able to set fields it shouldn't, e.g. `role` or `price`).
7. **Secrets.** In the repo (working tree *and* git history — secrets "removed" in a later commit are still there); in the client bundle (anything imported by client code is public — grep the built bundle); in logs; default credentials; `.env` files committed; credentials shared between environments.
8. **Data exposure.** API responses over-fetching (password hashes, internal IDs, other users' data in list responses); verbose errors/stack traces returned to clients; PII in URLs (it lands in logs, proxies, and browser history).
9. **Rate limiting & abuse.** Auth endpoints (brute force, credential stuffing), expensive endpoints (search, exports, anything calling paid APIs), write endpoints. Missing throttling on auth = P1; elsewhere P2 unless it enables financial abuse.
10. **Crypto hygiene.** Password hashing with bcrypt/argon2 (not md5/sha1/plaintext — not even sha256+salt, it's not a password function); tokens from crypto-random sources (not `Math.random`); any homemade crypto or encoding-used-as-crypto (`base64` is not encryption).
11. **Dependency reachability.** Run the ecosystem audit (see detection-techniques.md). Report *reachable* vulnerable deps at their face severity; unreachable ones as P2 with the reachability caveat.
12. **Insecure defaults.** CORS `*` (especially with credentials); debug modes on by default; TLS verification disabled (`NODE_TLS_REJECT_UNAUTHORIZED=0`, `verify=False`); cookies without Secure/HttpOnly/SameSite; permissive Content-Security-Policy absent while rendering user HTML.

Severity guide for this lens: auth bypass, IDOR on real data, secret in the client bundle, test backdoor in prod = **P0**. Missing rate limit on auth, weak token entropy, SSRF = **P1**. Verbose errors, missing cookie flags, PII in logs = **P2**.

## L8 · Error Handling & Resilience

**Core question:** what happens when something fails halfway?

### Checks

1. **Error taxonomy.** Is there one way errors are shaped, propagated, and surfaced? Or does each module improvise (throws here, returns null there, sets a flag elsewhere)? No taxonomy is itself an L6 finding that this lens inherits.
2. **Swallowed errors.** Empty catch blocks; catch-and-log-only where the caller *needed* to know; `.catch(() => {})`; `except: pass`. On a core path, a swallowed error converts a visible failure into silent data corruption — P1 minimum.
3. **Partial failure.** Multi-step operations without transaction or compensation: charge the card then fail to record the order; create the user then fail to send the setup email with no retry path. Walk every flow that writes in more than one place and ask what state exists if each step individually fails. Unhandled partial failure on money/data-loss paths = P0/P1.
4. **Timeouts & retries.** Every external call (HTTP, DB, third-party API) has a timeout — default no-timeout is a production outage waiting for a slow dependency. Retries: present where appropriate, with backoff and a cap; no retry storms; idempotency keys where retries can double-apply a write.
5. **Race conditions.** Double-submit (same form firing twice → two orders); concurrent edits (last-write-wins on data that deserves merging or locking); check-then-act patterns on shared state ("if not exists then create" without a unique constraint — also an L9 finding).
6. **Resource leaks.** Connections/streams/file handles not closed on error paths; frontend listeners added per render and never removed; intervals never cleared. Leaks are slow-burn P2s that become P1 incidents in long sessions/processes.
7. **Graceful degradation.** Optional dependencies (analytics, email, feature-notification systems) failing must not kill the core path. Find the try/catch boundaries — or their absence — around optional work.
8. **Edge-case sweep on core paths.** Empty collections; null/undefined/missing fields; zero and negative numbers; unicode/emoji in names (length limits counted in bytes vs chars); timezone and date boundaries (DST, month-end, "today"); pagination past the end; very long strings; two entities created with the same natural key simultaneously.
9. **Failure UX.** When something fails, does the user get a next action or a stack trace? (Cross-references L3 — one problem, two lenses; report once with both tags.)

## L9 · Data Integrity

**Core question:** can the data silently become wrong?

Silent is the operative word — integrity failures don't crash, they corrupt.

### Checks

1. **Schema honesty.** Does the database enforce what the domain assumes? `NOT NULL` where business rules require a value; `UNIQUE` where identity is claimed; foreign keys where references exist; cascade rules matching intended delete semantics. A schema that enforces nothing and an app layer that forgot a check somewhere = orphaned or duplicated records. Gaps on core entities = P1.
2. **Validation layering.** Where is validation enforced: one shared boundary (good), duplicated client+server with drift between them (L6 finding with a security edge — L7), or client-only (P0-flavored L7 finding)? The check: submit an invalid entity through the API directly, bypassing the UI, in a test — does anything stop it?
3. **Migration safety.** Destructive operations guarded (backups, dry-runs, or staged rollouts); data migrations accompanying schema changes that require them; deploy ordering (new code before/after the migration it needs — the expand/contract pattern for zero-downtime); are down-migrations written, and do they preserve data?
4. **Transactionality.** Multi-table or multi-service writes atomic where the domain requires all-or-nothing. In distributed flows: at least a documented compensation or outbox approach — or an explicit finding.
5. **Canonical source.** The same fact stored in more than one place without a sync mechanism: counters maintained beside lists, denormalized copies without invalidation, status fields duplicated across services. Each is a future inconsistency — P2 now, P1 once they first disagree.
6. **Deletion semantics.** Hard vs soft delete — consistent across entities? Orphan production after deletion (comments surviving their deleted parent where FKs are absent). "Delete account" that leaves personal data scattered across side tables is both an integrity and a compliance finding.
7. **Audit trail.** created/updated timestamps maintained automatically (DB defaults/triggers, not app-code on its best behavior)? Who-did-what recorded for destructive and money actions? Absent audit on money paths = P1 for a production bar.
