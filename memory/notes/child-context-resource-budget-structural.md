---
name: child-context-resource-budget-structural
description: Child contexts: structural resource limits, no absolute millisecond or graph-size cap
type: decision
date: 2026-10-25
status: current
supersedes: 
superseded_by: 
source:
---

Constraints: root-only generated output preserved, no extra whole-source scan per child, lifecycle bookkeeping proportional to instantiated child singletons, cleanup proportional to participating objects. No initial millisecond cap, graph-size cap or callback-duration budget.

**Why:** the package has no benchmark baseline and user cleanup code controls close duration; acceptance should not depend on machine speed.
