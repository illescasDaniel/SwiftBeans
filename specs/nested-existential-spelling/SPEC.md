# Nested existential spelling

## Metadata

- **Feature:** Preserve nested existential markers in generated Swift types.
- **Status:** Phase 1 approved in chat on 2026-10-25.
- **System design:** [design/nested-existential-spelling/DESIGN.md](../../design/nested-existential-spelling/DESIGN.md)
- **Design approved:** 2026-10-25 (chat).
- **Design decisions approved:** 2026-10-25 through approval of the design's outcome, failures, resource, trust and compatibility sections; elaborated contracts below await spec approval.
- **Spec approved:** 2026-10-25 (chat).
- **Related:** `specs/compile-time-di/SPEC.md`, `specs/collection-injection/SPEC.md`, `specs/factory-injection/SPEC.md`, `specs/qualifiers/SPEC.md`, `specs/child-contexts/SPEC.md`.
- **Affected module:** `SwiftBeansGeneratorCore`; no new runtime or macro API.

## Design decisions

### Success criteria

Supported nested types retain every applicable explicit `any` in generated accessor types and
matching context protocol requirements. Valid fixtures compile both with ordinary settings and
with `-enable-upcoming-feature ExistentialAny`. Identity, dependency wiring, names and lifetimes
remain unchanged. Ordinary and assisted accessors use the same spelling contract.

### Failure handling

Existing graph and type validation remains authoritative, including unsupported-key/factory,
duplicate-provider, missing-dependency and assisted-injection diagnostics. No new diagnostic,
retry or partial-success mode is introduced. The generator preserves explicit type information;
the Swift compiler remains responsible for semantic type validity and existential conformances.

### Performance and resource budget

Generation stores and processes information proportional to supported source-type structure and
existing graph visibility relationships. Accumulate evidence per normalized complete type and
owner visibility; do not compare every source type against every provider. No additional source
scan, external lookup, subprocess or runtime operation is required. No numeric latency threshold
is imposed because this is a structural correctness change, not a performance feature.

### Trust boundary

Client source and configuration remain inputs to the existing scanner and validators. Preserve
existential positions structurally from parsed types, not by text replacement in source. An emitted
type representation does not authorize otherwise unsupported graph types. No paths, imports,
source discovery or configuration permissions change.

### Compatibility and rollout

No public declaration, minimum Swift version or platform requirement changes. Regeneration fixes
affected declarations automatically. Generated source without applicable nested evidence remains
byte-identical, including existing outermost existential behavior. Normalized graph dumps remain
unchanged. For affected declarations, adding nested markers is an explicit exception to the older
collection-injection spec's output-stability guarantee; collection resolution rules do not change.
No version bump, release or feature flag is included. Reverting the generator restores old output
and its known limitation.

## Public API and contracts

### Identity and emitted spelling

`TypeKey` remains normalized recursively: `P` and `any P` share identity; arrays and dictionaries
use existing canonical identities; qualifiers remain in `BeanKey`. The generator additionally
retains recursive emitted-type information that distinguishes an existential wrapper at each
supported position. This information must not participate in dependency equality or naming.
Architecture will define its internal type and access levels.

Supported positions include the whole type, array element, dictionary key/value, and generic
arguments on any nominal component. Nested combinations are supported to the same extent as
existing key validation. `any` wraps its actual constraint at that position; for example,
`Box<any P>` and `any Box<P>` are structurally distinct spellings, even if the normalizer accepts
both with the same key. This feature does not promise either spelling is semantically valid Swift.

Canonical rendering retains existing nominal qualification and generic argument order, renders
`Array<T>` as `[T]` and `Dictionary<K, V>` as `[K: V]`, and normalizes redundant parentheses and
whitespace as existing generated key spelling does. Explicit existential wrappers must survive
these transformations. Concrete names never acquire `any` without corresponding explicit evidence.

### Applicable spelling evidence

