# Nested existential spelling — system design

- **Date:** 2026-10-25
- **Status:** Phase 0 approved in chat on 2026-10-25.
- **Design approved:** 2026-10-25 (chat).
- **Spec:** `specs/nested-existential-spelling/SPEC.md`, to be written after design approval.
- **Direction selected in chat:** retain a recursive emitted-type representation separately from normalized dependency identity.

## Problem and outcome

A `@Bean` returning `[any Handler]` currently produces a context property and protocol requirement
typed `[Handler]`. `KeyNormalization` correctly removes existential markers for graph matching, but
`CodeGenerator` reconstructs declarations from that normalized `TypeKey`. The separate
`spelledWithAny` Boolean only preserves a marker at the outermost level. Generated code therefore
loses nested markers and can fail compilation with `ExistentialAny` enabled.

Preserve the location of explicit `any` throughout every currently supported graph type: arrays,
dictionaries, nominal generic arguments and nested combinations. Both ordinary property accessors
and assisted method return types must emit the same valid type as their generated context protocol
requirements. This is a generator correction, with no new client annotation or runtime API.

## Public surface and generated-code flow

For a bean declared `static func handlers() -> [any Handler]`, the generated declaration becomes
`var handlerArray: [any Handler]`. Its name and normalized key stay the same. Equivalent spellings
such as `Array<any Handler>` may retain the generator's canonical array formatting.

The existing flow remains: `SwiftBeansPlugin` invokes `SwiftBeansGenerator`, which uses
`SwiftBeansGeneratorCore` to scan declarations, resolve providers, validate graphs and emit source.
Only the generator core's type information and emitted type declarations change.

Within the core, source types feed two parallel representations:

| Representation | Responsibility | Consumers |
|---|---|---|
| `TypeKey` and `BeanKey` | Normalized dependency identity; qualifiers belong to `BeanKey` | `ProviderResolver`, graph validation, collection/factory matching, naming and graph dumps |
| Recursive emitted type (internal name decided in architecture) | Canonical Swift type structure retaining explicit existential markers at their original positions | `CodeGenerator`, carried through provider and context plans |

`DeclarationScanner` captures the information while syntax is available. `ProviderResolver` retains
it alongside normalized keys. `ContextGraph` and `ContextCodePlan` carry it without changing provider
ownership or lookup. `CodeGenerator` uses one rendering policy for protocol requirements and accessor
definitions. Rendering must not fall back to `TypeKey.description` in a way that discards nested markers.

`SwiftBeans` runtime, macro declarations, macro implementation, syntax diagnostics, plugin discovery
and the generator executable's invocation contract need no behavior changes.

## Contracts and invariants

- Graph identity continues to ignore `any` recursively. `[P]`, `[any P]` and `Array<any P>` still
	identify the same dependency, including duplicate-provider detection.
- Accessor names, registry keys, qualifiers, factory matching, collection membership and explicit
	array-bean precedence remain unchanged. Graph dumps continue to describe normalized graph keys.
- Preserve the existing outermost-`any` inference from provider, consumer and factory-return
	declarations. Extend spelling evidence to nested positions of the same normalized type, including
	qualified variants visible to the generated context. Combine explicit markers deterministically;
	declaration order must not change output. Do not infer that arbitrary nominal names are protocols.
- Nested evidence belongs to corresponding positions in equivalent complete types. Seeing
	`Box<any P>` does not by itself rewrite an unrelated `OtherBox<P>` or every occurrence of `P`.
	The spec must make these boundaries explicit with examples.
- Preserve provider-declared nested markers even when no consumer exists. Include nested evidence
	from injectable consumer types and factory return types when spelling the matching accessor.
- Existing source-spelled assisted arguments and child-context inputs must retain their markers;
	use them as spelling evidence when they participate in dependency resolution, without changing
	their existing declaration formatting unnecessarily. A child consumer must not change the
	declaration of a parent-owned accessor only within the child; owner declarations and protocol
	requirements must agree. The spec must pin down ownership-wide evidence collection.
- No change to context isolation, `Sendable` requirements, scope caching, factory execution,
	managed teardown or resolution-after-close behavior. The representation exists at generation time.

## Main flow and failure paths

1. Scan a source type and preserve its supported structure plus explicit existential positions.
2. Normalize the same type for dependency resolution, using the existing support restrictions.
3. Resolve and validate the graph using normalized keys. Gather applicable spelling evidence for
	the owning generated declaration, independently of source order.
4. Render canonical Swift types with existential markers in their recorded positions. Emit matching
	context protocol and accessor declarations; continue using existing construction and injection code.

**F1 — Unsupported source type:** existing unsupported-key/factory diagnostics remain authoritative.
The new representation must not silently admit optionals, compositions, opaque types or other
currently rejected graph types. Carry this boundary into spec scenarios.

**F2 — Invalid dependency graph:** existing missing-dependency, duplicate-key and other validation
errors continue to prevent successful generation. Distinct existential spellings must not hide a
duplicate provider or manufacture a separate dependency. Cover these cases in the spec.

The fix introduces no retry, recovery, configuration toggle or new diagnostic category. It preserves
explicit syntax; it does not provide semantic type checking or discover external protocol declarations.
Source declarations that omit required `any` everywhere remain the client's responsibility.

## Compatibility and resource budget

Unchanged graphs without nested existential evidence should retain their generated output. Affected
graphs intentionally gain the missing `any` markers. This relaxes the collection-injection spec's
earlier byte-identical-output guarantee in a separately documented correction; it does not amend
collection resolution behavior. Existing valid top-level existential output must remain stable.

No minimum Swift/platform change or migration annotation is proposed. Regeneration applies the fix;
rolling back the generator restores the previous output and its compilation limitation. No release
or version bump is part of this design task.

Work and storage should scale with scanned type syntax plus the graph's existing visibility data.
Do not introduce external lookups, compiler invocations during normal generation, graph-wide
cross-products or runtime work. Compiler invocations belong only in verification fixtures.

The trust boundary remains parsed client source and configuration. Retain structural type data
through existing validation; do not use textual substitution to insert `any` into arbitrary source.

## Alternatives considered

- Retain raw provider spelling: smaller change, but insufficient for consistent spelling evidence
	from consumers and equivalent declarations, and ties output formatting to incidental source syntax.
- Patch array elements only: leaves the same information loss in dictionaries and nominal generics.
- Reject nested existential beans: prevents otherwise supported Swift types from being generated.

The recursive representation addresses the information loss at the generator boundary while keeping
dependency identity independent of emitted Swift syntax.

## Validation plan

After the design, spec and architecture gates, add failing output regressions and generated-source
compiler fixtures. Cover arrays, dictionary positions, generic arguments, nested combinations,
top-level existential regression, equivalent spellings, qualifiers, assisted return types, deferred
factories and parent/child ownership. Include concrete-type controls so the generator never blindly
adds `any`. Compile valid fixtures with `ExistentialAny` enabled and ordinary settings, and check
rejected types and duplicate keys retain their existing diagnostics.

Run `swift test` and the feature-specific compiler fixtures, then obtain an independent read-only
conformance grade. No production changes or tests are part of Phase 0.

## Open questions and approval

No blocking product question remains. This proposal includes all currently supported nested type
shapes rather than an array-only patch, and extends existing spelling evidence while preserving
identity and ownership. Phase 1 will turn these boundaries into explicit Given/When/Then scenarios;
Phase 2 will choose internal contracts and the evidence-collection mechanism.

Approval requested: `design approved`, or requested changes. Spec and architecture remain separate gates.
