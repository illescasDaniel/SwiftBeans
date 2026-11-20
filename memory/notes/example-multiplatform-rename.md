---
name: example-multiplatform-rename
description: Example is multiplatform (iOS + macOS), renamed SwiftBeansExample; keep normal #Preview with async .task refresh
type: decision
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

Re-enabled native `macosx` (`SUPPORTED_PLATFORMS` includes it, `SDKROOT = auto`, macOS runpath). The earlier Previews failure on My Mac (`NoBuildableEntriesError`) was traced mainly to nesting `Examples/` under a whole-repo `Packages/SwiftBeans` symlink and two open workspaces, not to macOS support.

**Why:** the selective-symlink layout that fixed Previews also makes My Mac eligible; matches the library's macOS 15/iOS 18 platforms. Reverses the iOS-only target part of `example-previews-selective-symlinks`.
