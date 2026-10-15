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
1. Example-app fixes from the review (the generated-code compile check landed: `Packages/GreetingKit`, `Features.WelcomeBanner`, `TagSummary`, `tagCounts` bean; ARCHITECTURE line "Still open from this document…" can now be dropped)
1. Optional: push `main` when ready
2. Docs / README usage polish for compile-time DI (include HTTIES `@Bean` + `AppContextProtocol` / `FakeAppContext` pattern)
