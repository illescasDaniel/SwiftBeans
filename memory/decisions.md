# Decisions

## 2026-10-25 — SDD workflow uses separate design, spec, and architecture gates

**Context:** SwiftBeans is a growing Swift package with runtime, macro, generator, plugin, and example seams; the prior workflow centered on specs and contracts but did not define a design phase or an independent conformance grade.

**Decision:** Require a design artifact for public API and intentional behavior changes, then separate explicit approval gates for design, spec, and architecture, followed by scenario-mapped tests, implementation, and independent read-only grading. Small internal-only changes may request approval to skip design.

**Rationale:** The sequence makes package boundaries, compatibility, failure behavior, and acceptance criteria reviewable before implementation, while independent grading checks conformance beyond test results.

## 2026-10-25 — Example session ownership separated from screen construction

**Context:** Authentication cancellation/admission and managed logout had accumulated in AppCoordinator. Forwarding session members or exposing coordinator.session still made the coordinator the access point for session concerns.

**Decision:** The user selected separate app-owned AppSession and AppCoordinator composition. The coordinator receives a sign-in action; root presentation observes the session directly and signed-in UI receives logout/expiry callbacks. AppSession uses one explicit lifecycle state while LoginViewModel retains its separate presentation-request identity.

**Rationale:** Screen construction depends on the action it needs, without a session property or mirrored presentation state. One lifecycle owner preserves stale-result rejection and the cleanup admission barrier, and action callbacks remove the signed-in UI's root coordinator environment dependency.

## 2026-10-25 — Child-context architecture approved and managed lifecycle delivered

**Context:** The user explicitly approved the child-context architecture after the design/spec approvals. Login-scoped objects can remain externally retained after logout, so cleanup completion must be independent of their ARC deallocation.

**Decision:** Deliver A1/A2 with a separate MainActor `SwiftBeansManagedRegistry`; preserve the existing root/ARC registry. Managed close runs one unstructured actor-isolated cleanup task shared by all callers, enrolls instantiated own singleton identities once, and guards subsequent generated resolutions and retained factories. The example root coordinator owns a flow containing the context and transient child coordinator. Compiler identity witnesses validate unresolved qualified context references without guessing Xcode module names.

**Rationale:** This keeps existing root behavior and locking intact, avoids new unsafe sendability promises, makes waiter cancellation unable to abandon cleanup, and preserves the example's existing factory/build composition. Solely owned beans release normally; externally retained beans follow their service-defined inactive behavior and eventual ARC lifetime.

## 2026-10-25 — Child-context spec approved, including managed teardown

**Context:** The revised spec brings coordinator-owned login flows and optional managed cleanup into initial delivery alongside child dependency graphs.

**Decision:** The user explicitly approved `specs/child-contexts/SPEC.md` and the managed teardown option. Phase 2 proposes a separate MainActor managed registry and compiler-checked public/consumer contract snapshots; those architecture choices still require separate approval.

**Rationale:** The approved spec fixes cleanup participation, close idempotency, resolution boundaries and escaped-reference limits before implementation. Separating architecture approval lets the runtime/cache and actor-safe factory contracts be reviewed without changing those behaviors.

## 2026-10-25 — Child-context resource budget: structural limits before timing thresholds

**Context:** Child graphs need explicit build/runtime constraints, but the package has no agreed performance benchmark baseline and user-defined async cleanup controls close duration.

**Decision:** The user confirmed preservation of root-only generated output, no additional whole-source scan per child, lifecycle bookkeeping proportional to instantiated child singletons and cleanup proportional to participating objects. Do not set an initial absolute millisecond/graph-size cap or fixed callback-duration budget. Record structural checks and representative comparisons in the architecture/test plan.

**Rationale:** These constraints prevent repeated scanning and unnecessary lifecycle work while keeping acceptance independent of machine speed and application callback latency.

## 2026-10-25 — Child-context design approved: coordinator flow and managed cleanup

