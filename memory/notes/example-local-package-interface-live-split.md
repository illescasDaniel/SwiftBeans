---
name: example-local-package-interface-live-split
description: Example local package split into GreetingKit (interface) and GreetingKitLive (impl) to prove the auto-import
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

`Examples/SwiftBeansExample/Packages/GreetingKit` has `GreetingKit` (protocol `Greeter`, imported by the app) and `GreetingKitLive` (`public @Service(boundTo: Greeter.self) EnglishGreeter`). Only `GreetingKitLive` is listed in `.swiftbeans.yml`; nothing in the app imports it, so its `import` in `SwiftBeansGenerated.swift` comes from the local-package rule.

**Why:** the generated `AppContextProtocol` makes the hand-written fake name every key's type, so a single-target package type could never stay un-imported; the split is also the realistic shape.
