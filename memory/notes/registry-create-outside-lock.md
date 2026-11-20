---
name: registry-create-outside-lock
description: Example crashed with _os_unfair_lock_recursive_abort: registry factories must run outside the lock
type: incident
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

Launching the MVVM example crashed in `SwiftBeansRegistry.singleton`: resolving `fetchItemsUseCase` held the `Mutex` while its factory resolved `itemRepository`, which locked again. Fix: double-checked locking with `NSLock` (look up under lock, create unlocked, store under lock, prefer the winner on a race). `Mutex` was dropped for this API because Swift 6 region isolation rejects returning a value created outside `withLock`. Later refined to per-key slots (see `generator-rewrite-shared-rules`).

**Why:** constructor-injected singleton graphs always nest registry calls and non-recursive locks require unlocked factories. Cycles remain a compile-time validator concern.
