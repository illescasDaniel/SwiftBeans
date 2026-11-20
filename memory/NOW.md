# Now
Updated: 2026-11-20

## Doing
Repo housekeeping on `main` (unpushed): README refresh, then memory-1 and docs-1 migration. `@Service(autoInit: true)` is implemented (see [note](notes/service-auto-init-opt-in-recommended.md)): 356 tests pass, example passes on macOS and builds for iOS Simulator.
## Done recently
- Added `@Service(autoInit: true)` with `@Assisted`/`@Qualifier` property markers; independent grade passed after one fix round (commit 5446022).
- README refreshed with icon, badges, quick start and how-it-works diagram.
- Memory migrated from memory-bank to memory-1; docs indexed with docs-1.
## Next
1. Push `main`, then
2. Get CI green on GitHub (workflow `ci.yml`, runner `xcode-27`).
3. Tag and release 0.3.0 (CHANGELOG and README pin are prepared).
4. Update the Steady app to 0.3.0 and adopt auto-init (user-queued).
## Open questions / blocked
- None. The Phase 4 spec amendment was approved 2026-11-20.
