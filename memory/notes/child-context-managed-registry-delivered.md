---
name: child-context-managed-registry-delivered
description: Managed child close uses a separate MainActor SwiftBeansManagedRegistry; cleanup is independent of ARC deallocation
type: decision
date: 2026-10-25
status: current
supersedes: 
superseded_by: 
source:
---

Architecture approved after design and spec. A1/A2 shipped with a separate MainActor `SwiftBeansManagedRegistry`; the root/ARC registry is untouched. Managed close runs one unstructured actor-isolated cleanup task shared by all callers, enrolls instantiated own singleton identities once, and guards later generated resolutions and retained factories. The example root coordinator owns a flow with the context and a transient child coordinator. Compiler identity witnesses validate unresolved qualified context references without guessing Xcode module names.

**Why:** login-scoped objects can stay retained after logout, so completion cannot depend on ARC; a waiter's cancellation must not abandon cleanup; no new unsafe sendability promises. Evidence: `specs/child-contexts/VERIFICATION.md`, `REVIEW.md`.
