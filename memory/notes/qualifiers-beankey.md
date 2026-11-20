---
name: qualifiers-beankey
description: Qualifiers: BeanKey = (TypeKey, name?), accessor = qualifier + type; unqualified params never pick a named bean
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

`named:` on `@Bean`/`@Service` and `@Qualifier("...")` on parameters (marker property wrapper like `@Assisted`). Accessor = qualifier + type pieces (`snakeCaseJSONDecoder`). Name literals must be identifier-shaped. Graphs without qualifiers stay byte-identical.

**Why:** apps need several beans of one type; Spring-style global names collide across types and numeric suffixes are unstable. Keeps diagnostics and `{Context}Protocol` per key. Optional later: an `accessor:` override.
