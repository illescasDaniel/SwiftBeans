---
name: graph-dump-not-plugin-outputs
description: SwiftBeansGraph.md/.dot are written by the generator but must not be declared as plugin outputFiles
type: gotcha
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

Declaring them in `outputFiles` made SwiftPM copy them into a `<Package>_<Target>.bundle` (unknown output types become resources), giving every consumer target a resource bundle. The plugin passes `--graph-markdown`/`--graph-dot` but lists only `SwiftBeansGenerated.swift`. v1 always emits on success, with no `.swiftbeans.yml` toggle.

**Why:** a resource bundle in app targets is worse than the build system not tracking a debug artifact. Trade-off: deleting a graph file by hand does not rerun the generator until an input changes. Content comes from `GraphDump` in `SwiftBeansGeneratorCore`.
