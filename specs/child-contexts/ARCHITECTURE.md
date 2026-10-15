# Architecture: Child Contexts (PROPOSED)

> **Status: proposed and speculative.** Written alongside the Phase 1 draft in `SPEC.md` to show where the seams would be. Nothing here is approved or a contract; Phase 2 will replace this file once the spec is approved.

Builds on `specs/compile-time-di/ARCHITECTURE.md` (module seams, generator pipeline, `SwiftBeansRegistry`). Only deltas are listed.

## Module seams

| Module | Proposed change |
|--------|-----------------|
| `SwiftBeans` (runtime) | Declares `@ChildContext(of:)`, `@ContextInput`, and the `in:` parameter on `@Service` / `@Bean` / `@Configuration`. `SwiftBeansRegistry` is **unchanged** (one instance per context instance). No new runtime types |
| `SwiftBeansMacros` | `ChildContextMacro` (member macro: `_swiftBeansRegistry`, `_swiftBeansParent`, generated `init`), `ContextInputMacro` (marker with local diagnostics). `ServiceMacro` / `BeanMacro` / `ConfigurationMacro` accept `in:` |
| `SwiftBeansSyntaxRules` | New single-declaration rules: `@ChildContext` only on `final class`, `@ContextInput` only on stored `let` without default in a `@ChildContext` type, `in:` is a type literal |
| `SwiftBeansGeneratorCore` | Scanner records contexts and per-provider owner; resolver builds a context tree; validator runs per context; codegen emits one protocol + extension per context |
| `Plugins/SwiftBeansPlugin` | No change expected: same scan set, same single output file |

## Division of labor

- **Macros** (local checks, inline in Xcode): shape of the context class, input properties, `in:` literal form.
- **Generator** (cross-file): parent resolution, owner assignment, visibility, duplicates across the chain, narrowing diagnostics.

## Generator pipeline deltas

1. **Scanner.** Adds `ContextDeclaration { name, kind: root | child(parentName), inputs: [(label, type, location)] }` and `owner: TypeName?` on each provider (from `in:` or the enclosing `@Configuration(in:)`; `nil` = root).
2. **Resolver.**
	- Builds a context tree; checks parent resolution and acyclic parents.
	- Assigns each provider to its context; local-package providers with an owner other than root are errors.
	- Per context, computes the **visible key set**: own providers, inputs, then the ancestor chain, recording which context owns each key.
3. **Validator.** Per context: missing dependency (names the context chain), duplicate across the chain, accessor collisions, cycles over own edges, `@Assisted` rules. Extra check: root-owned (or ancestor-owned) providers requiring a key owned by a descendant or sibling produce the "narrower lifetime" diagnostic.
4. **Codegen.** Contexts emitted parent-first and sorted. Each dependency renders as `self.key` (own / input), `self._swiftBeansParent.key` (direct parent). With nesting (phase C), a grandparent key is forwarded through the intermediate protocol, so every child's protocol must expose forwarded keys it needs or the generated child must hold the ancestors directly. This is an open design point; phase A only needs the direct parent.

## Generated code shape (proposed)

```swift
protocol UserSessionContextProtocol: AnyObject {
	var feedRepository: FeedRepository { get }
	var user: User { get }
}

extension UserSessionContext {
	var feedRepository: FeedRepository {
		_swiftBeansRegistry.singleton(key: "feedRepository") {
			FeedRepository(api: self._swiftBeansParent.apiClient, user: self.user)
		}
	}
}

extension UserSessionContext: UserSessionContextProtocol {}
```

Macro-added members of `UserSessionContext`:

```swift
let _swiftBeansRegistry = SwiftBeansRegistry()
let _swiftBeansParent: any AppContextProtocol
init(parent: any AppContextProtocol, user: User) {
	self._swiftBeansParent = parent
	self.user = user
}
```

Inputs are stored properties, so they satisfy the protocol requirement directly and the generated extension emits no accessor for them. Phase 2 decides the final form.

## Risks and seams to watch

- **Parent protocol surface.** Because children depend on the parent's *protocol*, every key a child uses must be in the parent protocol; this already holds because the protocol lists every injectable key.
- **Isolation.** Existential parent plus `@MainActor` contexts needs a concrete decision (spec open question 6).
- **Registry keys** stay per accessor within a context; keys never need to be unique across contexts since each context owns its registry.
- **Diagnostics volume.** Per-context validation multiplies errors; keep sorting and dedupe rules unchanged.
- **Plugin input set** is unchanged, so no new known limitations are introduced.

## Testing seams (proposed)

- Generator unit tests: tree resolution, ownership, visibility, each diagnostic, byte-identical output without children (golden test against the current fixtures).
- Macro expansion tests for `@ChildContext` / `@ContextInput` / `in:`.
- Runtime fixture tests (generated code compiled in the test target): singleton identity per child, parent sharing, release via weak reference, concurrent first access.
- Example app: login / logout scene proving ARC teardown (phase B).