**Context:** The app example builds screens through injected factories. A login-scoped dependency graph also needs a defined boundary for stopping session work when outgoing UI still retains a model or repository.

**Decision:** The user approved `design/child-contexts/DESIGN.md`: the root coordinator owns a flow containing a child context and transient child coordinator; ARC is default, with optional managed cleanup of instantiated child singletons. Managed contexts initially use MainActor; generated resolution fails a precondition after closing starts. Initial delivery comprises child graphs (A1) and managed cleanup plus the login example (A2).

**Rationale:** This preserves existing factory/build conventions, avoids caching a context-retaining coordinator in that context, and gives logout one awaited cleanup boundary. Cleanup can stop owned work without claiming to force deallocation of escaped references. Design approval does not approve the spec or architecture.

## 2026-10-25 — SDD workflow: design, spec, architecture gates and independent grade

**Context:** The local SDD skill had four phases (spec, architecture, tests, implementation), while the upstream `illescasDaniel/sdd-feature-skill` revision added a system-design deliverable, explicit decision review, structural checks, and post-implementation conformance grading.

**Decision:** Adopt upstream commit `5443fe57ff5f0fef25d8a76f75dae64953bb9e7b` as the workflow baseline, adapted for SwiftBeans. API/behavior changes use separate design, spec, and architecture approval gates; tests map to approved Given/When/Then criteria; implementation is followed by independent read-only grading. No UI track is used. Design skips for small internal-only changes also require approval.

**Rationale:** The design phase surfaces module and generated-code seams before the spec is frozen, the spec records compatibility and failure decisions, and independent grading checks that tests assert the approved outcomes. SwiftBeans-specific templates keep this useful for a package with runtime, macros, generator, and plugin targets without importing app-only workflows.

## 2026-10-16 — feature/improvements: merge order and BeanKey cross-feature seams

**Context:** Seven draft PRs (local-package scan, inter-bean diagnostic, graph dump, qualifiers, factory injection, collection injection, child-contexts SPEC) needed a single integration branch without closing the PRs.

**Decision:** Create `feature/improvements` from `main` and merge in order #3 → #4 → #2 → #7 → #6 → #5, then #1. Qualifiers (`BeanKey`) land before factory and collection so those features adapt once. On the stack: factories resolve against the **unqualified** provider of the return type (`BeanKey(type)`); collection membership is by **type** (and declared conformances), so named providers of an element type join `[any P]` / `[P]`. Plugin keeps `--request` from #3 and adds `--graph-markdown` / `--graph-dot` from #2.

**Rationale:** Landing `BeanKey` before factories/collections avoids rebasing those PRs twice. Unqualified factory lookup and type-based collection membership match the qualifier rules (no silent pick of a sole named bean for a plain parameter; collections still gather every implementation of `P`).

## 2026-10-15 — Local package scan: generator re-resolves every run; prebuild rejected by SwiftPM

**Context:** `createBuildCommands` froze the local-package file list at plan time, so a new `.swift` file in a `.swiftbeans.yml` package needed a clean build. The planned fix was a `prebuildCommand` that runs every build.

**Decision:** SwiftPM refuses prebuild commands whose executable is built from source (`a prebuild command cannot use executables built from source, including executable target 'SwiftBeansGenerator'`, same with `--build-system swiftbuild`). Kept a `buildCommand`, but moved all scan decisions into the generator: the plugin writes `SwiftBeansRequest.json` (`GeneratorRequest`: scan root, target sources, config name) and the generator (`SwiftBeansGeneration.generate(request:)`) re-reads `.swiftbeans.yml` and re-walks `Sources/<target>/` on every run, reporting config errors as `config.invalid` diagnostics. The plugin declares the scan root, config, local package files and their *folders* as inputs, so adding/removing a file (folder mtime) reruns the generator. Output stays byte-stable via `GeneratedFileWriter`.

