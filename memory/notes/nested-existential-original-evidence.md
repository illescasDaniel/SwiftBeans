---
name: nested-existential-original-evidence
description: Accessor/protocol spelling comes from one immutable AccessorTypePlan built from original source evidence per owner
type: decision
date: 2026-10-25
status: current
supersedes: 
superseded_by: 
source:
---

Recursive `EmittedType` metadata is carried through normalization/resolution. One `AccessorTypePlan` is computed from original source evidence in the existing visibility views, so inferred results never become new evidence and markers do not leak between sibling contexts. `(any P).Alias` keeps its legacy canonical `P.Alias` qualification: existential wrappers are removed only from the member's qualification base.

**Why:** complete-type evidence unions are deterministic and owner-aware; wrappers on the qualification base do not wrap the resulting alias type, so existing valid source and output are preserved.
**How to apply:** see `specs/nested-existential-spelling/`. Graph identity, wiring, scopes and lifecycle are unchanged.
