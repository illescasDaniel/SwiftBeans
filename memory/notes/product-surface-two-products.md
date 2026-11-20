---
name: product-surface-two-products
description: Only two products (SwiftBeans, SwiftBeansPlugin); GeneratorCore uses package access; BeanScope stays in SwiftBeans
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

`SwiftBeansGeneratorCore` is not a product: its cross-module API uses `package` access, except `ScanSetResolution.swift`, which stays `public` to remain byte-identical with the plugin copy (plugins compile without a package name).

**Why:** generator IR must not leak into semver; `BeanScope` is part of the macro signatures users write, so a separate module would only add an import.
