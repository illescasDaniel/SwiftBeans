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

### Open

- [ ] Generator: beans from local packages need the app to `import` that module somewhere, because generated imports only copy imports seen in scanned files (found 2026-10-15 in SPM fixture)
- [ ] Review #5–10 (type keys, accessor names, file:line diagnostics) and #15 (registry once-only creation)

- [ ] Push `main` when ready (optional)
- [ ] Docs / README usage polish for compile-time DI (include HTTIES `@Bean` + `AppContextProtocol` / FakeAppContext pattern)
