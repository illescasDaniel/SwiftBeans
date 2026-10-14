---
name: sdd-feature
description: >-
  Run Spec-Driven Development for SwiftBeans library features. Use when adding
  or changing public API, macros, container behavior, writing SPEC.md, or
  implementing features from acceptance criteria.
---

# SDD Feature Workflow (Swift Package)

## Phase 1 — Spec

Create or update `specs/<feature>/SPEC.md` with:

- Metadata & dependencies (Swift tools version, platforms, related macros/targets)
- Public API surface (types, macros, registration/resolution entry points)
- Behavioral rules (scopes, lifetimes, thread safety, error cases)
- Acceptance criteria (Given/When/Then)
- Out of scope (anti-goals)

**Stop for approval.**

## Phase 2 — Architecture

Add or update contracts in the package (as applicable):

- Public protocols / types for the feature
- Macro declaration surface vs implementation target boundaries
- Internal module seams (e.g. runtime vs macros vs plugins)

**Stop for approval.**

## Phase 3 — Tests

Map each BDD scenario to a `@Test` in Swift Testing (follow `modernize-tests`):

```swift
@Test
func givenRegisteredTypeWhenResolvedThenReturnsSameInstance() async throws { ... }
```

Prefer package unit tests under `Tests/`. Macro expansion tests belong with the macro target’s test suite when present.

## Phase 4 — Implementation

Implement until tests pass. Update `AGENTS.md` or specs only if behavior changed intentionally. Update `memory/` at milestones (see `.cursor/rules/agent-memory.mdc`).

### Quality gate

```bash
swift test
```

When **xcode-tools** MCP is available, prefer opening the Swift package workspace and running tests there after a successful `swift test` baseline.

## Spec template

See `specs/` for feature specs as they are added.
