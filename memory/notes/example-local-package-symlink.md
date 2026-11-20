---
name: example-local-package-symlink
description: Example local package first pointed at a whole-repo Packages/SwiftBeans symlink with package= on product dependencies
type: decision
date: 2026-10-14
status: superseded
supersedes: 
superseded_by: example-previews-selective-symlinks
source:
---

Done because Xcode reported `Missing package product 'SwiftBeans'` with `XCLocalSwiftPackageReference` `relativePath = ../..` even though `xcodebuild` often resolved it. Superseded the same day by selective symlinks after Previews broke.
