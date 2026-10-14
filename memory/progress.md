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

- [x] `Examples/SwiftBeansIOSExample/` builds with `SwiftBeansPlugin` (iPhone 16 / iOS 18.6 sim)

### Done (continued)

- [x] Fix example SwiftUI Previews (`NoBuildableEntriesError`): iOS-only scheme, selective `Packages/SwiftBeans` links, Simulator destination
- [x] Fix nested singleton registry crash (`_os_unfair_lock_recursive_abort` → create-outside-lock)

### Done (continued)

- [x] Commit Phase 2–4 + example; ignore nested `.build/` / `DerivedData/`

### Open

- [ ] Push `main` when ready (optional)
- [ ] Docs / README usage polish for compile-time DI
