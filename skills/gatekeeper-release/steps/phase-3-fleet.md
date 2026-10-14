# Phase 3 — the fleet

Each reviewer is a **separate fresh-session subagent**. It receives three things and
nothing else:

1. The seal SHA.
2. The brief — work order + the spec's FR/SC list.
3. Its mandate file from `../reviewers/` — never the implementer's commentary.

Depth follows risk; policy decides who wakes, never the implementer. The dispatch
table lives in the active workflow ("Who wakes").

Mechanics:

- **Honor the switches first.** The active workflow's reviewer switches decide who is
  even eligible; the risk table then decides who of those wakes. A disabled reviewer
  is skipped silently in dispatch but named in the receipt.
- Reviewers run as **subagents when the harness supports it** — separate fresh
  sessions, concurrently where the roles are independent. If concurrency is
  unavailable, run independent fresh reviewer sessions in strict sequence. If fresh sessions cannot be created, report BLOCKED; separate passes in
  the same conversation do not provide isolation.
- When enabled, the Architect does **not** wake with the others; it joins in Phase 4
  after findings are verified.
- Collect each reviewer's findings verbatim; the gate keeper merges in Phase 4.
- If a reviewer could not run (rate limit, tooling), say so in the receipt and cover
  its surface another way — a silent gap is a false PASS.
