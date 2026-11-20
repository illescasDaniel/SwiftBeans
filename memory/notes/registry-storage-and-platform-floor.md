---
name: registry-storage-and-platform-floor
description: @ApplicationContext adds _swiftBeansRegistry storage; platforms macOS 15 / iOS 18 floor; acronym-aware accessor names
type: decision
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

Generated extensions cannot add stored properties, so the member macro adds `_swiftBeansRegistry: SwiftBeansRegistry`. Platforms were set to macOS 15 / iOS 18+ originally for Synchronization `Mutex`. Accessor names lowercase acronyms (`URLSession` -> `urlSession`).

**Note:** the `Mutex` storage itself was replaced by lock-outside-factory registry slots (`registry-create-outside-lock`); the platform floor stayed.
