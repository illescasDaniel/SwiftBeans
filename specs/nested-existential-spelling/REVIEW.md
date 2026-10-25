# Nested existential spelling — independent review

Date: 2026-10-25. Reviewer: fresh read-only agent `grade_nested_existentials`, following
`.cursor/skills/sdd-feature/agents/code-grader.md`. Diff reviewed: current working changes against
HEAD/main, including untracked feature source, tests and approved artifacts.

## Verdict: PASS — fix round 1

Pre-checks: 0 hard failures, 0 warnings. Whitespace/tab checks pass. Final `swift test` log confirms
307 passing test functions, including generated-source compilation in ordinary and ExistentialAny modes.

| # | Criterion | Score | Key evidence |
|---|---|---|---|
| 1 | Spec conformance | PASS | All 27 scenarios map to tests and implementation; see scenario map below and VERIFICATION.md |
| 2 | Design decisions honoured | PASS | Structural preservation, unchanged identity, bounded visibility processing and compatibility regressions |
| 3 | Architecture and module seams | PASS | Internal EmittedType and owner-qualified planner; runtime/macros/plugin unchanged |
| 4 | Test quality | PASS | Output, diagnostics, merge laws, ordering, ownership and actual compiler fixtures |
| 5 | Design fidelity | PASS | Shared accessor/protocol rendering; original evidence only; existing lifetime behavior retained |
| 6 | Scope discipline | PASS | Generator correction and focused documentation/tests only |
| 7 | Conventions and maintainability | PASS | Tabs, Swift Testing, changelog and project memory |

## Findings and resolution

Initial verdict was NEEDS WORK. Both findings were resolved in one fix round and independently rechecked:

1. **Compatibility regression:** the new nominal-member base guard rejected valid `(any P).Alias`.
	`Sources/SwiftBeansGeneratorCore/TypeKey.swift:212` now peels only existential wrappers from
	the member's qualification base. Existing canonical `P.Alias` remains valid; generic argument
	markers survive. Output matrix regressions cover both plain and generic bases, and a compiler
	fixture validates a real protocol-extension alias.
2. **S13 compiler coverage:** the initial compiler fixture covered assisted `Box<any P>` but not
	assisted `[any P]`. `Tests/SwiftBeansGeneratorCoreTests/GeneratedExistentialContractCompileTests.swift:80`
	now declares that assisted provider; line 93 adds its fake method and line 102 calls its real
	accessor. Both compiler modes pass.

Remaining actionable findings: **none**.

## Final scenario map

| Scenarios | Tests | Implementation |
|---|---|---|
| S01–S05 | Supported-type matrix; compiler fixture | Recursive normalization and rendering |
| S06 | Consumer positional merge; merge laws | EmittedType.merging |
| S07–S08 | Complete-type isolation; concrete compatibility | Complete-key evidence and canonical rendering |
| S09–S10 | Consumer/default and child array evidence | Parameter metadata → planner |
| S11–S12 | Qualifier and existing outermost-any regressions | Shared type evidence; unchanged qualifier identity |
| S13–S15 | Assisted output/non-evidence; factory tests; compiler calls | Assisted/factory return rendering |
| S16–S17 | Collection suite | Existing injection policy |
| S18–S20 | Parent, sibling, input and compiler checks | Owner-qualified visibility plan |
| S21 | Source/declaration/view permutations | Deterministic union before emission |
| S22–S25 | Exact diagnostic/default regressions | Existing validation and omission paths |
| S26 | Output/dump comparison; lifecycle suites | Existing wiring, dumps and runtime behavior |
| S27 | Absent-evidence controls | Explicit parsed evidence only |

The supported-source matrix has 13 cases after the alias additions. Tests, commands, red-phase
evidence and the detailed scenario mapping are recorded in [VERIFICATION.md](VERIFICATION.md).

## Example demonstration — supplemental independent review

User requested the example follow-up on 2026-10-25. The same independent read-only reviewer
inspected the example/README diff, actual generated plugin output, macOS xcresult and iOS build log.

**Verdict: PASS. All seven criteria PASS; no actionable findings.**

Evidence: named array declaration in `Examples/SwiftBeansExample/SwiftBeansExample/DI/AppConfiguration.swift:63`,
qualified model injection in `Presentation/FeaturesDemoViewModel.swift:37`, matching fake property in
`DI/FakeAppContext.swift:31`, real/fake identity and ordering assertions in
`Examples/SwiftBeansExample/SwiftBeansExampleTests/GeneratedWiringTests.swift:79`, and sibling/root
survival after cleanup in `SwiftBeansExampleTests/AppContextScopeTests.swift:60`.

Actual generated output preserves `[any FeatureNote]` in both declaration sites and injects the
named accessor separately from the unchanged automatic collection. The view displays model data
and the fake reuses its member instances. README describes the example accurately.

Validation independently confirmed: macOS 54 functions / 64 executions PASS, zero failures/skips/
runtime warnings; generic iOS Simulator BUILD SUCCEEDED; whitespace checks clean. Existing package
gate remains 307 passing functions. No new library API or lifecycle policy is introduced.
