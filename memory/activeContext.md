# Active Context

_Last updated: 2026-10-15_

## Branch

- `cursor/graph-dump-53df` (base `main` @ `6b04703`)

## Current focus

Graph dump feature: done and pushed, awaiting review. Spec `specs/graph-dump/SPEC.md`.

## Just changed

- `Sources/SwiftBeansGeneratorCore/GraphDump.swift` (new): Markdown + DOT text from validated providers
- `SwiftBeansGeneration.swift`: `GenerationResult.graphMarkdown` / `graphDot` (nil on failure)
- `SwiftBeansGenerator`: `--graph-markdown` / `--graph-dot`; stderr via `FileHandle` (Linux Swift 6 fix)
- `SwiftBeansPlugin`: passes both paths; graph files intentionally NOT in `outputFiles` (SwiftPM would bundle them as resources)
- Tests: `GraphDumpTests` (12), `GeneratedFileWriterTests` mtime tolerance
- Docs: SPEC, ARCHITECTURE, README, CHANGELOG

## Blockers

- None. Not verified on macOS/Xcode (undeclared plugin outputs in the Xcode work folder); CI will exercise the example build.

## Next steps

1. Review/merge this branch
2. Later: `.swiftbeans.yml` toggle for the dump (out of scope in v1)
