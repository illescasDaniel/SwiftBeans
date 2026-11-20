---
name: example-previews-selective-symlinks
description: Xcode Previews NoBuildableEntriesError: use selective Packages/SwiftBeans symlinks and open the example project alone
type: gotcha
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

Previews failed with empty `buildableEntries` while target containment looked fine. Causes: destination My Mac on an iOS-only-intended target, a repo-root `Packages/SwiftBeans` symlink that nested `Examples/` under the package path, and the repo-root package window open next to the example `.xcodeproj`. Fix: a shared `SwiftBeansExample` scheme; `Packages/SwiftBeans` is a directory of symlinks to `Package.swift`/`Sources`/`Plugins`/`Tests` only; open the example project alone with an iOS Simulator destination.

The "target is iOS-only" part was later reversed by `example-multiplatform-rename`; the symlink layout and open-alone advice still apply.
