---
name: versioning-0x-mit
description: Stay on 0.x; any minor may break; README says pin with .upToNextMinor; MIT license
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

First public release `0.1.0` of `illescasDaniel/SwiftBeans` (published 2026-10-15), then `0.2.0` on 2026-10-16.

**Why:** SPM's `from:` allows everything below the next major, which for 0.x would pull in breaking minors; `upToNextMinor` limits users to patches.
