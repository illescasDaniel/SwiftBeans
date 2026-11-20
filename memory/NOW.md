# Now
Updated: 2026-11-20

## Doing
Repo housekeeping on `main` (unpushed): README refresh, then memory-1 and docs-1 migration. `@Service(autoInit: true)` is implemented (see [note](notes/service-auto-init-opt-in-recommended.md)): 356 tests pass, example passes on macOS and builds for iOS Simulator.
## Done recently
- Added `@Service(autoInit: true)` with `@Assisted`/`@Qualifier` property markers; independent grade passed after one fix round (commit 5446022).
- README refreshed with icon, badges, quick start and how-it-works diagram.
- Memory migrated from memory-bank to memory-1; docs indexed with docs-1.
## Next
1. User approval of the Phase 4 amendment to `specs/service-auto-init/SPEC.md` (empty-init wording, optional-`let` diagnostic ID, `@Observable` backing-storage marker exemption). Pending.
2. Push `main` (user-queued; not done: no push without the user).
3. Get CI green on GitHub (workflow `ci.yml`, runner `xcode-27`).
4. Release 0.3.0 (user-queued; `CHANGELOG.md` still has everything under Unreleased, latest tag is 0.2.0).
5. Update the Steady app to 0.3.0 and adopt auto-init (user-queued).
## Open questions / blocked
- Phase 4 spec amendment awaits the user's approval (see Next 1).
