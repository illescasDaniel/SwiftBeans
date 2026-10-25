# Nested existential spelling — verification

Date: 2026-10-25. Design, spec and architecture approved separately in chat on 2026-10-25.

## Test-first evidence

Before implementation, new `GeneratorExistentialSpellingTests` and
`GeneratedExistentialContractCompileTests` compiled successfully. The focused run failed with
missing nested markers in generated arrays, dictionaries, nominal generic arguments, consumer
inference, factory return types and child ownership output. Strict compiler fixture diagnostics
identified generated `[P]`, `Box<P>` and `[String: P]` declarations requiring `any P`.
The pre-existing explicit-array precedence test was updated to expect its corrected declaration.

Command: `swift test --filter 'GeneratorExistentialSpellingTests|GeneratedExistentialContractCompileTests|GeneratorCollectionTests'`.
Initial run: 36 test functions, 27 assertion issues. Four issues were inaccurate fixture expectations
(three diagnostic columns and one legacy closure argument spelling); these were corrected to the
existing behavior. The remaining failures exercised the intended gap, including the compiler error.

`EmittedTypeTests` then compiled against a minimal representation with unimplemented rendering and
merge operations. All three initial test functions failed with five assertion issues, covering
rendering, union and positional distinction. The completed operations made those tests pass.

Local logs during the session: `/tmp/swiftbeans-nested-red.log` and
`/tmp/swiftbeans-emitted-red.log`. These temporary paths are supporting evidence, not permanent
project dependencies.

## Scenario traceability

All listed suites are in `Tests/SwiftBeansGeneratorCoreTests/`.

| Scenarios | Test coverage |
|---|---|
| S01–S05 | `GeneratorExistentialSpellingTests`: supported-source-type matrix (13 cases); compiler suite's nested declaration fixture |
| S06 | Consumer-evidence test, declaration-order test and `EmittedTypeTests` positional merge laws |
| S07 | Nested-evidence/other-complete-types test |
| S08 | Concrete rows in supported-type matrix; existing `GeneratorCollectionTests` exact-output compatibility test |
| S09–S10 | Consumer-evidence test parameterized with and without a default |
| S11 | Qualified-variants binding and four-declaration check |
| S12 | Existing qualifier/collection compatibility and factory tests; their exact outermost-any output assertions remain unchanged |
| S13–S14 | Assisted-arguments output test checks both method declarations, source-spelled argument and unrelated unmarked provider; compiler suite exercises assisted calls |
| S15 | Factory-return evidence output test and compiler suite with deferred and assisted factories |
| S16 | Updated explicit-array precedence test in `GeneratorCollectionTests` |
| S17 | Existing collection suite, covering members, ordering, empty/default behavior and lack of aggregate accessors |
| S18 | Child-evidence/parent-declaration test; compiler suite child consumer |
| S19 | Sibling-evidence test and separate independent root generation; `AccessorTypePlannerTests` non-propagation test |
| S20 | Context-input exact spelling and injection test; compiler suite input consumer |
| S21 | Reordered-source and reordered-declaration tests; planner view/provider reversal assertions |
| S22 (F1) | Unsupported-provider and unsupported-factory matrices assert exact error IDs/locations and absent output |
| S23 (F2) | Duplicate-existential-keys test asserts both source locations and absent output |
| S24 (F2) | Invalid-dependencies test parameterized for missing and assisted providers |
| S25 | Unsupported-default test checks unmarked provider and omitted argument |
| S26 | Only-spelling-changes test compares complete generated output after replacing the affected type plus both graph dumps; unchanged package lifecycle/integration suites |
| S27 | Complete-type boundary controls and concrete/absent-evidence matrix rows; planner reads only original parsed metadata |

Additional `EmittedTypeTests` cover normalization/rendering round trips and equality of erased
identity. Planner tests prove synthesized parent evidence does not feed back into sibling declarations.

## Quality gates

- Focused implementation run: 39 test functions across four suites PASS, including generated-source
	compilation with ordinary settings and `ExistentialAny` enabled.
- Full package gate: `swift test` PASS, 307 test functions across 37 suites (19 runtime,
	27 macro, 247 generator and 14 plugin/integration functions), zero failures.
