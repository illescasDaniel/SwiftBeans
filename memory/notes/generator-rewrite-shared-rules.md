---
name: generator-rewrite-shared-rules
description: Generator is a scanner, resolver, validator, codegen pipeline over TypeKey with collected positioned diagnostics
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

A `SwiftBeansSyntaxRules` module holds single-declaration rules; macros report them with `context.diagnose`, the generator reuses them only to decide what it can wire. Errors are collected as sorted `file:line:column` with notes; cycles use Tarjan SCC over injected edges only. The plugin hands files over as `SwiftBeansInput.json` (per-file module). `SwiftBeansRegistry` uses per-key slots so a singleton factory runs once.

**Why:** triggered by review items #5-11, #13-16 (raw-text key matching, first-initializer only, first-error-stops, import skip list, double factory runs). One rule source keeps macro and generator consistent.
