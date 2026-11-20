---
name: example-httties-public-spm
description: Example depends on HTTIES from GitHub (upToNextMajor from 2.0.2), not a local clone
type: decision
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

Uses `XCRemoteSwiftPackageReference` to `https://github.com/illescasDaniel/HTTIES`. Only `Packages/SwiftBeans` remains a local symlink for in-repo library development.

**Why:** consumers of the example should need only the SwiftBeans repo.
