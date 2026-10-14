## [1.1.0] - 2026-10-14

### Fixed
- Reject unrelated files staged during release-notes editing
- Close verified release blockers (gatekeeper-review-release-router)
- Parse sealed receipt hashes correctly
- Harden release gates and receipts (gatekeeper-review-release-router)

### Added
- Split review and release skills (gatekeeper-review-release-router)

### Known issue
- Keep the review receipt unchanged during publishing; the helper validates its verdict at startup.