**Rationale:** Verified with an SPM test app: new files in existing/nested folders, a new subfolder, a config created or edited later all regenerate without a clean build; a no-op rebuild leaves the output untouched. A binary-target generator (artifact bundle per release) would allow a true prebuild but is a separate effort. Residual edge cases and the Xcode behavior (not testable on Linux) are documented under SPEC Known limitations.
## 2026-10-15 — Inter-bean direct calls: warning, not error, no runtime change

**Context:** Spring proxies `@Configuration` so inter-bean calls return the shared singleton; SwiftBeans `@Bean`s are static, so `Config.otherBean()` inside a `@Bean` silently builds a second instance.

**Decision:** Add a generator-only warning `bean.directCall` (`DirectCallAnalyzer`, after scan/resolve) for calls to a known `@Bean` from `@Bean` bodies and `@Service` initializer bodies (`Type.bean()`, `Self.bean()`, bare `bean()`), with a note at the callee. Matches by base name and type spelling; ambiguous or self calls are skipped. Severity is a warning. Proxies, instance `@Bean`, and macro rewriting stay out of scope (options recorded in the SPEC).

**Rationale:** Cheapest useful step with no change to generated output or public API. A warning avoids breaking builds on false positives of a spelling-based match (typealiases, local shadowing) until there is data to justify an error.
## 2026-10-15 — Graph dump files are written by the generator but not declared as plugin outputs

**Context:** Graph dump adds `SwiftBeansGraph.md` / `SwiftBeansGraph.dot` next to `SwiftBeansGenerated.swift`. Declaring them in the build command's `outputFiles` made SwiftPM copy them into a `<Package>_<Target>.bundle` (unknown output types become resources), giving every consumer target a resource bundle.

**Decision:** The plugin passes `--graph-markdown` / `--graph-dot` paths to the generator but lists only `SwiftBeansGenerated.swift` in `outputFiles`. v1 always emits on success; no `.swiftbeans.yml` toggle yet.

**Rationale:** A resource bundle in app targets is a worse side effect than the build system not tracking a debug artifact. Trade-off: deleting a graph file by hand does not rerun the generator until an input changes. Content is generated in `SwiftBeansGeneratorCore` (`GraphDump`) so it is unit-tested from fixture sources.
## 2026-10-15 — Qualifiers: key is (TypeKey, name?), accessor is name + type

**Context:** Apps need several beans of one type (two `JSONDecoder`s). Spring-style global names collide across types; numeric accessor suffixes are unstable.

**Decision:** Introduce `BeanKey` = `(TypeKey, qualifier: String?)`. `named:` on `@Bean`/`@Service` and `@Qualifier("…")` on parameters (property-wrapper marker like `@Assisted`). Accessor = qualifier + type pieces (`snakeCaseJSONDecoder`). Unqualified params never pick a sole named candidate. Name literals must be identifier-shaped. Graphs with no qualifiers stay byte-identical.

**Rationale:** Matches the 2026-10-15 backlog notes; keeps diagnostics and `{Context}Protocol` per-key; avoids global name registries and suffix churn.
## 2026-10-15 — Factory injection: lazy edges, positional type matching, strong context capture

**Context:** Beans (e.g. a coordinator) had to hold the whole context to create assisted view models or defer expensive beans.

**Decision:** Function types are accepted only as dependency parameters. `(P…) -> R` binds to `R`'s assisted method when the assisted parameter types equal `P…` positionally (canonical spelling; labels ignored), and `() -> R` binds to `R`'s plain accessor. Both emit closure literals (`{ self.t }`, `{ self.t($0, label: $1) }`) and add no cycle edge. Mismatches are `factory.unresolved`; unknown `R` stays `graph.missingDependency`. Closures capture the context strongly. Spec: `specs/factory-injection/SPEC.md`.

