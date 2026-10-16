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

### Done (continued)

- [x] Inter-bean call diagnostic slice (branch `cursor/inter-bean-call-diagnostic-53df`): `specs/inter-bean-call-diagnostic/SPEC.md`, `DirectCallAnalyzer`, `bean.directCall` warning, `GeneratorDirectCallTests` (15); generator `stderr` fixed for Linux; `GeneratedFileWriterTests` date comparison made tolerant on Linux

### Open

- [ ] Backlog (after `@Assisted`): let beans inject assisted factories, e.g. `(Item) -> ItemDetailViewModel`, so a bean (coordinator) can create assisted objects without holding the context

- [x] Published as public repo `illescasDaniel/SwiftBeans`, MIT license, tag + release `0.1.0` (2026-10-15)

### Possible future improvements (to review; each needs its own spec)

Suggested order: CI first, then factory injection, then qualifiers.

- [x] CI: GitHub Action (`.github/workflows/ci.yml`, `xcode-27` runner, Xcode 27.0) running `swift test` + example macOS tests and iOS Simulator build; README badge; `CHANGELOG.md` (2026-10-15). Releases stay semver `0.x` while the API may break
- [ ] Factory injection (same item as the backlog above): `(Item) -> ItemDetailViewModel` and deferred `() -> T` (expensive objects, breaking cycles)
- [ ] Qualifiers: `@Bean(named: "snakeCase")` / `@Service(named:)` + `@Qualifier("snakeCase") decoder: JSONDecoder`. Notes from the 2026-10-15 discussion:
	- Key is (type, qualifier), not a global name: `snakeCase` on `JSONDecoder` and on `JSONEncoder` are different beans
	- Unqualified bean is the default; unknown (type, name) pair is a build error at the parameter; names must be string literals
	- Unqualified parameter with only named beans of that type → build error (no implicit single-candidate pick)
	- Accessor = qualifier + type (`snakeCaseJSONDecoder`); collision with a real type's accessor is a build error at both declarations (no numeric suffixes: unstable, unreadable). Maybe later: `accessor:` override
	- `@Qualifier` as a marker property wrapper on parameters (same trick as `@Assisted`); works with protocol-bound beans; `{Context}Protocol` gains qualified accessors
	- Acceptance criterion: a graph without qualifiers generates byte-identical output to today
- [ ] Collection injection: `[any AnalyticsTracker]` receives every bean bound to that protocol (trackers, interceptors, plugins)
- [ ] Graph dump: plugin emits a Markdown/DOT file of the resolved graph for debugging and onboarding
- [x] Fix known limitation: a new file in a local package may need a clean build before it joins the graph (2026-10-15): generator re-resolves config + local packages every run from a `GeneratorRequest`; plugin declares folders as inputs (SwiftPM rejects source-built prebuild commands; see decisions). Xcode behavior unverified (no Xcode on Linux)
- [ ] Later / bigger: child contexts (e.g. a logged-in-user scope created and destroyed at runtime)
- [ ] Investigate Spring-style inter-bean calls (diagnostic slice done, see Done; remaining: proxies / instance `@Bean` / macro rewriting, options in `specs/inter-bean-call-diagnostic/SPEC.md` Future work) (idea from Java, 2026-10-15): in Spring a `@Configuration` class is proxied, so `repoUsuarios()` calling `conexionBaseDatos()` returns the same singleton instead of a new instance. Explore whether `@Bean` could be instance methods where `self.otherBean()` goes through the context's registry. Notes:
	- Today `@Bean` is `static` and dependencies come in as parameters, so the generated code already shares singletons; but a `@Bean` body that calls `AppConfiguration.otherBean()` directly silently creates a second instance
	- Swift has no runtime subclass proxies, and `enum`/`struct` configurations can't be overridden; candidates: macro-rewritten bodies, a configuration instance owned by the context that forwards to accessors, or generating a subclass of a `class` configuration
	- ~~Cheap first step regardless: a build diagnostic when a `@Bean` body calls another `@Bean` directly, suggesting a parameter instead~~ (done: warning `bean.directCall`)
