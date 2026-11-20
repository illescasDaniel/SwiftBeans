---
name: service-auto-init-opt-in-recommended
description: @Service(autoInit: true) is opt-in (default false), a Bool flag, shown as the recommended style; markers are peer macros on properties
type: decision
date: 2026-11-20
status: current
supersedes: 
superseded_by: 
source:
---

`@Service(autoInit: true)` generates the initializer from stored properties. `@Assisted` and `@Qualifier` mark `let` properties through same-named marker peer macros, not property-wrapper storage. The flag defaults to `false` (a `Bool` in v1, no enum) but the README shows it as the first `@Service` example and the example app uses it everywhere except where a hand-written init shows something auto-init cannot do.

**Why:** existing graphs stay byte-identical while the boilerplate-free style is promoted.
**How to apply:** keep auto-init as the first `@Service` example in README concepts (the spec requires it). Details: `specs/service-auto-init/SPEC.md`, `design/service-auto-init/DESIGN.md`.