An evidence record contains a normalized **complete type** plus its existential positions.
The positions are combined by union only among records for that same complete type.
For example, `Pair<any P, Q>` and `Pair<P, any Q>` combine to `Pair<any P, any Q>`;
`Box<any P>` supplies no nested evidence for `OtherBox<P>`, standalone `P`, or `[P]`.
A complete `any P` record still supplies the existing outermost evidence for standalone `P`.
Nested subtrees are not independently promoted into complete-type evidence.

Gather source evidence from:

- Provider return/binding types, including providers with assisted parameters.
- Non-assisted dependency parameter types accepted by existing key normalization, including
	defaulted parameters. A default staying in use does not erase its explicit type evidence.
- Supported factory return types, whether deferred or assisted.
- Child-context input types, which already serve as providers.

Assisted argument declarations retain their existing source spelling. Assisted arguments do not
become graph dependencies or independently contribute spelling evidence. Unsupported parameter
types that keep defaults do not gain graph-type support through this feature. Factory argument
matching continues to use existing canonical identities; only its return type contributes evidence.

For root contexts without child contexts, preserve existing outermost evidence behavior across
the graph's providers, dependency parameters and factory returns, extending it recursively.

### Ownership and visibility

Compute the spelling of each generated accessor once at its declaring owner. For provider `p`,
consider every context whose existing visibility view contains `p` (including its owner). Collect
source evidence from providers and their parameters/factory returns in those views, restricted to
the same complete normalized type as `p`. Qualifiers do not partition type spelling evidence.
Union their explicit positions with `p`'s own type evidence. Emit that same result for `p`'s
accessor and its owner's protocol requirement.

This means a child consumer may supply evidence for a parent accessor visible to that child.
All uses of that parent accessor observe the single corrected declaration. Evidence from a sibling
that cannot see a child-owned provider does not affect that child-owned provider. Separate context
trees do not exchange evidence. Ancestor input providers retain their already source-spelled
property declarations; do not rewrite stored inputs or synthesize duplicate accessors.

Collect only original source evidence, not markers synthesized into other generated declarations.
There is no iterative propagation of inferred markers between views. This gives deterministic
results independent of declaration order, file order and the order contexts are generated.

### Generated output and unchanged behavior

For `@Bean static func handlers() -> [any Handler]`, both declarations must contain:

```swift
// Context protocol
var handlerArray: [any Handler] { get }

// Context extension
var handlerArray: [any Handler] { /* existing construction and scope code */ }
```

For an assisted provider, preserve the generated method name, argument labels and argument spelling;
its return type and corresponding protocol requirement follow this same rendering policy.
Context inputs continue using their declared property names and source-spelled types.

Registry keys, graph dumps, collision diagnostics, qualification, dependency bindings and construction
expressions are unchanged. An explicit array bean still wins over collection members. Arrays
assembled through multi-binding still use existing member accessors; nested spelling does not
create additional beans or collection accessors. Factory closures call the same target accessors.
Isolation, locking, caching, managed cleanup and owner lifetime rules do not change.

### Validation obligations

Output assertions cover every supported position, complete-type evidence boundaries, qualification,
context ownership and deterministic ordering. Generated-source compiler fixtures must compile valid
protocol/implementation pairs and representative call sites, including arrays, dictionary values,
unconstrained generic arguments, nested combinations, assisted returns, factories and parent/child
access. Run those fixtures with ordinary settings and `ExistentialAny` enabled.

Dictionary-key spelling must have an output test. Do not require a compiler fixture claiming that
`any Hashable` itself satisfies the dictionary key's `Hashable` constraint; semantic conformance is
outside this generator correction. Use concrete dictionary keys for valid compiler fixtures.

Run `swift test`, feature compiler checks and an independent read-only conformance review after
architecture approval and test-first implementation. Structural spec validation alone does not
establish feature correctness.

## Acceptance criteria

### Scenario: S01 — Explicit array bean without consumers

**Given** a bean returning `[any P]` and no consumer of that array
**When** generation succeeds
**Then** its property and protocol requirement use `[any P]`, keeping the existing accessor name and registry key.