- Compiler fixtures compile original annotated client declarations plus actual generated code,
	with Swift 6, complete strict concurrency and warnings as errors. A concrete fake conforms to the
	generated protocol; call sites exercise context, fake, factories and child access.
- No example/UI behavior change. Existing plugin-backed package integration tests remain part of
	the full gate; dedicated generated-source fixtures validate the changed spelling directly.
- The initial sandboxed Swift command could not write the compiler cache. Approved execution of
	the same Swift test commands supplied cache access; this was environment setup, not red evidence.

## Independent review

Initial independent review: NEEDS WORK. Two findings:

1. The new member-base guard rejected valid `(any P).Alias`; restore legacy canonical `P.Alias`
	while preserving generic argument markers in the qualification base.
2. S13 needed an explicit assisted `[any P]` compiler call; the initial compiler fixture covered
	assisted `Box<any P>` only.

Fix round 1 added qualified-alias output regressions and reproduced their rejection before the
normalizer correction (`/tmp/swiftbeans-member-red.log`). The normalizer now removes existential
wrappers only from the member qualification base before appending nominal components. Both
`(any P).Alias` and `(any Box<any P>).Alias` have output regressions. The compiler fixture includes
a real protocol-extension alias plus a qualified assisted-array provider, fake method and call.

Full `swift test` after these fixes: PASS, 307 functions, zero failures; compiler fixture passes
ordinary and ExistentialAny modes. Structural and whitespace checks pass. Independent follow-up
review: PASS on all seven criteria, no remaining actionable findings after one fix round.
Final scorecard: [REVIEW.md](REVIEW.md).

## Example demonstration follow-up

Requested in chat on 2026-10-25 after the package feature's completion. This extends the example's
coverage of the approved package contracts without changing library behavior or lifecycle policy.

- `AppConfiguration.highlightedNotes` is `@Bean(named: "highlights")` returning `[any FeatureNote]`
	with explicitly chosen `[factory, assisted]` order. It uses injected member singletons.
- `FeaturesDemoViewModel` receives that named array alongside its existing automatic collection;
	`FeaturesDemoView` displays both demonstrations. The existing automatic list is unchanged.
- `FakeAppContext` conforms to the new generated requirement with the same existential array
	type and its own shared member instances.
- `GeneratedWiringTests` reads the array through `any AppContextProtocol`, parameterized for the
	real and fake contexts; checks chosen order, exact concrete singleton identities, named injection
	into the model, and unchanged automatic collection order.
- `AppContextScopeTests` checks two real child repositories have distinct identities and proper
	model sharing; closing one closes only its own repository. The sibling can still resolve its
	model, and root-owned highlight members remain usable. It closes both contexts.
- Existing child-context tests already cover runtime cleanup/cancellation, macro expansion,
	diagnostics, generated source compilation, plugin-backed wiring, ownership release and
	resolution-after-close exits. Their 64-scenario mapping remains in
	`specs/child-contexts/VERIFICATION.md`; no missing child-context suite was discovered.

Quality gates:

- macOS example `xcodebuild test`: PASS, 54 functions / 64 executions, zero failures/skips/runtime
	warnings in the result summary. Log: `/tmp/swiftbeans-nested-example-macos.log`.
- Generic iOS Simulator `xcodebuild build`: PASS. Log: `/tmp/swiftbeans-nested-example-ios.log`.
- Plugin output inspected: `highlightsFeatureNoteArray: [any FeatureNote]` appears in both the
	context protocol requirement and accessor; construction injects it into `FeaturesDemoViewModel`.
- Both commands use `-project Examples/SwiftBeansExample/SwiftBeansExample.xcodeproj`,
	`-scheme SwiftBeansExample`, `-derivedDataPath DerivedData/SwiftBeansExample`,
	`-skipPackagePluginValidation` and `-skipMacroValidation`, with their platform destinations.
- The first example test build caught an incorrect test access to a parent accessor directly on
	a child context. The corrected test accesses parent-owned declarations through `AppContext`,
	preserving the existing owner boundary. No production ownership change was made.
- Package gate remains 307 passing functions from the feature validation; example changes do not
	modify package source or package tests.
- Supplemental independent example review: PASS on all seven criteria, no actionable findings;
	see `REVIEW.md`.
