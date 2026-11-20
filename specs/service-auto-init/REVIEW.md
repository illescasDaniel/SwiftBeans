# Service auto-init — independent review

- **Date:** 2026-11-20
- **Reviewer:** independent read-only `code-grader` agent, graded against `SPEC.md` (including the
	Phase 4 amendment), `ARCHITECTURE.md` and project conventions.

## Round 1 scorecard

| # | Criterion | Score |
|---|---|---|
| 1 | Spec conformance | PASS |
| 2 | Design decisions | PASS |
| 3 | Architecture | PASS |
| 4 | Test quality | PARTIAL: test naming convention; no rule-level test for the `@Observable` exemption |
| 5 | Design fidelity | PASS |
| 6 | Scope | PASS |
| 7 | Conventions / docs | PARTIAL: README gaps, a stale doc comment, a `///` reason line, memory files |

## Fix round

All findings were resolved:
- The README covers markers on properties, exact compiler wording, subclasses, the attribute
	allowlist, the generated-init sample and an optional-`var` warning.
- The `@Observable` exemption is narrowed to underscore-prefixed backing storage and has two
	rule-level tests.
- Tests are renamed to Given/When/Then, with `// Scenario:` traceability comments.
- The doc comment and `TagSummary` comment are fixed.
- `LoginViewModel` now uses auto-init (`attempt` is given `= nil`).
- The spec's rule 8 wording is simplified.

## Final evidence

- `swift test`: 356 tests (19 + 54 + 262 + 14 + 7), all passing.
- Example: macOS `xcodebuild test` reports `** TEST SUCCEEDED **`, and the generic iOS Simulator
	build reports `** BUILD SUCCEEDED **`.
- `spec_check.py`: 0 hard failures. Tab check: clean.
