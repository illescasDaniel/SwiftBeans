---
name: swift-test-does-not-build-generator-executable
description: `swift test` does not build the SwiftBeansGenerator executable; example xcodebuild does (a duplicate printError slipped through)
type: gotcha
date: 2026-10-16
status: current
supersedes: 
superseded_by: 
source:
---

A duplicate `printError` in `SwiftBeansGeneratorMain` passed `swift test` and failed only in the example build. Run the example `xcodebuild test` after touching the generator executable.
