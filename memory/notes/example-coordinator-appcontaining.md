---
name: example-coordinator-appcontaining
description: Example navigation: AppCoordinator builds routes from an injected container seam; screens ItemDetail and FeaturesDemo
type: decision
date: 2026-10-14
status: superseded
supersedes: 
superseded_by: context-protocol-user-fakes
source:
---

Mirrors the GamesLibrary pattern: coordinator builds routes from a container protocol, tests inject a stub, host-app tests cover use cases, view models, coordinator and live context behavior.

**Why:** keeps navigation out of views and exercises every v1 feature. The hand-written `AppContaining` was replaced by the generated protocol, see `context-protocol-user-fakes`.
