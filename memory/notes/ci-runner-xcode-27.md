---
name: ci-runner-xcode-27
description: CI uses the xcode-27 runner (Xcode 27.0, Swift 6.4) for package tests, example macOS tests and iOS Simulator build
type: context
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

`.github/workflows/ci.yml` sets `DEVELOPER_DIR` to `Xcode_27.0.app` (runner image notes: actions/runner-images#14404) and passes `-skipPackagePluginValidation -skipMacroValidation` to `xcodebuild`. CI has not yet run for the unpushed auto-init work.
