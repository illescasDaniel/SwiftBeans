# Decisions

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
