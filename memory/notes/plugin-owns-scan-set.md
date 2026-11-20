---
name: plugin-owns-scan-set
description: Plugin owns the scan set; config resolver is a byte-identical copy in GeneratorCore and the plugin with a drift test
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

The plugin takes sources only from the build system, reads `.swiftbeans.yml` only at the package/`.xcodeproj` folder, resolves local-package sources and declares them plus the config as inputs; the generator receives an explicit file list. A probe on Xcode 27.0 showed `XcodeTarget.inputFiles` already lists every Swift file in nested synchronized-group subfolders. `SwiftBeansScanConfiguration` left the runtime library.

**Why:** plugins cannot link library targets and inputs must be known at planning time; a copy plus drift test is safer than symlinks. Triggered by a review that found guessed source roots and stale local-package inputs.
