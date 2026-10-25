# SwiftBeans — Playbook Adaptations

This project follows the SDD playbook with these **intentional adaptations** for a Swift package (dependency injection + macros), not an iOS app.

## What this repo is

- A **Swift Package** (`Package.swift`) producing the `SwiftBeans` library (and, later, macro targets as needed).
- No app target, no SwiftUI UI, no XCUITests, no simulator MCP workflow.

## SDD phases (library-shaped)

| Phase | GamesLibrary-style playbook | SwiftBeans |
|-------|-----------------------------|------------|
| Design | Wireframes and app system diagrams | `design/<feature>/DESIGN.md` for API, runtime, macro, generator, or plugin changes; no UI wireframes |
| Spec | User flows, UI rules, routing | Public API, lifetimes/scopes, macro surface, generated-code behavior, diagnostics, error/thread-safety rules, design decisions, and BDD criteria |
| Architecture | Ports in Core + adapters | `specs/<feature>/ARCHITECTURE.md`: public contracts and macro vs runtime vs generator/plugin seams |
| Tests | ViewModel / use-case tests; UI tests XCTest | Package tests with Swift Testing; macro expansion and generated-source compile tests as needed |
| Implementation | Adapters + UI | Library + macros until `swift test` and feature-specific checks pass |
| Grade | — | Independent read-only review against approved spec, design, and project conventions |

Phases Design, Spec, and Architecture each require a separate explicit approval in chat before proceeding. A small internal-only change may propose skipping Design, but that skip itself requires approval. See `.cursor/skills/sdd-feature/SKILL.md` for the complete workflow and templates.

## Quality gate

```bash
swift test
```

Prefer **xcode-tools** MCP for scheme/test runs when the package is open in Xcode. Prefer **codenav-swift** for symbol navigation after an index exists (see `AGENTS.md`).

## Do not apply from app playbooks

- Hexagonal app folder trees, coordinators, SwiftUI previews, BFF/pinning, App Intents, or iOS Simulator MCP / XCUITest exploration.
