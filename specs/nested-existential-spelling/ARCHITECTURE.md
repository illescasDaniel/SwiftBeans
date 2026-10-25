# Nested existential spelling — architecture

## Authority and scope

- Design: [DESIGN.md](../../design/nested-existential-spelling/DESIGN.md), approved in chat 2026-10-25.
- Specification: [SPEC.md](SPEC.md), approved in chat 2026-10-25.
- Architecture: Phase 2 approved in chat on 2026-10-25.
- Implementation boundary: internal declarations in `SwiftBeansGeneratorCore` and its tests.

No public/package API change, manifest change, runtime change, macro change or plugin invocation
change is needed. Proposed signatures below establish contracts; they are not production additions
in this phase. Project source indentation remains tabs.

## Type identity and emitted structure

Keep `TypeKey` and `BeanKey` unchanged as equality, graph validation, naming, registry and dump
contracts. Add `EmittedType.swift` containing the following internal value representation:

```swift
indirect enum EmittedType: Equatable, Sendable {
	case nominal([NominalComponent])
	case array(EmittedType)
	case dictionary(EmittedType, EmittedType)
	case existential(EmittedType)

	struct NominalComponent: Equatable, Sendable {
		var name: String
		var genericArguments: [EmittedType]
	}

	var key: TypeKey { get }
	var description: String { get }
	static func unmarked(_ key: TypeKey) -> EmittedType
	func merging(_ other: EmittedType) -> EmittedType
}
```

`key` recursively erases existential wrappers. `description` renders canonical collection syntax,
nominal components and argument order with explicit wrappers at their recorded positions. Parentheses
are emitted only when required by the supported type grammar. `unmarked` reconstructs the existing
canonical spelling for keys without existential evidence; it never classifies names as protocols.

`merging` requires equal normalized keys. It unions existential wrappers at corresponding structural
positions and merges matching children. A wrapper is idempotent: merging two `any P` records yields
one `any P`. A wrapper around a generic nominal is distinct from wrappers on its arguments. Merging
is associative, commutative and idempotent for equal keys, ensuring source-order independence.
Different keys must never be merged; grouping by `TypeKey` establishes this invariant before calls.
Do not add a client diagnostic for an internal grouping error.

This recursive value is small generation-time metadata. It has no references to runtime instances,
syntax-node ownership, locks or actors.

## Capture and normalization seam

Extend `KeyNormalization.Normalized` to retain emitted structure alongside the existing key and
outermost `spelledWithAny` fields. Preserve those legacy fields while existing callers need them;
the key must equal the emitted structure's erased key. Existing acceptance/rejection rules remain
in `KeyNormalization`, with one structural traversal producing both results. Do not add a second
parser, textual `any` substitution or reparsing during rendering.

The traversal preserves existential wrappers before normalizing their constraints. Existing
parenthesis/attribute handling, nominal member structure and collection desugaring remain the
normalizer's responsibility. Unsupported types continue through the same `UnsupportedKey` paths.

`DeclarationScanner` already calls normalization for bean returns, bound services, parameters and
context inputs. Their successful normalization results now carry emitted structure. For defaulted
parameters, normalize precisely the existing `keyType` projection, including the current wrapped
optional handling; this feature does not broaden or narrow that projection. Original source strings
continue to support diagnostics and source-spelled assisted arguments/input declarations.

Add the following stored metadata at resolution boundaries:

| Existing record | Additional information | Inclusion rule |
|---|---|---|
| `BeanProvider` | `emittedType: EmittedType` | Required for each resolved provider; normalized key agrees with `key.type` |
| `BeanParameter` | `emittedType: EmittedType?` | Only for a successful non-assisted dependency key, including defaulted dependencies |
| `FactoryType` | `returnEmittedType: EmittedType` | Only for a supported factory return |
| `ContextInputDecl` | `emittedType: EmittedType` | Successful input normalization |

`ParameterInfo.key`, `BeanDecl.returnKey` and `ServiceDecl.boundTo.key` carry the richer normalized
result without parallel raw-type storage. `FactoryNormalization` retains its existing argument
canonicalization and adds return metadata from successful return normalization.

`ProviderResolver` copies metadata into resolved providers and accepted dependency parameters.
For assisted parameters, retain `AssistedArgument.typeSpelling` and `canonicalType`; do not expose
assisted arguments as spelling evidence. For factories, the dependency emitted-type field is nil
and only `returnEmittedType` contributes. For ignored unsupported defaults, both are absent.
`ContextGraph` copies input metadata when constructing its existing synthetic input providers.