**Rationale:** Factories are invoked after construction, so they cannot create a construction cycle. Swift erases function-type labels, so positional matching is the only sound rule. A weak capture would force optional handling in generated code; transient holders (the example coordinator) avoid the retain cycle.
## 2026-10-15 — Collection injection: members by key or declared conformance

**Context:** `[any P]` should receive every `P` bean, but keys are unique (two providers for `P` are `graph.duplicateProvider` and would share an accessor), so key equality alone yields at most one member.

**Decision:** A `[E]` parameter with no `[E]` provider multi-binds `[self.a, self.b]`: members are non-assisted providers whose key is `E` or whose key names a scanned type declaring `E` in an inheritance clause (own declaration or extension, transitively through superclasses / sub-protocols), excluding the consumer, sorted by accessor name. An explicit `[E]` bean wins. `[any E]` with no members gets `[]`; plain `[E]` (e.g. `[String]`) stays a missing dependency. A `boundTo: Q` service is a member only via `Q`'s own conformances, never via its concrete type's (its accessor is typed `any Q`). One `ParameterInjection` value is shared by validator and codegen so both agree.

**Rationale:** Spring-like assignability without touching the duplicate rule, accessors, `{Context}Protocol` or qualifiers; graphs that built before keep byte-identical output, except a defaulted `[E]` parameter that now receives existing members.
## 2026-10-15 — Child contexts (draft): compile-time tree, ARC lifetime, child sees parent via its protocol

**Context:** Backlog item "child contexts" (logged-in-user scope created and destroyed at runtime). v1 spec deferred "Subcontexts" and "Context arguments".

**Decision (proposed in `specs/child-contexts/SPEC.md`, pending approval):** `@ChildContext(of: Parent.self)` classes, each with its own `SwiftBeansRegistry`; beans are assigned with `in: Context.self` (default root, so existing output is byte-identical); the child holds its parent strongly as `any {Parent}Protocol` (fakes work); visibility is one-way (child sees parent, never the reverse, siblings isolated) and validated at build time; disposal is ARC deallocation with no explicit hooks in the MVP; context inputs (`@ContextInput`) are providers inside the child. Delivery: phase 0 root inputs, A single-level MVP, B factory/ergonomics, C nesting, D hooks/overrides.

**Rationale:** Dagger/Needle-style compile-time subcomponents keep the no-runtime-locator rule; reusing the registry and the protocol existential needs no new runtime types and keeps tests/Previews possible with hand-written fakes; ARC teardown matches the "release child = release singletons" goal with the least API.

## 2026-10-15 — Versioning: stay on 0.x, publish under MIT

**Context:** First public release of the package on GitHub (`illescasDaniel/SwiftBeans`).

**Decision:** Tag `0.1.0` and stay below `1.0.0` while the API is still settling; any `0.x` minor bump may break the API. README tells users to pin with `.upToNextMinor(from:)`. License is MIT.

**Rationale:** SPM's `from:` allows any version below the next major, which for `0.x` would pull in breaking minors; `upToNextMinor` limits users to patch releases.

## 2026-10-15 — Product surface: two products only

**Context:** Review flagged `SwiftBeansGeneratorCore` as a public product (generator IR leaking into semver) and suggested splitting `BeanScope` into its own module.

**Decision:** Remove the `SwiftBeansGeneratorCore` product; its cross-module API uses `package` access, except `ScanSetResolution.swift`, which stays `public` to remain byte-identical with the plugin copy (plugins compile without a package name). Keep `BeanScope` in `SwiftBeans`.

**Rationale:** The generator already stopped depending on the runtime (`ScopeLiteral`), and `BeanScope` is part of the macro signatures users write, so a separate module would only add an import.

## 2026-10-15 — Example local package split into interface + live targets

**Context:** The example must prove the generator imports a local package module that no app file imports. But the generated `AppContextProtocol` makes the hand-written `FakeAppContext` (app target) name every key's type, so a single-target package type can never stay un-imported.

