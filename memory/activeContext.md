# Active Context

_Last updated: 2026-10-15_

## Branch

- `main`

## Current focus

Review backlog cleared (2026-10-15): example-app fixes, product surface (`SwiftBeansGeneratorCore` no longer a product, `package` access), README written, `.claude` symlinks to `.cursor` skills/rules. All uncommitted; `@Assisted` is committed (`25e0b04`). Verified: `swift test` 133, example macOS tests, iOS Simulator and Release builds.

## Just changed

- Example: Swift 6 mode, `@State` view models, `LoadState`, throwing `ItemRepository`, `#if DEBUG` fakes and Previews, Release `URLSession.shared`
- `Package.swift`: products are only `SwiftBeans` + `SwiftBeansPlugin`
- `README.md` (new)

## Next steps

1. Commit this batch when asked
2. Spec assisted-factory injection (`(Item) -> ItemDetailViewModel`) — Phase 1
3. Optional: push `main`
