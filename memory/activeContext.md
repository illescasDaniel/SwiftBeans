# Active Context

_Last updated: 2026-10-15_

## Branch

- `cursor/local-package-scan-refresh-53df`

## Current focus

Fix the local-package known limitation: new files under a `.swiftbeans.yml` package join the graph without a clean build.

## Just changed

- `GeneratorRequest` (shared `ScanSetResolution.swift`, plugin copy kept identical) and `SwiftBeansGeneration.generate(request:)`: config + local packages are re-resolved on every generator run
- Generator CLI: `--request`; stderr via `FileHandle.standardError` (Linux concurrency); creates the output folder
- Plugin: thin; writes `SwiftBeansRequest.json`, declares scan root, config, package files and folders as inputs. Still a `buildCommand`: SwiftPM rejects source-built prebuild executables (see `decisions.md`)
- SPEC (Source discovery rule 4, Known limitations, 2 new scenarios), ARCHITECTURE, README, CHANGELOG updated
- Tests: `GeneratorRequestTests`; `GeneratedFileWriterTests` mtime comparison made tolerant (Linux ns precision); `swift test` green

## Next steps

1. Verify in Xcode (example app): add a file to `Packages/GreetingKit/Sources/GreetingKitLive/` and build without cleaning
2. Optional: binary-target generator to allow a true prebuild command