**Decision:** `Examples/SwiftBeansExample/Packages/GreetingKit` has `GreetingKit` (protocol `Greeter`, imported by the app) and `GreetingKitLive` (`public @Service(boundTo: Greeter.self) EnglishGreeter`). Only `GreetingKitLive` is listed in `.swiftbeans.yml`; no app or test file imports it, so its `import` in `SwiftBeansGenerated.swift` comes from the local-package rule.

**Rationale:** Interface/implementation split is the realistic shape for local-package beans, and it is the only one where the auto-import is actually load-bearing.

## 2026-10-15 — Generator rewrite: shared syntax rules, collected diagnostics, per-key registry

**Context:** Review #5–11, #13–16: the generator matched keys by raw text, only saw top-level declarations and the first initializer, stopped at the first error with no location, imported via a skip list, and the registry could run a singleton factory twice under contention.

**Decision:** New `SwiftBeansSyntaxRules` module holds single-declaration rules; macros report them with `context.diagnose` at the offending node, and the generator reuses them only to decide what it can wire (never re-reports). The generator is a scanner → resolver → validator → codegen pipeline over `TypeKey` (normalized syntax, `any P` ≡ `P`), collecting every error as `file:line:column` with notes, sorted. Cycles via Tarjan SCC over injected edges only. The plugin hands files over as `SwiftBeansInput.json` (with per-file module). `SwiftBeansRegistry` uses one `NSCondition` with per-key `creating(owner)` / `ready` slots; same-thread re-entry traps.

**Rationale:** One rule source keeps macro and generator consistent; collecting diagnostics gives Xcode clickable issues for all problems at once; per-key slots give once-only creation without serializing unrelated factories (no main-thread deadlocks).

## 2026-10-15 — Plugin owns the scan set; resolver shared by byte-identical copy

**Context:** Review found the plugin guessed a source root from `MyApp.swift` / `Assets.xcassets`, could drop target files, searched parent folders for `.swiftbeans.yml`, and never declared local package sources as inputs (stale wiring). A probe on Xcode 27.0 showed `XcodeTarget.inputFiles` already lists every Swift file in nested synchronized-group subfolders.

**Decision:** Plugin takes sources only from the build system, reads `.swiftbeans.yml` only at the package / `.xcodeproj` folder, resolves local package sources itself and declares them plus the config as inputs; the generator just receives an explicit file list (no `--config`, no search). Config parsing + resolution live in one Foundation-only file kept byte-identical in GeneratorCore (tested) and the plugin, with a test guarding drift. `SwiftBeansScanConfiguration` leaves the runtime library.

**Rationale:** Plugins cannot link library targets, and inputs must be known at planning time, so the plugin must do resolution. A copy + drift test is safer than symlinks.

## 2026-10-14 — Generated `{Context}Protocol` + user-owned fakes

**Context:** The example hand-maintained `AppContaining` mirroring generated accessors so navigation/tests could inject stubs. Previews also needed mock graphs without production `AppContext`.

**Decision:** Generator emits `{ContextTypeName}Protocol` (e.g. `AppContextProtocol`) with one `{ get }` per injectable key, plus `extension AppContext: AppContextProtocol {}`. Apps hand-write fakes (`FakeAppContext`); SwiftBeans does not generate mock implementations. Example deleted `AppContaining` and uses `any AppContextProtocol` in the coordinator / Previews / tests.

**Rationale:** The protocol is derived from the same graph as accessors, so it cannot drift. Fake wiring is app-specific (HTTIES fakes, stub repos) and belongs outside the library.

## 2026-10-14 — Example HTTIES from public SPM (not local clone)

**Context:** The example initially linked HTTIES via `Packages/HTTIES` symlinks to a sibling checkout, which forced anyone opening the example to also clone HTTIES.

