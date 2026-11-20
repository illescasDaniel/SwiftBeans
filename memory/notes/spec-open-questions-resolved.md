---
name: spec-open-questions-resolved
description: Root attribute is @ApplicationContext (not @Component); @Service attribute-only; @Bean static only; multi-module via YAML
type: decision
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

`@Component` was avoided for the root because in Spring it is a stereotype like `@Service`. `@Service` needs no protocol conformance marker. Multi-module participation uses YAML so Xcode apps without `Package.swift` can list local packages. `@Bean` is static methods only; a configuration may be an `enum` of static funcs.

**Why:** aligns naming with Spring's entry-point mental model, keeps service types plain for tests, supports real iOS layouts.
