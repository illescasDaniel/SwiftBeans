---
name: example-session-ownership-split
description: Example: app-owned AppSession separate from AppCoordinator composition; coordinator gets a sign-in action
type: decision
date: 2026-10-25
status: current
supersedes: 
superseded_by: 
source:
---

Authentication cancellation/admission and managed logout had accumulated in `AppCoordinator`. The user selected a separate app-owned `AppSession` and `AppCoordinator` composition: the coordinator receives a sign-in action, root presentation observes the session directly, and signed-in UI receives logout/expiry callbacks. `AppSession` has one explicit lifecycle state; `LoginViewModel` keeps its own presentation-request identity.

**Why:** screens depend only on the action they need, with no session property or mirrored state; one lifecycle owner preserves stale-result rejection and the cleanup admission barrier.
**Rejected:** forwarding session members or exposing `coordinator.session`, which kept the coordinator as the session access point.
