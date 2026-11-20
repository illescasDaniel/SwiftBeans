---
name: phase2-architecture-seams
description: compile-time-di architecture: discovery in generator + plugin, macros only attributes and local diagnostics; .swiftbeans.yml; one @ApplicationContext
type: decision
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

Discovery and validation live in `SwiftBeansGenerator` (run by `SwiftBeansPlugin`). Scan config is `.swiftbeans.yml` with `local_packages` (`SwiftBeansScanConfiguration`). No forced `@MainActor` on contexts; prefer `final class` contexts. v1: exactly one `@ApplicationContext` per scanned graph, injectable key = provided type name (qualifiers came later). Details: `specs/compile-time-di/ARCHITECTURE.md`.

**Why:** fits Swift macro limits, supports Linux/CI and non-UI packages, mirrors the Pin/Sword macro-surface vs build-time-scan split.
