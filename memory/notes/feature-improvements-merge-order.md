---
name: feature-improvements-merge-order
description: feature/improvements merged PRs #3, #4, #2, #7, #6, #5, #1 in that order; BeanKey lands before factories and collections
type: decision
date: 2026-10-16
status: current
supersedes: 
superseded_by: 
source:
---

Seven draft PRs were integrated on `feature/improvements` without closing them first. Qualifiers (`BeanKey`) landed before factory and collection injection so those adapted once. Resulting rules: factories resolve against the unqualified provider of the return type; collection membership is by type and declared conformances, so named providers of an element type join `[any P]`/`[P]`. The plugin keeps `--request` from #3 and adds `--graph-markdown`/`--graph-dot` from #2.

**Why:** avoids rebasing factory/collection work twice; matches the qualifier rule that a plain parameter never silently picks a named bean. The draft PRs #1-#7 were later closed as superseded.
