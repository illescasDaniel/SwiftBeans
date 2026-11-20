---
name: example-plugin-pbxproj-attachment
description: Attach the plugin in project.pbxproj as plugin:SwiftBeansPlugin; registry property must be internal, generated file imports Foundation
type: gotcha
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

Xcode's "Run Build Tool Plug-ins" UI is easy to miss. Attach via `XCSwiftPackageProductDependency` with `productName = "plugin:SwiftBeansPlugin"` plus a `PBXTargetDependency`. The first example build failed on a `fileprivate` registry property and missing `Foundation` in generated code, so the property is internal and the generated file imports `Foundation`.
