---
name: factory-injection-lazy-edges
description: Factory injection: function types only as parameters, positional type matching, lazy edges, strong context capture
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

`(P...) -> R` binds to `R`'s assisted method when the assisted parameter types equal `P...` positionally (labels ignored, Swift erases them); `() -> R` binds to `R`'s plain accessor. Both emit closure literals and add no cycle edge. Mismatches are `factory.unresolved`; unknown `R` stays `graph.missingDependency`. Closures capture the context strongly.

**Why:** factories run after construction so they cannot create a construction cycle; a weak capture would force optionals into generated code, so transient holders (the example coordinator) avoid the retain cycle. Spec: `specs/factory-injection/SPEC.md`.