**Decision:** Use `XCRemoteSwiftPackageReference` to `https://github.com/illescasDaniel/HTTIES` (`upToNextMajorVersion` from 2.0.2). Keep only `Packages/SwiftBeans` as a local symlink for in-repo development of this library.

**Rationale:** Consumers of the example only need the SwiftBeans repo; HTTIES resolves from GitHub like any normal dependency.

## 2026-10-14 — HTTIES via @Bean + generator existential/import fixes

**Context:** The example’s clearest `@Configuration`/`@Bean` story is wiring a foreign HTTP stack (HTTIES + `URLSession` / fake handler) to JSONPlaceholder — not toy types like `AppClock`. Returning `any HTTPClient` broke codegen (`var any HTTPClient`) and the generated file lacked `import HTTIES` under member-import visibility.

**Decision:** (1) Example beans: `httpDataRequestHandler` → `FakeJSONPlaceholderDataHandler` by default (swap to `URLSession.shared` for live API), `httpClient` → `HTTPClientImpl`. (2) `Naming.accessorName` strips `any`/`some` prefixes. (3) Generator collects non-skipped imports from scanned sources and emits them in `SwiftBeansGenerated.swift`.

**Rationale:** `@Bean` exists for types you don’t own; HTTIES makes that obvious. Fake handler keeps CI/Previews offline while one-line swap demonstrates live JSONPlaceholder.

## 2026-10-14 — Example coordinator navigation + AppContaining seam

**Context:** The MVVM example needed more screens and a place to exercise every v1 SwiftBeans feature (`@Configuration`/`@Bean`, singleton vs transient, protocol binding). GamesLibrary already used `AppCoordinator` + `NavigationPath` + an `AppContaining` protocol for testable navigation.

**Decision:** Mirror that pattern in `SwiftBeansExample`: `AppCoordinator` builds routes from `any AppContaining`; production `AppContext` conforms via generated accessors; tests use a stub container. Add `ItemDetail` and `FeaturesDemo` screens; provide `AppClock` / `RequestProbe` via `@Configuration` beans. Host-app unit tests cover use cases, view models, coordinator, and live `AppContext` scope/protocol behavior.

**Rationale:** Keeps navigation out of views, demonstrates compile-time DI end-to-end, and lets tests construct services manually (SPEC “plain types stay plain”) while still integration-testing the generated graph.

## 2026-10-14 — Example multiplatform (iOS + macOS) + rename

**Context:** `SwiftBeansExample` (formerly `SwiftBeansIOSExample`) was locked to iOS-only after Previews failed on **My Mac** (`NoBuildableEntriesError`). That failure was later traced mainly to nesting `Examples/` under a whole-repo `Packages/SwiftBeans` symlink and dual open workspaces, not to macOS support itself.

**Decision:** Re-enable native `macosx` (`SUPPORTED_PLATFORMS` includes `macosx`, `SDKROOT = auto`, macOS runpath). Keep selective `Packages/SwiftBeans` symlinks. Keep the normal `#Preview` construct + `.task { await refresh() }` (no seeded preview state). Rename folder/target/scheme/docs to `SwiftBeansExample`.

**Rationale:** Same package layout that fixed Previews also makes My Mac eligible; multiplatform matches the library’s macOS 15 / iOS 18 platforms and drops the misleading “iOS” name. Async load in Preview is real app behavior — Xcode updates the canvas when `@Observable` state changes.

## 2026-10-14 — Registry create-outside-lock for nested singletons

**Context:** Launching the MVVM example crashed with `_os_unfair_lock_recursive_abort` in `SwiftBeansRegistry.singleton`: resolving `fetchItemsUseCase` held `Mutex` while its factory resolved `itemRepository`, which locked again.

**Decision:** Implement double-checked locking with `NSLock`: look up under lock, run `create` unlocked, store under lock (prefer the winner if two threads race). Drop `Mutex` for this API because Swift 6 region isolation rejects returning a value created outside `withLock`.

