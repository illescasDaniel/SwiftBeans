# Active Context

_Last updated: 2026-10-15_

## Branch

- `cursor/factory-injection-53df` (base `main` @ `6b04703`)

## Current focus

Factory injection (`specs/factory-injection/SPEC.md`): bean parameters `(Item) -> ItemDetailViewModel` (assisted factory) and `() -> T` (deferred factory). Implemented and tested on Linux; spec was written together with the implementation and still awaits human review.

## Just changed

- Generator: `FactoryType` / `FactoryNormalization` (`TypeKey.swift`), `FactoryBinding.swift`, `BeanParameter.factory`, `GraphValidator` step 3b (`factory.unresolved`, `graph.missingDependency`), cycle detection ignores factory params, `CodeGenerator` emits closures; scanner stores `factory` / `canonicalType`
- `GeneratorFactoryInjectionTests` (+ byte-identical baseline, verified against `main`)
- Example: `AppCoordinator` is a transient `@Service` taking `makeItemList` / `makeItemDetail` / `makeFeaturesDemo` factories; `FakeAppContext.appCoordinator`; tests updated (example not compiled on Linux: SwiftUI)
- `GeneratedFileWriterTests`: 1s mtime tolerance (Linux); `SwiftBeansGeneratorMain` Linux `FileHandle.standardError` fix kept

## Next steps

1. Review `specs/factory-injection/SPEC.md`
2. Run the example's `xcodebuild test` and iOS Simulator build on macOS (not verifiable on Linux)
3. Qualifiers is next in the suggested order
