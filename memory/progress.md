# Progress

## Bootstrap (2026-10-14)

### Done

- [x] Copy non-UI skills from GamesLibrary
- [x] Add MCP config (`codenav-swift`, `xcode-tools`)
- [x] Add memory bank + agent rules + SDD adaptations
- [x] Add `memory-bank` skill + `jevmem` MCP / `jev-memory` skill

### Done (continued)

- [x] Enable and smoke-test MCP servers (`codenav-swift`, `xcode-tools`, `jevmem`)

### Done (continued)

- [x] Phase 1: Approve `specs/compile-time-di/SPEC.md` (compile-time DI + plugin scan)

### Done (continued)

- [x] Phase 2: Approve architecture (`specs/compile-time-di/ARCHITECTURE.md`)
- [x] Phase 2 contracts: `BeanScope` / `SwiftBeansScanConfiguration`

### Done (continued)

- [x] Phase 3: BDD-mapped tests + `SwiftBeansGeneratorCore`
- [x] Phase 4: Macros + parser + codegen + generator CLI + `SwiftBeansPlugin` (`swift test` green)

### Done (continued)

- [x] `Examples/SwiftBeansExample/` builds with `SwiftBeansPlugin` (iPhone 16 / iOS 18.6 sim)

### Done (continued)

- [x] Fix example SwiftUI Previews (`NoBuildableEntriesError`): selective `Packages/SwiftBeans` links; later re-enabled My Mac
- [x] Fix nested singleton registry crash (`_os_unfair_lock_recursive_abort` → create-outside-lock)

### Done (continued)

- [x] Commit Phase 2–4 + example; ignore nested `.build/` / `DerivedData/`

### Done (continued)

- [x] Example multiplatform (iOS + macOS): My Mac run + Previews; rename to `SwiftBeansExample`

### Done (continued)

- [x] Example: coordinator navigation + full DI feature demo (`@Configuration`/`@Bean`, scopes, protocol bind)
- [x] Example unit tests (`SwiftBeansExampleTests`) + package test coverage gaps filled (`swift test` / example `xcodebuild test` green)
- [x] Example: HTTIES + JSONPlaceholder (fake handler / live `URLSession`) via `@Bean`; generator fixes for `any` accessors + imports

### Done (continued)

- [x] Generate `{Context}Protocol` (e.g. `AppContextProtocol`) + example `FakeAppContext` / Previews / tests

### Done (continued)

- [x] Project review (2026-10-15); plugin source-discovery fix (review #1–4): SPEC, ARCHITECTURE, tests, implementation, example rename

### Done (continued)

- [x] Review #5–11, #13–16: generator rules (keys, nesting, initializer selection, imports, local-package auto-import), positioned diagnostics, macro diagnostics, `@Inject`, registry once-only (2026-10-15)

### Done (continued)

- [x] Example as generated-code compile check: local package `Packages/GreetingKit` (`GreetingKitLive` auto-imported), nested `Features.WelcomeBanner`, `[String: Int]` `@Bean` consumed as `Dictionary<String, Int>`, `@Inject` on `TagSummary` (2026-10-15)

### Done (continued)

- [x] Runtime arguments (`@Assisted`): Phases 1–4 done (2026-10-15). `Assisted` wrapper, `isAssisted` rules, scanner/resolver/validator/codegen, `GeneratorAssistedTests`; example `ItemDetailViewModel` uses `itemDetailViewModel(item:)` (`swift test` 133 tests green; example `xcodebuild test` + iOS Simulator build green)

### Done (continued)

- [x] Example-app review fixes: Swift 6 mode, `@State` view models, no context in views, `LoadState` (tests assert state, not copy), throwing repository, `#if DEBUG` fakes + Previews, Release uses `URLSession.shared` (2026-10-15)
- [x] Product surface: `SwiftBeansGeneratorCore` no longer a product, `package` access; `BeanScope` split closed as unnecessary (2026-10-15)
- [x] README with installation, concepts, scopes, `@Inject`, `@Assisted`, `{Context}Protocol` fakes, `.swiftbeans.yml`, rules (2026-10-15)
- [x] `.claude/skills` and `.claude/rules/*.md` symlinked to `.cursor/` (2026-10-15)

### Open

- [ ] Backlog (after `@Assisted`): let beans inject assisted factories, e.g. `(Item) -> ItemDetailViewModel`, so a bean (coordinator) can create assisted objects without holding the context

- [ ] Push `main` when ready (optional)
