---
name: collection-injection-membership
description: Collection injection: [any P] receives non-assisted providers whose key is P or whose type declares conformance to P
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

Keys are unique (two providers for `P` are `graph.duplicateProvider`), so a `[E]` parameter with no `[E]` provider multi-binds `[self.a, self.b]`: members are non-assisted providers whose key is `E` or whose scanned type declares `E` in an inheritance clause (own declaration or extension, transitively via superclasses/sub-protocols), excluding the consumer, sorted by accessor name. An explicit `[E]` bean wins. `[any E]` with no members gets `[]`; plain `[E]` (e.g. `[String]`) stays a missing dependency. A `boundTo: Q` service is a member only via `Q`'s conformances. One `ParameterInjection` value is shared by validator and codegen.

**Why:** Spring-like assignability without touching the duplicate rule, accessors, `{Context}Protocol` or qualifiers; earlier graphs stay byte-identical except a defaulted `[E]` parameter that now receives members.
