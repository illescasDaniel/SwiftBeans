# Memory

Code at HEAD wins for current behaviour; notes win for why and history; newest current note wins; open `source` sessions for detail.

## Decisions
- [memory-1-and-docs-1-adoption](notes/memory-1-and-docs-1-adoption.md) 2026-11-20: Project memory moved to memory-1 (NOW/LATER/MEMORY + notes) and docs to docs-1 (front matter + generated docs/INDEX.md)
- [service-auto-init-opt-in-recommended](notes/service-auto-init-opt-in-recommended.md) 2026-11-20: @Service(autoInit: true) is opt-in (default false), a Bool flag, shown as the recommended style; markers are peer macros on properties
- [nested-existential-original-evidence](notes/nested-existential-original-evidence.md) 2026-10-25: Accessor/protocol spelling comes from one immutable AccessorTypePlan built from original source evidence per owner
- [emitted-spelling-separate-from-graph-identity](notes/emitted-spelling-separate-from-graph-identity.md) 2026-10-25: Normalized graph keys drop nested `any`; emitted types need a separate recursive representation
- [sdd-separate-approval-gates](notes/sdd-separate-approval-gates.md) 2026-10-25: SDD needs separate explicit approvals for design, spec and architecture, then tests, implementation, independent grade
- [sdd-workflow-upstream-baseline](notes/sdd-workflow-upstream-baseline.md) 2026-10-25: SDD skill is adapted from illescasDaniel/sdd-feature-skill commit 5443fe5 (2026-10-22); no UI track
- [example-session-ownership-split](notes/example-session-ownership-split.md) 2026-10-25: Example: app-owned AppSession separate from AppCoordinator composition; coordinator gets a sign-in action
- [child-context-managed-registry-delivered](notes/child-context-managed-registry-delivered.md) 2026-10-25: Managed child close uses a separate MainActor SwiftBeansManagedRegistry; cleanup is independent of ARC deallocation
- [child-context-spec-approved-managed-teardown](notes/child-context-spec-approved-managed-teardown.md) 2026-10-25: Child-context spec approved including managed teardown; architecture approval kept separate
- [child-context-resource-budget-structural](notes/child-context-resource-budget-structural.md) 2026-10-25: Child contexts: structural resource limits, no absolute millisecond or graph-size cap
- [child-context-design-approved](notes/child-context-design-approved.md) 2026-10-25: Child contexts: root coordinator owns a flow with child context and transient child coordinator; ARC default, optional managed cleanup
- [feature-improvements-merge-order](notes/feature-improvements-merge-order.md) 2026-10-16: feature/improvements merged PRs #3, #4, #2, #7, #6, #5, #1 in that order; BeanKey lands before factories and collections
- [local-package-scan-generator-reresolves](notes/local-package-scan-generator-reresolves.md) 2026-10-15: Generator re-reads .swiftbeans.yml and re-walks sources every run; SwiftPM rejects prebuild commands built from source
- [inter-bean-direct-call-warning](notes/inter-bean-direct-call-warning.md) 2026-10-15: Inter-bean direct calls get a generator warning bean.directCall, not an error; no runtime change
- [qualifiers-beankey](notes/qualifiers-beankey.md) 2026-10-15: Qualifiers: BeanKey = (TypeKey, name?), accessor = qualifier + type; unqualified params never pick a named bean
- [factory-injection-lazy-edges](notes/factory-injection-lazy-edges.md) 2026-10-15: Factory injection: function types only as parameters, positional type matching, lazy edges, strong context capture
- [collection-injection-membership](notes/collection-injection-membership.md) 2026-10-15: Collection injection: [any P] receives non-assisted providers whose key is P or whose type declares conformance to P
- [versioning-0x-mit](notes/versioning-0x-mit.md) 2026-10-15: Stay on 0.x; any minor may break; README says pin with .upToNextMinor; MIT license
- [product-surface-two-products](notes/product-surface-two-products.md) 2026-10-15: Only two products (SwiftBeans, SwiftBeansPlugin); GeneratorCore uses package access; BeanScope stays in SwiftBeans
- [example-local-package-interface-live-split](notes/example-local-package-interface-live-split.md) 2026-10-15: Example local package split into GreetingKit (interface) and GreetingKitLive (impl) to prove the auto-import
- [generator-rewrite-shared-rules](notes/generator-rewrite-shared-rules.md) 2026-10-15: Generator is a scanner, resolver, validator, codegen pipeline over TypeKey with collected positioned diagnostics
- [plugin-owns-scan-set](notes/plugin-owns-scan-set.md) 2026-10-15: Plugin owns the scan set; config resolver is a byte-identical copy in GeneratorCore and the plugin with a drift test
- [context-protocol-user-fakes](notes/context-protocol-user-fakes.md) 2026-10-14: Generator emits {Context}Protocol; fakes are hand-written by the app, never generated
- [example-httties-public-spm](notes/example-httties-public-spm.md) 2026-10-14: Example depends on HTTIES from GitHub (upToNextMajor from 2.0.2), not a local clone
- [httties-bean-and-generator-import-fixes](notes/httties-bean-and-generator-import-fixes.md) 2026-10-14: Example wires HTTIES via @Bean with a fake handler by default; accessor naming strips any/some; generated file imports scanned modules
- [example-multiplatform-rename](notes/example-multiplatform-rename.md) 2026-10-14: Example is multiplatform (iOS + macOS), renamed SwiftBeansExample; keep normal #Preview with async .task refresh
- [registry-storage-and-platform-floor](notes/registry-storage-and-platform-floor.md) 2026-10-14: @ApplicationContext adds _swiftBeansRegistry storage; platforms macOS 15 / iOS 18 floor; acronym-aware accessor names
- [generatorcore-for-phase3-tests](notes/generatorcore-for-phase3-tests.md) 2026-10-14: SwiftBeansGeneratorCore introduced so Phase 3 BDD tests could compile before macros and plugin existed
- [phase2-architecture-seams](notes/phase2-architecture-seams.md) 2026-10-14: compile-time-di architecture: discovery in generator + plugin, macros only attributes and local diagnostics; .swiftbeans.yml; one @ApplicationContext
- [spec-open-questions-resolved](notes/spec-open-questions-resolved.md) 2026-10-14: Root attribute is @ApplicationContext (not @Component); @Service attribute-only; @Bean static only; multi-module via YAML
- [compile-time-di-with-plugin-scan](notes/compile-time-di-with-plugin-scan.md) 2026-10-14: Target a compile-time dependency graph with an SPM build-tool plugin scan; runtime dictionary container only as a spec-approved fallback
- [agent-tooling-from-gameslibrary](notes/agent-tooling-from-gameslibrary.md) 2026-10-14: Agent tooling copied from GamesLibrary minus UI pieces: SDD, Swift Testing, worktree helpers, codenav-swift and xcode-tools MCP
## Gotchas
- [swift-test-does-not-build-generator-executable](notes/swift-test-does-not-build-generator-executable.md) 2026-10-16: `swift test` does not build the SwiftBeansGenerator executable; example xcodebuild does (a duplicate printError slipped through)
- [graph-dump-not-plugin-outputs](notes/graph-dump-not-plugin-outputs.md) 2026-10-15: SwiftBeansGraph.md/.dot are written by the generator but must not be declared as plugin outputFiles
- [linux-swift6-generator-stderr-and-mtime](notes/linux-swift6-generator-stderr-and-mtime.md) 2026-10-15: Linux: Swift 6 rejects fputs(_, stderr); GeneratedFileWriterTests compare mtime with 1 s tolerance
- [example-previews-selective-symlinks](notes/example-previews-selective-symlinks.md) 2026-10-14: Xcode Previews NoBuildableEntriesError: use selective Packages/SwiftBeans symlinks and open the example project alone
- [example-plugin-pbxproj-attachment](notes/example-plugin-pbxproj-attachment.md) 2026-10-14: Attach the plugin in project.pbxproj as plugin:SwiftBeansPlugin; registry property must be internal, generated file imports Foundation
## Incidents
- [registry-create-outside-lock](notes/registry-create-outside-lock.md) 2026-10-14: Example crashed with _os_unfair_lock_recursive_abort: registry factories must run outside the lock
## Context
- [ci-runner-xcode-27](notes/ci-runner-xcode-27.md) 2026-10-15: CI uses the xcode-27 runner (Xcode 27.0, Swift 6.4) for package tests, example macOS tests and iOS Simulator build
## Preferences
## History (superseded)
- [child-contexts-draft-arc-lifetime](notes/child-contexts-draft-arc-lifetime.md) 2026-10-15 -> superseded by child-context-design-approved
- [example-coordinator-appcontaining](notes/example-coordinator-appcontaining.md) 2026-10-14 -> superseded by context-protocol-user-fakes
- [example-local-package-symlink](notes/example-local-package-symlink.md) 2026-10-14 -> superseded by example-previews-selective-symlinks
- [memory-bank-and-jevmem-added](notes/memory-bank-and-jevmem-added.md) 2026-10-14 -> superseded by memory-1-and-docs-1-adoption
