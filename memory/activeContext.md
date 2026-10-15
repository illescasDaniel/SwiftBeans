# Active Context

_Last updated: 2026-10-15_

## Branch

- `main`

## Current focus

None — plugin source-discovery fixes (review #1–4) implemented and committed 2026-10-15. `swift test` (42) + example `xcodebuild test` green; SPM fixture (scratchpad) verified nested folders, excluded file, parent config ignored, config add/edit regeneration, config errors; Xcode verified config error fails the build.

## Just changed

- `ScanSetResolution.swift` (parser + resolver; GeneratorCore canonical + plugin copy + drift test)
- Plugin rewritten: build-system files only, `.swiftbeans.yml` at scan root only, local package sources + config declared as inputs
- Generator: no `--config` / upward search; dedupes + sorts inputs; rejects unknown `--` options
- Removed `ScanConfigurationLoader` and public `SwiftBeansScanConfiguration`
- Example entry renamed `MyApp.swift` → `SwiftBeansExampleApp.swift`

## Next steps

0. Next review items: type-key normalisation / accessor naming / file:line diagnostics (#5–10); registry once-only creation (#15)
1. Optional: push `main` when ready
2. Docs / README usage polish for compile-time DI (include HTTIES `@Bean` + `AppContextProtocol` / `FakeAppContext` pattern)
