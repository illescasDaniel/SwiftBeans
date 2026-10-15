# Active Context

_Last updated: 2026-10-15_

## Branch

- `main`

## Current focus

Review #5–11, #13–16 (generator rules, diagnostics, registry once-only) implemented 2026-10-15 through all four SDD phases; `swift test` (113) and the example's `xcodebuild test` are green. Uncommitted. Later batches: architecture items (BeanScope module split, non-public GeneratorCore product) and example-app fixes.

## Just changed

- `SwiftBeansSyntaxRules` + macros diagnose at nodes; `@Inject`
- GeneratorCore: `DeclarationScanner`, `ProviderResolver`, `GraphValidator`, `CodeGenerator`, `TypeKey`; legacy parser/validator/codegen/`Naming` deleted; no dependency on `SwiftBeans`
- CLI `--input <json>`; plugin writes `SwiftBeansInput.json` (write-if-changed); output written only when changed
- `SwiftBeansRegistry`: NSCondition per-key once-only, re-entry traps

## Next steps

0. Commit this batch (when asked)
1. Example: add a local-package bean + nested / generic-collection / `any`-bound beans as the generated-code compile check (ARCHITECTURE → Testing seams), then the example-app fixes from the review
1. Optional: push `main` when ready
2. Docs / README usage polish for compile-time DI (include HTTIES `@Bean` + `AppContextProtocol` / `FakeAppContext` pattern)
