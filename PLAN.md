# Quick wins

Survey completed before implementation. Work on `codex/quick-wins-audit`; keep each
logical change in its own commit. No deployments, provider calls, migrations against
existing databases, public API changes, or dependency upgrades.

1. **Accounts:** validate bcrypt's 72-byte password limit before hashing, including
   validation-only changesets; reject overlong login input rather than matching a
   truncated password. Add boundary and multibyte regression tests.
2. **Browser audio:** release playback blob URLs on success and failure; verify with
   Node's built-in test runner and mocked browser APIs.
3. **Browser charts:** destroy Chart.js instances when LiveView removes their hooks,
   preventing retained canvases/listeners during navigation; verify hook lifecycle.

Run focused checks after each change, then the full build/test commands and asset
build. Revert changes that cannot be independently validated. Record baseline
failures separately; do not rewrite the obsolete suite or upgrade the runtime as
part of a quick win. The requested green full-suite gate is required for a complete
closeout, and must not be claimed if baseline problems prevent it.

See `docs/CODEBASE_REVIEW.md` for the survey, candidate backlog, and final outcomes.
