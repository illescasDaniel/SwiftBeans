---
name: child-contexts-draft-arc-lifetime
description: Early child-context draft: compile-time tree, ARC-only disposal, child sees parent via its protocol
type: decision
date: 2026-10-15
status: superseded
supersedes: 
superseded_by: child-context-design-approved
source:
---

Draft in `specs/child-contexts/SPEC.md`: `@ChildContext(of:)` classes with their own registry, beans assigned with `in:` (default root, so existing output is byte-identical), child holds its parent as `any {Parent}Protocol`, visibility one-way and validated at build time, disposal by ARC with no hooks in the MVP, `@ContextInput` providers. Phased A single-level, B factories, C nesting, D hooks.

**Why:** Dagger/Needle-style subcomponents keep the no-runtime-locator rule. Superseded on 2026-10-25 by the approved design, which adds optional managed teardown.