### Scenario: S02 — Equivalent collection syntax

**Given** otherwise equivalent beans spelled `Array<any P>` or redundantly parenthesized `[any P]`
**When** generated separately
**Then** their accessor types render canonically as `[any P]` with identical normalized identity and names.

### Scenario: S03 — Dictionary positions

**Given** individually supported dictionary source types `[String: any P]`, `Dictionary<String, any P>` and `[any P: Value]`
**When** generating their declarations separately
**Then** canonical emitted types preserve the marker at the corresponding value or key position without asserting semantic conformance of existential keys.

### Scenario: S04 — Nominal generic arguments and qualification

**Given** a supported bean returning `Module.Outer<any P>.Inner<any Q>`
**When** generating declarations
**Then** nominal qualification, argument order and both existential positions survive in the accessor and protocol requirement.

### Scenario: S05 — Nested combinations

**Given** a valid bean returning `Box<[String: [any P]]>`
**When** generating and compiling its context
**Then** the nested element retains `any`, and protocol conformance and accessor calls compile under ordinary and ExistentialAny settings.

### Scenario: S06 — Markers merge at corresponding positions

**Given** a provider and applicable dependency evidence for `Pair<any P, Q>` and `Pair<P, any Q>`
**When** generating its accessor
**Then** both declarations use `Pair<any P, any Q>` without changing the dependency key.

### Scenario: S07 — Complete-type evidence boundary

**Given** evidence for `Box<any P>` and separate providers for `OtherBox<P>`, `[P]` and `P`, with no other existential evidence
**When** generating declarations
**Then** that nested evidence changes only the `Box<P>` declarations, not the unrelated complete types or standalone `P`.

### Scenario: S08 — Concrete types stay concrete

**Given** beans returning `[String]`, `[String: Int]` and `Box<Value>` without applicable existential evidence
**When** generating declarations
**Then** no `any` is inserted and existing generated output is byte-identical.

### Scenario: S09 — Consumer supplies nested evidence

**Given** an array provider spelled `[P]` and an injectable dependency spelled `[any P]` in its applicable visibility views
**When** generating declarations
**Then** the array accessor and its protocol requirement use `[any P]` and the consumer still calls that accessor.

### Scenario: S10 — Defaulted dependency evidence

**Given** a supported defaulted dependency spells a complete type with nested `any` and an applicable provider of that type exists
**When** generating declarations
**Then** that spelling contributes evidence and default-selection behavior remains as defined by existing injection rules.

### Scenario: S11 — Qualifiers share spelling evidence

**Given** qualified providers of the same normalized complete type, one spelling a nested existential explicitly, visible together
**When** generating their declarations
**Then** both use the combined type spelling while qualifiers still select distinct providers, accessors and registry keys.

### Scenario: S12 — Existing outermost existential inference

**Given** explicit outermost `any P` evidence from a provider, accepted dependency or factory return type
**When** generating equivalent top-level `P` accessors
**Then** existing outermost-`any` output remains unchanged, including qualification behavior.

### Scenario: S13 — Assisted return type

**Given** an assisted bean returning `[any P]`
**When** generating and compiling a caller of its method accessor
**Then** the method and protocol requirement return `[any P]`, preserve assisted labels and source-spelled arguments, and compile in both settings.

### Scenario: S14 — Assisted arguments remain source-spelled

**Given** an assisted argument spelled `Box<any P>` and an unrelated injectable `Box<P>` provider with no other evidence
**When** generating declarations
**Then** the assisted argument retains its source spelling without contributing evidence to the unrelated provider or becoming a dependency.

### Scenario: S15 — Factory return evidence

**Given** a deferred factory `() -> [any P]` or an assisted factory `(Item) -> Box<any P>` targeting an existing normalized provider
**When** generating each valid fixture
**Then** the target accessor and protocol requirement retain the factory return's nested markers, factory matching is unchanged, and calls compile in both settings.

