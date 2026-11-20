---
name: sdd-workflow-upstream-baseline
description: SDD skill is adapted from illescasDaniel/sdd-feature-skill commit 5443fe5 (2026-10-22); no UI track
type: decision
date: 2026-10-25
status: current
supersedes: 
superseded_by: 
source:
---

The local SDD skill had four phases; it now follows upstream `illescasDaniel/sdd-feature-skill` commit `5443fe57ff5f0fef25d8a76f75dae64953bb9e7b`, adapted with SwiftBeans-specific templates for runtime, macro, generator and plugin seams. No UI/app-only workflows are imported.

**Why:** the design phase surfaces module and generated-code seams before the spec freezes; structural checks and independent grading were missing.