**Rationale:** Constructor-injected singleton graphs always nest registry calls; non-recursive locks require unlocked factories. Cycles remain a compile-time validator concern.

## 2026-10-14 — Example Previews: iOS scheme + non-nested Packages/SwiftBeans

**Context:** Previews failed with `NoBuildableEntriesError` / empty `buildableEntries` while target containment still listed `ItemListView.swift`. Diagnostics showed destination **My Mac**; the example was also multiplatform (`macosx` in `SUPPORTED_PLATFORMS`). A repo-root `Packages/SwiftBeans` symlink nested `Examples/` under the package path. Having the repo-root Swift package window open alongside the example `.xcodeproj` also blocked Previews.

**Decision:** (1) Shared `SwiftBeansExample` scheme; target iOS-only (`iphoneos` / `iphonesimulator`). (2) `Packages/SwiftBeans` is a directory of symlinks to `Package.swift` / `Sources` / `Plugins` / `Tests` only (not the whole repo). (3) Open the example project alone for Previews; use an iOS Simulator destination.

**Rationale:** Xcode package resolution still likes the named local folder; avoiding the Examples nest + My Mac + dual-workspace ambiguity made `#Preview` render successfully.

## 2026-10-14 — Example local package via Packages/SwiftBeans symlink

**Context:** Xcode reported `Missing package product 'SwiftBeans'` with `XCLocalSwiftPackageReference` `relativePath = ../..` even though `xcodebuild` often resolved it.

**Decision:** Point the example at `Packages/SwiftBeans` (symlink to the repo root) and set `package =` on each `XCSwiftPackageProductDependency`.

**Rationale:** Matches GamesLibrary-style named local package folders; Xcode build via MCP succeeded afterward. Superseded the same day by selective symlinks (see above) after Previews broke.

## 2026-10-14 — Example E2E: plugin pbxproj + registry visibility

**Context:** Xcode “Run Build Tool Plug-ins” UI is easy to miss; first example build failed on `fileprivate` registry and missing `Foundation` in generated code.

**Decision:** Attach plugins in `project.pbxproj` as `XCSwiftPackageProductDependency` with `productName = "plugin:SwiftBeansPlugin"` plus a `PBXTargetDependency`. Registry property is **internal** (not `fileprivate`) so generated extensions compile. Generated file imports `Foundation`.

**Rationale:** Matches what Xcode writes; verified with iOS Simulator build of `Examples/SwiftBeansExample`.

## 2026-10-14 — Phase 4: registry storage + Mutex platforms

**Context:** Generated extensions cannot add stored properties; per-bean `Mutex` fields need somewhere to live.

**Decision:** `@ApplicationContext` member macro adds `_swiftBeansRegistry: SwiftBeansRegistry`; codegen uses `singleton(key:create:)` for `.singleton` and inline construction for `.transient`. Package platforms set to macOS 15 / iOS 18+ for Synchronization `Mutex`. Accessor names use acronym-aware lowercasing (`URLSession` → `urlSession`).

**Rationale:** One storage property keeps generation simple and concurrency-safe without associated objects.

## 2026-10-14 — GeneratorCore library for Phase 3 tests

**Context:** BDD scenarios need a compilable API before macros/plugin exist; IR validation is pure and testable without parsing.

**Decision:** Add `SwiftBeansGeneratorCore` with `BeanGraphValidator` (implemented) and `BeanSourceParser` (stub `notImplemented`). Runtime accessor scenarios are `@Test(.disabled)` until Phase 4 codegen. Example iOS app lives under `Examples/SwiftBeansExample/` after Phase 4, human-owned.

**Rationale:** Unblocks Phase 3 SDD gate while keeping discovery/codegen for Phase 4.

## 2026-10-14 — Phase 2 architecture seams (`compile-time-di`)

**Context:** Need clear ownership between macros, generator, and plugin; concurrency and YAML filename were still open in the SPEC.

