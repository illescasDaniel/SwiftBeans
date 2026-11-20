---
name: emitted-spelling-separate-from-graph-identity
description: Normalized graph keys drop nested `any`; emitted types need a separate recursive representation
type: decision
date: 2026-10-25
status: current
supersedes: 
superseded_by: 
source:
---

Normalized `TypeKey`s discard nested `any`, so rebuilding accessor types from keys can emit invalid Swift under `ExistentialAny`. The user chose a recursive emitted-type representation alongside the keys.

**Why:** dependency equivalence and valid emitted syntax need different information; this fixes arrays, dictionaries and generic arguments without changing graph identity.
**How to apply:** see `nested-existential-original-evidence` for how the spelling is chosen.
