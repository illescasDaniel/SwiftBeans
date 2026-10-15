# Active Context

_Last updated: 2026-10-15_

## Branch

- `cursor/inter-bean-call-diagnostic-53df` (from `main` @ 6b04703)

## Current focus

Inter-bean call diagnostic (cheap first step of the Spring-style inter-bean calls backlog item). Implemented and tested: `bean.directCall` warning.

## Just changed

- `specs/inter-bean-call-diagnostic/SPEC.md` (new; includes Spring investigation findings + future options)
- `Sources/SwiftBeansGeneratorCore/DirectCallAnalyzer.swift` (new); `DeclarationScanner` records call sites in `@Bean` and initializer bodies; `SwiftBeansGeneration` runs the analyzer
- `Tests/SwiftBeansGeneratorCoreTests/GeneratorDirectCallTests.swift` (15 tests)
- `SwiftBeansGeneratorMain`: `stderr` via `FileHandle` (Linux Swift 6); `GeneratedFileWriterTests` tolerant date compare (Linux)
- `swift test`: 148 tests green on Linux

## Next steps

1. Review/open PR for this branch (not opened by the agent)
2. Optional: verify the warning surfaces in Xcode/SwiftPM plugin output on macOS with the example app
3. Remaining backlog: proxies / instance `@Bean` / macro rewriting (see SPEC Future work)