**Decision:**
- Discovery and graph validation live in **SwiftBeansGenerator** (invoked by **SwiftBeansPlugin**); macros are attribute API + local diagnostics only.
- Scan config file name: **`.swiftbeans.yml`**; schema type `SwiftBeansScanConfiguration` with `local_packages`.
- Concurrency: no forced `@MainActor` on contexts; singleton slots use **`Mutex`**; prefer `final class` contexts.
- v1: exactly one `@ApplicationContext` per scanned graph; injectable key = provided type name (no qualifiers).
- Details: `specs/compile-time-di/ARCHITECTURE.md`.

**Rationale:** Matches Swift macro limits, supports Linux/CI and non-UI packages, and mirrors Pin/Sword split (macro surface vs build-time scan).

## 2026-10-14 — SPEC open questions resolved (`compile-time-di`)

**Context:** Phase 1 draft left root name, `@Service` shape, multi-module scan, and `@Bean` static vs instance open.

**Decision:**
- Root attribute: **`@ApplicationContext`** (compile-time graph root; not a runtime service locator). Avoid `@Component` for the root because in Spring that name is a stereotype like `@Service`.
- **`@Service`**: attribute-only for the scanner; no protocol conformance marker in v1.
- Multi-module participation: **YAML** (e.g. `.swiftbeans.yml`) so Xcode iOS apps without `Package.swift` can list local packages/targets.
- **`@Bean`**: static methods only; configuration may be an `enum` with static funcs.

**Rationale:** Aligns naming with Spring’s entry-point mental model, keeps service types plain for tests, and supports real iOS app layouts.

## 2026-10-14 — Compile-time Spring-style DI + build-plugin scan

**Context:** SwiftBeans aims to mimic Spring Boot DI (`@Configuration`, `@Bean`, `@Service`). Swift macros cannot scan other files/modules, so true auto-discovery needs more than macros alone. Runtime vs compile-time graph was also open.

**Decision:** Target a **compile-time dependency graph** first, with **SPM build-tool plugin auto-scan** of annotated sources (option 1B). Keep Spring-inspired attribute names. Fall back to a runtime dictionary-style container only if compile-time proves infeasible after a serious attempt (new spec required). Spec draft: `specs/compile-time-di/SPEC.md`.

**Rationale:** Matches user preference for Spring Boot ergonomics while preserving type-safe wiring (Pin/Sword/Needle camp). Macros supply local API; the plugin supplies classpath-like discovery Swift macros cannot do.

## 2026-10-14 — Add memory-bank skill + jevmem MCP

**Context:** Markdown `memory/` already existed from the GamesLibrary-style bootstrap; long-term semantic memory was still missing.

**Decision:** Vendor [illescasDaniel/memory-bank](https://github.com/illescasDaniel/memory-bank) as `.cursor/skills/memory-bank/` and [illescasDaniel/jev-mem](https://github.com/illescasDaniel/jev-mem) as MCP `jevmem` plus `.cursor/skills/jev-memory/`. Keep the existing `memory/` files; add `archive.md`.

**Rationale:** Official skill matches our bank layout; jevmem is complementary (dated facts by relevance) and the two repos already document the split.

## 2026-10-14 — Agent tooling from GamesLibrary (library-shaped)

**Context:** Starting SwiftBeans as a Swift package DI library with macros; GamesLibrary already had proven Cursor skills/MCP/memory setup.

**Decision:** Copy non-UI skills (`modernize-tests`, worktree helpers, `save-changes`, SDD, playbooks, security audit), memory bank, SDD playbook + adaptations, and MCP servers `codenav-swift` + `xcode-tools`. Skip SwiftUI/App Intents/document/UIKit skills, hexagonal-ios app rules, and `ios-simulator` MCP.

**Rationale:** Keep agent process (SDD, memory, Swift Testing, build/nav MCPs) without dragging app/UI workflows into a package repo.