### Scenario: S16 — Explicit array provider retains precedence

**Given** an explicit `[any P]` bean, individual P members and a consumer of `[any P]`
**When** generating its construction expression
**Then** the consumer calls the array accessor, whose declarations preserve `any`, rather than assembling a member array.

### Scenario: S17 — Multi-binding remains unchanged

**Given** a collection dependency with individual members and no explicit array provider
**When** generating its injection
**Then** existing membership, ordering, empty/default rules and member accessor calls are unchanged, and no collection accessor is introduced.

### Scenario: S18 — Child evidence corrects a parent declaration once

**Given** a parent-owned `[P]` bean and a child dependency on that visible bean spelled `[any P]`
**When** generating the context tree
**Then** the parent accessor and parent protocol requirement both use `[any P]`, the child references the parent accessor without redeclaring it, and valid source compiles in both settings.

### Scenario: S19 — Visibility limits sibling and tree evidence

**Given** a child-owned provider, nested evidence only in a sibling that cannot see that provider, and another independent context tree
**When** generating declarations
**Then** that inaccessible evidence changes neither the child-owned provider nor declarations in the independent tree.

### Scenario: S20 — Child inputs preserve their declarations

**Given** a child input declared `[any P]` that participates in dependency injection
**When** generating its protocol and consumers
**Then** its existing input name and source-spelled type survive, matching complete-type providers receive applicable evidence, and ownership and input storage are unchanged.

### Scenario: S21 — Output is independent of traversal order

**Given** the same graph and original source evidence with files, declarations or context traversal reordered
**When** generating output
**Then** existential spelling and the existing deterministic output order are identical, with no iterative propagation of synthesized evidence.

### Scenario: S22 — Unsupported types remain rejected (F1)

**Given** a provider type or factory return type rejected today, including optional, opaque or composition types
**When** generating its graph
**Then** existing unsupported-key or unsupported-factory diagnostics and source positions remain, and no successful context is produced for the invalid graph.

### Scenario: S23 — Equivalent existential spellings remain duplicates (F2)

**Given** two providers with equal qualifiers and normalized keys spelled `[P]` and `Array<any P>`
**When** validating the graph
**Then** existing `graph.duplicateProvider` diagnostics identify both declarations rather than creating separate dependencies.

### Scenario: S24 — Missing and assisted dependencies still fail (F2)

**Given** a required non-collection dependency without a provider, or a direct dependency on an assisted provider
**When** validating each graph with nested existential spelling evidence
**Then** existing `graph.missingDependency` or `assisted.notInjectable` diagnostics remain and spelling evidence does not supply a value or bypass validation.

### Scenario: S25 — Unsupported default remains a default

**Given** an unsupported defaulted dependency which existing rules omit from injection
**When** generating an otherwise valid graph
**Then** it keeps its default and introduces no new supported key, emitted accessor or spelling evidence.

### Scenario: S26 — Dumps and runtime behavior are stable

**Given** equivalent graphs before and after the spelling correction
**When** comparing normalized dumps, dependency bindings, generated scope/construction code and lifecycle behavior
**Then** only affected type spellings change; graph identity, registry keys, ownership, isolation and lifetime contracts remain unchanged.

### Scenario: S27 — Absent explicit evidence is not semantic inference

**Given** a provider and all applicable declarations omit `any` at a protocol position
**When** generating declarations
**Then** no marker is invented from the nominal name or external symbol lookup, and any Swift semantic error remains the compiler's responsibility.

## Out of scope

- New graph types, protocol compositions, opaque types, optional injection or existential conformance rules.
- Discovering protocols through semantic analysis or repairing client source that never spells required `any`.
- Changes to factory argument equivalence, qualifiers, collection resolution or graph dumps.
- Reformatting existing source-spelled assisted arguments or context input declarations.
- Runtime, macro, plugin discovery, platform, release, version or configuration changes.
- Type aliases gaining new semantic resolution behavior.
