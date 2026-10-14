# SwiftBeans — Playbook Adaptations

This project follows the SDD playbook with these **intentional adaptations** for a Swift package (dependency injection + macros), not an iOS app.

## What this repo is

- A **Swift Package** (`Package.swift`) producing the `SwiftBeans` library (and, later, macro targets as needed).
- No app target, no SwiftUI UI, no XCUITests, no simulator MCP workflow.

## SDD phases (library-shaped)

| Phase | GamesLibrary-style playbook | SwiftBeans |
|-------|-----------------------------|------------|
| Spec | User flows, UI rules, routing | Public API, lifetimes/scopes, macro surface, error/thread-safety rules |
| Architecture | Ports in Core + adapters | Public protocols/types + macro vs runtime module seams |
| Tests | ViewModel / use-case tests; UI tests XCTest | Package unit tests with Swift Testing; macro expansion tests when macros exist |
| Implementation | Adapters + UI | Library + macros until `swift test` is green |

## Quality gate

```bash
swift test
```

Prefer **xcode-tools** MCP for scheme/test runs when the package is open in Xcode. Prefer **codenav-swift** for symbol navigation after an index exists (see `AGENTS.md`).

## Do not apply from app playbooks

- Hexagonal app folder trees, coordinators, SwiftUI previews, BFF/pinning, App Intents, or iOS Simulator MCP / XCUITest exploration.
