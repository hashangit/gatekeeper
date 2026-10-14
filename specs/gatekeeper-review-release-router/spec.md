# Gatekeeper Review and Release router

## Goal

Ship a standalone Review skill with the complete original Gatekeeper review flow,
retain the release flow, and route ambiguous Gatekeeper requests to Review.

## Requirements

- Provide three independently installable skills: Gatekeeper router, Gatekeeper
  Review, and Gatekeeper Release.
- Review includes all six phases, all seven reviewer mandates and switches, fresh
  sessions, committed-HEAD seal, work-order task truth, computed verdict, receipt,
  and the two-repair limit.
- Review never creates commits or performs release operations. Uncommitted changes
  block the gate.
- Release requires an explicit user request or confirmation before entering, and
  explicit user consent for each set of release mutations and target.
- Keep reviewer mandates and credited source skills unchanged.
- Validate every standalone installation and the plugin release tag.
