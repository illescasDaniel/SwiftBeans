# Progress

## SDD workflow refresh (2026-10-25)

- [x] Updated `.cursor/skills/sdd-feature/` from upstream `illescasDaniel/sdd-feature-skill` commit `5443fe57ff5f0fef25d8a76f75dae64953bb9e7b` (2026-10-22), adapting design/spec/architecture gates, templates, structural checks, and independent grading to SwiftBeans package boundaries
- [x] Aligned `AGENTS.md`, `.cursor/rules/sdd.mdc`, and the SwiftBeans SDD playbooks

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

### Done (continued)

- [x] Inter-bean call diagnostic slice: `specs/inter-bean-call-diagnostic/SPEC.md`, `DirectCallAnalyzer`, `bean.directCall` warning, `GeneratorDirectCallTests` (15)
- [x] Linux fixes: generator stderr via `FileHandle` (Swift 6 rejects `fputs(_, stderr)`); `GeneratedFileWriterTests` mtime compared with 1 s tolerance (2026-10-15)

### Open

- [x] Backlog (after `@Assisted`): let beans inject assisted factories, e.g. `(Item) -> ItemDetailViewModel` — done on `cursor/factory-injection-53df` (2026-10-15)

- [x] Published as public repo `illescasDaniel/SwiftBeans`, MIT license, tag + release `0.1.0` (2026-10-15)
- [x] Tag + release `0.2.0` (qualifiers, factories, collection injection, graph dump, inter-bean diagnostic, local-package scan refresh, CI, example showcase) (2026-10-16)

### Possible future improvements (to review; each needs its own spec)

Landed on `feature/improvements` (2026-10-16) by merging draft PRs in order #3 → #4 → #2 → #7 → #6 → #5, then #1.

- [x] CI: GitHub Action (`.github/workflows/ci.yml`, `xcode-27` runner, Xcode 27.0) running `swift test` + example macOS tests and iOS Simulator build; README badge; `CHANGELOG.md` (2026-10-15). Releases stay semver `0.x` while the API may break
- [x] Factory injection (`specs/factory-injection/SPEC.md`): `(Item) -> ItemDetailViewModel` and deferred `() -> T`. Factories resolve against the unqualified provider of the return type.
- [x] Qualifiers (`specs/qualifiers/SPEC.md`): `@Bean(named:)` / `@Service(named:)` + `@Qualifier("…")`, `BeanKey`. Optional later: `accessor:` override; example-app demo
- [x] Collection injection (`specs/collection-injection/SPEC.md`): `[any P]` / `[P]` multi-bind via `ParameterInjection` (spec approval still pending). Named providers of the element type join collections by type.
- [x] Graph dump (`specs/graph-dump/SPEC.md`): `SwiftBeansGraph.md` + `SwiftBeansGraph.dot`. Future: `.swiftbeans.yml` toggle
- [x] Local-package scan refresh: generator re-resolves config + local packages every run from a `GeneratorRequest`; plugin declares folders as inputs
- [x] Inter-bean call diagnostic (`specs/inter-bean-call-diagnostic/SPEC.md`): warning `bean.directCall`
- [x] Child contexts original Phase 1 draft and architecture stub (2026-10-15); superseded by the approved 2026-10-25 spec and Phase 2 proposal below
- [x] Integration merge on `feature/improvements` + `swift test` green (201 tests / 19 suites, 2026-10-16). Example app combined check still optional.
- [ ] Pre-existing gap: an array bean's accessor drops nested `any` (`-> [any P]` generates `[P]`), which breaks under `ExistentialAny`; fixing it changes output for existing graphs, so it needs its own decision
- [x] Example app: qualifiers (`@Bean(named:)` / `@Service(named:)` / `@Qualifier`), collection injection (`[any FeatureNote]`), factories already on `AppCoordinator`. macOS `xcodebuild test` green (2026-10-16). Duplicate `printError` in `SwiftBeansGeneratorMain` fixed in the same pass (`swift test` does not build the generator executable)
- [x] Example previews use `PreviewRootView` (debug-only, custom root) so `coordinator.path` is bound; `AppRootView` is constructed only from `@main` (2026-10-16)
- [x] Child contexts system-design draft (2026-10-25): `design/child-contexts/DESIGN.md` proposes coordinator-owned login flow, transient child coordinator, optional managed teardown and A1/A2 delivery. This draft was followed by the approved design/spec/architecture and completed delivery recorded below.
- [x] Child contexts Phase 0 design approved in chat (2026-10-25): coordinator-owned flow and optional managed teardown, including MainActor restriction and resolution-after-close precondition.
- [x] Child contexts Phase 1 decisions confirmed and spec revised (2026-10-25): approved resource defaults, managed cleanup/lifetime contracts, factory/qualifier/collection/dump composition, coordinator login flow and 64 BDD scenarios. Structural spec checker passes.
- [x] Child contexts spec explicitly approved in chat (2026-10-25), including managed teardown.
- [x] Child contexts Phase 2 proposal drafted (2026-10-25): public runtime/macro signatures, separate managed registry, generator ownership/injection plans, identity witnesses, example composition and mapping for all 64 scenarios. Nonproduction contract snapshots type-check under Swift 6.4 strict concurrency with ordinary/MainActor defaults; macro signatures parse. Architecture subsequently approved in chat.
- [x] Child contexts architecture/contracts explicitly approved in chat (2026-10-25).
- [x] Child contexts runtime/macros/generator and coordinator login example implemented with initial failing tests, generated-source compiler fixtures, 20 lifecycle exit cases and plugin-backed integration coverage; full package and both example platform gates have passed before final validation refinements (2026-10-25).
- [x] Child contexts A1/A2 complete (2026-10-25): final package gate passes 284 test functions, macOS example passes 40 functions/41 executions, iOS Simulator build passes, structural/whitespace checks pass. Independent read-only review: all seven criteria PASS, no remaining findings after one verification/metadata fix round. Evidence: `specs/child-contexts/VERIFICATION.md` and `REVIEW.md`.
- [ ] Investigate Spring-style inter-bean calls (diagnostic slice done; remaining: proxies / instance `@Bean` / macro rewriting, options in `specs/inter-bean-call-diagnostic/SPEC.md` Future work) (idea from Java, 2026-10-15): in Spring a `@Configuration` class is proxied, so `repoUsuarios()` calling `conexionBaseDatos()` returns the same singleton instead of a new instance. Explore whether `@Bean` could be instance methods where `self.otherBean()` goes through the context's registry. Notes:
	- Today `@Bean` is `static` and dependencies come in as parameters, so the generated code already shares singletons; but a `@Bean` body that calls `AppConfiguration.otherBean()` directly silently creates a second instance
	- Swift has no runtime subclass proxies, and `enum`/`struct` configurations can't be overridden; candidates: macro-rewritten bodies, a configuration instance owned by the context that forwards to accessors, or generating a subclass of a `class` configuration
	- ~~Cheap first step regardless: a build diagnostic when a `@Bean` body calls another `@Bean` directly, suggesting a parameter instead~~ (done: warning `bean.directCall`)
