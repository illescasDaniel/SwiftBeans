---
name: child-context-design-approved
description: Child contexts: root coordinator owns a flow with child context and transient child coordinator; ARC default, optional managed cleanup
type: decision
date: 2026-10-25
status: current
supersedes: child-contexts-draft-arc-lifetime
superseded_by: 
source:
---

Approved `design/child-contexts/DESIGN.md`: ARC is the default, with optional managed cleanup of instantiated child singletons. Managed contexts use MainActor initially; generated resolution fails a precondition after closing starts. Delivery split: child graphs (A1), managed cleanup plus the login example (A2).

**Why:** keeps the existing factory/build conventions, avoids caching a context-retaining coordinator in that context, and gives logout one awaited cleanup boundary without claiming to force deallocation of escaped references.
