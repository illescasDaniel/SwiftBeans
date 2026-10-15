# Active Context

_Last updated: 2026-10-15_

## Branch

- `cursor/collection-injection-53df` (from `main` @ 6b04703)

## Current focus

Collection injection (multi-bind) implemented: a `[E]` / `[any E]` parameter with no `[E]` bean receives every non-assisted bean that is an `E` (key `E`, or a scanned type declaring `: E`, transitively), sorted by accessor name; never the consumer itself. `[any E]` with no members → `[]`; plain `[E]` → missing dependency. Spec written as Draft; human approval of `specs/collection-injection/SPEC.md` still pending. No PR opened.

## Just changed

- `specs/collection-injection/SPEC.md` (new); pointers in `specs/compile-time-di/SPEC.md`
- `Sources/SwiftBeansGeneratorCore/ParameterInjection.swift` (new, shared by validator + codegen)
- `DeclarationScanner` (inheritance clauses, `elementSpelledWithAny`), `ProviderResolver` (`conformances`), `GraphValidator` (missing deps, cycle edges), `CodeGenerator`, `TypeKey` (`elementSpelledWithAny`)
- `Tests/SwiftBeansGeneratorCoreTests/GeneratorCollectionTests.swift` (21 tests) + `TypeKeyTests` case
- Linux: `SwiftBeansGeneratorMain` uses `FileHandle.standardError`; `GeneratedFileWriterTests` mtime tolerance
- README section, CHANGELOG

## Verified

- `swift test` on Linux: 155 tests (123 + 21 + 11) green
- Golden compatibility test passes against the base generator too; example-app sources generate byte-identical output base vs new
- Generated multi-bind literals type-check with `swiftc -swift-version 6` (stub registry)

## Next steps

1. Get approval of `specs/collection-injection/SPEC.md` (or adjust: membership by conformance is the main design call)
2. Example app: add trackers using `[any AnalyticsTracker]` and run example tests on macOS
3. Open PR when asked