Keep `elementSpelledWithAny` and the collection injection policy unchanged. They answer whether
an empty collection is allowed, a different question from accessor spelling. Existing
`spelledWithAny`/`returnSpelledWithAny` fields may remain as compatibility projections, but
`CodeGenerator` must stop using their flat `anyTypes` set as its type-rendering authority.

## Evidence and ownership planning seam

Add `AccessorTypePlanner.swift`. It accepts validated owner/visibility data and returns an immutable
plan before any accessor is rendered. Use existing `ProviderID(owner:key:)` and `GraphProvider`
identity rather than inventing another owner identity.

```swift
struct AccessorTypeView {
	var visible: [GraphProvider]
}

struct AccessorTypePlan {
	let typesByProvider: [ProviderID: EmittedType]
	func types(ownedBy owner: String) -> [BeanKey: EmittedType]
}

enum AccessorTypePlanner {
	static func plan(views: [AccessorTypeView]) -> AccessorTypePlan
}
```

`typesByProvider` includes context inputs as evidence-bearing providers, even though their stored
properties are not emitted as accessors. The generated input protocol requirement continues to
use its original `inputType` string. The planner's result must never overwrite source-spelled
input declarations or assisted argument signatures.

Planning is a reduction over original metadata:

1. For each visibility view, group original evidence by complete `TypeKey`. Evidence is each
	visible provider's emitted type, its accepted dependency emitted types, and supported factory
	return emitted types. Qualifiers do not partition this map. Union only equal complete keys.
2. For each provider visible in that view, contribute the map entry matching its complete type
	to that provider's owner-qualified result. Union it with its own emitted type and contributions
	from other views containing that provider.
3. Freeze the result for all owners before generation begins. Do not feed a synthesized result
	back into any view's source evidence map.

This implements the spec's ownership-wide contract directly: a root accessor visible to several
children gets one declaration incorporating applicable evidence from those views. A child-owned
provider receives no evidence from sibling-only views. No change to visibility, ownership or
lookup follows from the evidence plan.

Use per-view maps and traverse existing visible providers; do not scan the complete graph for each
source type. Complexity is proportional to syntax/evidence processed through existing visibility
views and the corresponding type merges, with storage for those maps and resulting provider types.
There is no transitive fixed-point computation or global registry of protocol names.

## Root-only and child-context orchestration

`SwiftBeansGeneration.generate(sources:)` retains the existing root-only validation path. After
validation, adapt its providers into one view whose owner is the root context's existing name,
then plan emitted types and pass that owner's map to `CodeGenerator`. A target without a root
continues to produce header-only output without requiring a type plan.

`ContextGraph.generate` retains its current graph partitioning, bindings and diagnostics. Build
all existing `ContextCodePlan` values and validate them first. After successful validation, derive
one `AccessorTypeView` from each plan's existing `visible` records, build one shared spelling plan,
and supply each owner's map to its generation call. Rendering order cannot affect evidence.

No context hierarchy expansion is implied: use the visibility views the package supports today.
The spec's independent-tree isolation is also checked by separate generation requests because
current validation permits one root per target; existing multiple-root rejection stays intact.

Failure results still return through existing diagnostic paths with no successful context output.
The planner introduces no diagnostics and does not perform provider selection or graph validation.

## Rendering contract

Extend the internal generator entry point with an explicit owner-local type map:

```swift
static func generate(
	context: ContextDecl?,
	providers: [BeanProvider],
	imports: [ImportRecord],
	accessorTypes: [BeanKey: EmittedType],
	plan: ContextCodePlan? = nil,
	includePreamble: Bool = true
) -> String
```

`CodeGenerator` resolves the emitted type once per owned provider using `accessorTypes`, and uses
that same spelling in protocol requirements, property accessors and assisted return declarations.
A validated non-input provider must have an entry. Do not silently substitute normalized key text
for missing metadata. The header-only path accepts an empty map.

Context input protocol requirements keep `ContextCodePlan.typeSpelling` and source spelling.
Assisted argument labels/spelling continue through `signature(_:)`. Dependency expressions,
factory closures, `path(_:)`, construction expressions, registry keys, guards and scope code remain
on their existing paths. `GraphDump` continues using normalized keys and does not read the plan.

## Compatibility boundaries

- Unmarked rendering reproduces the existing `TypeKey.description` output exactly.
- Root-only outermost evidence has the same sources and qualifier sharing as the old `anyTypes`
	set; extending it recursively must not remove existing outer markers.
