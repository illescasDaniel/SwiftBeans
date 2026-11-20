---
name: compile-time-di-with-plugin-scan
description: Target a compile-time dependency graph with an SPM build-tool plugin scan; runtime dictionary container only as a spec-approved fallback
type: decision
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

Swift macros cannot scan other files/modules, so auto-discovery needs a plugin; macros supply the local API. Spring-inspired attribute names are kept. Fall back to a runtime container only if compile-time proves infeasible after a serious attempt (new spec required). Spec: `specs/compile-time-di/SPEC.md`.

**Why:** the user prefers Spring Boot ergonomics with type-safe wiring (the Pin/Sword/Needle camp).
