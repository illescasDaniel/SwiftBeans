---
name: inter-bean-direct-call-warning
description: Inter-bean direct calls get a generator warning bean.directCall, not an error; no runtime change
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

`@Bean`s are static, so `Config.otherBean()` inside a `@Bean` silently builds a second instance (Spring proxies `@Configuration` to avoid this). `DirectCallAnalyzer` warns for calls to a known `@Bean` from `@Bean` bodies and `@Service` initializer bodies (`Type.bean()`, `Self.bean()`, bare `bean()`), with a note at the callee. Matching is by base name and type spelling; ambiguous or self calls are skipped. Proxies, instance `@Bean` and macro rewriting stay out of scope (options in the SPEC Future work).

**Why:** cheapest useful step with no output or API change; a warning avoids breaking builds on false positives of spelling-based matching (typealiases, shadowing).
