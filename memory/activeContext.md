# Active Context

_Last updated: 2026-10-15_

## Branch

- `main`

## Current focus

Runtime arguments (`@Assisted`, assisted injection) implemented (Phases 3–4, 2026-10-15): `Assisted` wrapper, generator method accessors, `GeneratorAssistedTests`, example `ItemDetailViewModel` as compile check; uncommitted. Next: commit, then the assisted-factory injection backlog item. Review batches (generator rules, example compile check) are committed on `main` (`31d6864`, `20a1dcf`).

## Just changed

- `SwiftBeansSyntaxRules` + macros diagnose at nodes; `@Inject`
- GeneratorCore: `DeclarationScanner`, `ProviderResolver`, `GraphValidator`, `CodeGenerator`, `TypeKey`; legacy parser/validator/codegen/`Naming` deleted; no dependency on `SwiftBeans`
- CLI `--input <json>`; plugin writes `SwiftBeansInput.json` (write-if-changed); output written only when changed
- `SwiftBeansRegistry`: NSCondition per-key once-only, re-entry traps

## Next steps

0. Commit the `@Assisted` work; then spec the assisted-factory injection backlog item
1. Example-app fixes from the review (the generated-code compile check landed: `Packages/GreetingKit`, `Features.WelcomeBanner`, `TagSummary`, `tagCounts` bean; ARCHITECTURE line "Still open from this document…" can now be dropped)
1. Optional: push `main` when ready
2. Docs / README usage polish for compile-time DI (include HTTIES `@Bean` + `AppContextProtocol` / `FakeAppContext` pattern)