- Canonical type formatting changes only where required to retain applicable markers.
- Normalization outcomes, rejection diagnostics and parameter default behavior remain unchanged.
- Internal initializer/test fixtures must supply real emitted metadata or explicitly unmarked
	metadata for concrete types; do not add a production default that masks omitted evidence.
- No runtime, isolation, lifetime, macro or import contract is extended.

## Scenario-to-test map

Use Swift Testing in `SwiftBeansGeneratorCoreTests`; read the modernize-tests skill before adding
tests. The following files are proposed test seams, not implementation requirements on filenames.

| Scenarios | Test seam | Observable assertions |
|---|---|---|
| S01–S05 | `GeneratorExistentialSpellingTests` | Both generated declaration sites preserve canonical markers at every supported position; no consumer required |
| S06–S08 | `EmittedTypeTests`, generator output tests | Structural merge laws plus positional union, complete-type isolation and unchanged concrete output |
| S09–S12 | Generator output tests | Consumer/default/factory evidence, qualified variants and existing top-level behavior |
| S13–S15 | Output tests and compiler fixtures | Assisted method/protocol signatures, argument non-evidence, unchanged factory matching and valid call sites |
| S16–S17 | Existing collection suite plus focused regressions | Explicit array precedence; unchanged member order, empty/default behavior and no invented accessors |
| S18–S20 | `GeneratorChildContextTests` or focused spelling suite | Parent declaration corrected once, no sibling contamination, independent requests isolated, inputs retain exact spelling |
| S21 | Planner and output permutation tests | Source declaration order, file ordering and visibility processing permutations yield identical spellings |
| S22–S25 | Diagnostic regressions | Exact diagnostic IDs and positions; no output for invalid graphs; unsupported defaults stay omitted |
| S26 | Compatibility regression tests | Dumps, keys and generated wiring match baseline except expected type spellings; existing lifecycle suite remains green |
| S27 | Output boundary test | No marker without explicit evidence and no external semantic lookup |

Test `EmittedType.key` against existing normalization results, including existential wrapper versus
argument positions, to ensure identity remains erased. Merge tests check the observable rendering
and algebra rather than private storage. Generator tests must assert both declaration sites; a
substring occurring only once cannot establish protocol/accessor agreement.

### Compiler fixtures

Add `GeneratedExistentialContractCompileTests` using the local compiler/runtime/macro loading pattern
in `GeneratedChildContractCompileTests`. A narrowly shared compile helper is acceptable if needed,
but do not refactor unrelated fixtures for this feature. Compile actual source plus actual generated
output with `-swift-version 6`, strict concurrency and warnings as errors. Parameterize ordinary
settings and `-enable-upcoming-feature ExistentialAny`. Locate existing products through the current
`SWIFTBEANS_TEST_PRODUCTS` convention; use unique temporary directories and drain compiler output.

Fixtures declare actual protocols, conformers and unconstrained containers. Cover arrays,
dictionaries with concrete keys, nested generic arguments, assisted returns, deferred/assisted
factory calls and parent/child access. Include a concrete fake conforming to the generated protocol
and use its members to exercise declaration agreement. Source that deliberately omits `any` for
inference tests belongs in generator output fixtures, not in the strict compiler fixtures.
Dictionary-key existential retention remains a spelling test, not a claim of `Hashable` conformance.
A compiler or fixture setup failure is a failed check, not a silent skip.

## Test-first sequence and verification

After architecture approval:

1. Add generator output and compiler regressions that compile as tests against current production
	interfaces and fail because generated declarations lose nested markers. Record red-phase output
	and diagnostics; missing symbols or failing fixture setup are not valid red evidence.
2. Introduce the approved internal representation/contracts with minimally implemented operations
	as needed for unit tests; representation tests must compile and fail meaningful assertions before
	completing those operations. Preserve the initial generator red evidence independently.
3. Implement metadata capture, planning and rendering, then run focused checks and `swift test`.
	Compare unaffected output and graph dumps, and run the compiler fixtures in both modes.
4. Record scenario mapping and gate results in `VERIFICATION.md`. Have an independent read-only
	reviewer grade the diff against approved artifacts and project conventions, using the skill's
	grader instructions. Resolve findings under the permitted review rounds.

No example behavior changes or new UI tests are required. The generated-source compiler suite
provides direct coverage of the changed generator contract. No commit, push, release or version
change is authorized merely by this architecture proposal.

## Approval requested

Reply `architecture approved`, or request changes. Approval authorizes test-first implementation
and independent grading under Phases 3–5; production behavior remains unchanged until then.
