---
name: context-protocol-user-fakes
description: Generator emits {Context}Protocol; fakes are hand-written by the app, never generated
type: decision
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

The generator emits `{ContextTypeName}Protocol` (e.g. `AppContextProtocol`) with one `{ get }` per injectable key plus `extension AppContext: AppContextProtocol {}`. The example deleted its hand-kept `AppContaining` and uses `any AppContextProtocol` in the coordinator, Previews and tests.

**Why:** derived from the same graph as the accessors, so it cannot drift; fake wiring is app-specific and belongs outside the library.
