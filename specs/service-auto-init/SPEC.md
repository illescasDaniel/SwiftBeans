# Service auto-init

## Metadata

- **Feature:** `@Service(..., autoInit: true)` generates the initializer from stored properties. The DI generator injects through it, and `@Assisted` / `@Qualifier` can mark `let` properties.
- **Status:** Phase 1 approved in chat on 2026-11-20.
- **System design:** [design/service-auto-init/DESIGN.md](../../design/service-auto-init/DESIGN.md)
- **Design approved:** 2026-11-20 (chat).
- **Design decisions approved:** 2026-11-20 (chat), together with the spec.
- **Spec approved:** 2026-11-20 (chat). Phase 2 amendment (diagnostics reported once, by the macro) approved 2026-11-20 (chat). Phase 4 amendment (empty-init wording, optional-`let` diagnostic ID, `@Observable` backing-storage marker exemption) approved 2026-11-20 (chat).
- **Related:** `specs/compile-time-di/SPEC.md` (initializer selection, memberwise rule, `@Assisted`), `specs/qualifiers/SPEC.md`, `specs/factory-injection/SPEC.md`, `specs/child-contexts/SPEC.md`.
- **Affected modules:** `SwiftBeans` (macro declarations), `SwiftBeansSyntaxRules` (shared init model and rules), `SwiftBeansMacros` (`ServiceMacro`, marker macros), `SwiftBeansGeneratorCore` (`DeclarationScanner`; the generator-side property-marker diagnostics are removed). Plugin and generator CLI are unchanged.

## Design decisions

### Success criteria

- A `@Service` class, struct or actor with `autoInit: true` and no initializer in its body compiles.
	The generated graph builds it through the macro-generated initializer, with the same wiring as an
	equivalent hand-written initializer.
- The parameter list derived by the macro and the one derived by the generator are equal for every
	test fixture. A test asserts this.
- `@Assisted` / `@Qualifier("…")` on a `let` property of an auto-init service produce an assisted
	accessor / a named lookup, with no wrapper storage.
- The example app adopts `autoInit: true` for every `@Service` where the rules allow it. Its existing
	tests stay green. The README presents auto-init as the recommended `@Service` style.

### Failure handling

- Every invalid use is a positioned compile-time diagnostic, reported once. Declaration-local rules
	(everything in "Rejected forms" except `qualifier.assisted`, plus marker placement) are
	`SwiftBeansSyntaxRules` violations reported by the macro. The generator runs the same rules and
	silently drops the service, so it emits no provider. This is the existing convention in
	`specs/compile-time-di/ARCHITECTURE.md` ("nothing is reported twice"). Graph-level failures
	(missing dependency, `qualifier.assisted`, initializer ambiguity) stay generator diagnostics.
	There is no runtime failure mode and no partial generation.
- One case is detected only by the Swift compiler: a closure property whose type is a typealias
	(see "Generated initializer"). It gets no SwiftBeans diagnostic. The README documents the
	compiler error and the fix.

### Performance and resource budget

- One extra linear pass over a type's members for each `autoInit: true` service, in both the macro
	and the scanner. No extra files are scanned, no subprocesses run, and there is no runtime cost.
	The generated init is the size of the hand-written one it replaces.

### Trust boundary

- Inputs are client Swift source, already parsed by SwiftSyntax. The macro emits only identifiers,
	types and attribute arguments copied from that same declaration. It never builds code from string
	content beyond those syntax nodes. The qualifier name keeps the existing string-literal validation.

### Compatibility and rollout

- Additive. `autoInit` defaults to `false`. Without it, `@Service` expands to nothing (as today), and
	the generated context source is byte-identical for existing fixtures.
- `@Service` gains `names: named(init)`, which has no effect when nothing is emitted.
- New public marker macros `Assisted()` / `Qualifier(_:)` share names with the existing wrappers.
	Parameters still resolve to the wrappers (verified on Swift 6.4.2, which is the package minimum).
	`@Assisted` / `@Qualifier` on a stored property used to compile and then fail in the generator
	(`assisted.property` / `qualifier.property`). They are now macro errors at compile time, except in
	auto-init services, where they are valid.
- Rollback: remove `autoInit: true` and write the initializer by hand. The graph does not change.

## Public API and contracts

### Declarations (`SwiftBeans`)

- All four `@Service` overloads gain a trailing parameter `autoInit: Bool = false` and become
	`@attached(member, names: named(init))`.
- New marker macros, documented as valid only on stored properties of `autoInit: true` services:
	- `@attached(peer) public macro Assisted()`
	- `@attached(peer) public macro Qualifier(_ name: String)`

### `autoInit` argument

- It must be the Boolean literal `true` or `false`. Any other expression is a positioned error,
	`service.autoInit`, reported by the macro. Like a bad `scope:`, the generator drops the service
	without reporting it.

### Generated initializer

Applies when `autoInit: true`.

1. **Included properties.** Stored instance properties declared in the type body, `let` or `var`, at
	any access level, that have a type annotation and no initial value. They appear in declaration
	order, including each binding of `let a: A, b: B`.
2. **Excluded properties.** `static`, `class` and `lazy` properties, computed properties (those with
	an accessor block), and properties with an initial value. Unlike Swift's memberwise rule, a `var`
	with an initial value does not become a parameter.
3. **Optional vars.** `var x: T?` (or `Optional<T>`) with no initial value becomes the parameter
	`x: T? = nil`. The graph resolves it as a defaulted, optional dependency, using the existing rule
	for defaulted parameters. `let x: T?` with no value stays required, as in Swift.
4. **Parameter shape.** Each parameter has the same label and internal name as the property and the
	property's type as written. If the type is a function type (possibly attributed, such as
	`@MainActor () -> T` or `@Sendable (A) -> B`, or parenthesized), `@escaping` is added in front of
	its attributes. Optional and implicitly unwrapped function types are left unchanged.
5. **Markers.** A property marked `@Assisted` produces `@Assisted name: T`. A property marked
	`@Qualifier("n")` produces `@Qualifier("n") name: T`. Both copy the attribute as written.
6. **Body.** It contains `self.name = name` for each parameter, in order. There is no `super.init`
	call and no other statements.
7. **Access.** `public` if the type is `public` or `open`, and `package` if the type is `package`.
	Otherwise there is no modifier (internal). The init has no explicit isolation and no
	`async`/`throws`.
8. **No properties.** If no property is included, the result is an empty `init()`.
9. **Shared model.** `SwiftBeansSyntaxRules` derives both the macro's output and the generator's
	`InitializerInfo` from one function. The generator treats it as a declared initializer candidate,
	so `@Inject` and selection rules apply across it and any initializers in extensions.

### Rejected forms (positioned errors; no init emitted; generator emits no provider for that type)

| ID | Condition |
|---|---|
| `autoInit.existingInit` | `autoInit: true` and the type body declares an initializer |
| `autoInit.propertyAttribute` | An included property has an attribute other than `@ObservationIgnored`, `@available`, `@Assisted` or `@Qualifier(…)`. Wrappers and other macros can't be told apart from syntax, so the message says to declare an initializer. |
| `autoInit.pattern` | A stored property uses a non-identifier pattern, such as `let (a, b): (A, B)` |
| `autoInit.missingType` | An included property has no type annotation |
| `qualifier.assisted` | A property is marked with both `@Assisted` and `@Qualifier` (existing ID and message) |

### Marker macros

- They expand to nothing.
- `assisted.property` / `qualifier.property` (existing IDs) are reported by the macro when the marker
	is on something other than a stored instance property of an enclosing `@Service(..., autoInit: true)`
	type. The new message names both fixes: "add `autoInit: true` to the `@Service`, or mark the
	initializer parameter instead".
- The generator no longer reports `assisted.property` / `qualifier.property`; the macro owns them.
	Every module the plugin scans is compiled with the SwiftBeans macros, so the build still fails.
- A qualifier name that is not a valid string literal uses the existing qualifier-name diagnostic.
- `@Observable` copies a property's attributes onto its generated `@ObservationIgnored` backing
	property, and the compiler expands the marker macros there with no lexical context. A marker on a
	`@ObservationIgnored` variable with no lexical context is therefore not checked. The original
	property is still checked. The exemption applies only to underscore-prefixed bindings, which is how
	`@Observable` names its backing storage. This was amended in Phase 4 after it was found in the example app.

## Acceptance criteria

### Scenario: coordinator class with private closure dependencies

**Given** a `@Service(scope: .transient, autoInit: true) @Observable @MainActor final class` with
`var path = NavigationPath()` and two `private let` properties of types `@MainActor () -> A` and
`@MainActor (Item) -> B`
**When** the macro expands
**Then** it emits `init(makeA: @escaping @MainActor () -> A, makeB: @escaping @MainActor (Item) -> B)`
that assigns both, and `path` is not a parameter
**And** the generated context constructs the coordinator with injected factories, and the fixture compiles.

### Scenario: dependency, assisted and qualified properties

**Given** an auto-init class with `private let repository: R`, `@Assisted let item: Item` and
`@Qualifier("snakeCase") private let decoder: JSONDecoder`, and a bean `@Bean(named: "snakeCase")`
returning `JSONDecoder`
**When** generation runs
**Then** the init is `init(repository: R, @Assisted item: Item, @Qualifier("snakeCase") decoder: JSONDecoder)`
**And** the context exposes `func xxx(item: Item)` that passes the graph's `R` and the `snakeCase` decoder
**And** a factory `(Item) -> Xxx` can be injected elsewhere
**And** direct calls `Xxx(repository: r, item: i, decoder: d)` compile.

### Scenario: macro and generator agree

**Given** every auto-init fixture in the macro and generator test suites
**When** the shared model is computed through the macro path and through the scanner path
**Then** both give the same ordered labels, types, defaults and markers.

### Scenario: optional var becomes an optional dependency

**Given** an auto-init type with `var logger: Logger?` and no `Logger` provider
**When** generation runs
**Then** the init has `logger: Logger? = nil`, the build succeeds and the default is used
**And** when a `Logger` provider is added, it is injected.

### Scenario: optional let stays required

**Given** an auto-init type with `let token: Token?` and no provider for `Token?` or `Token`
**When** generation runs
**Then** the build fails at that property with the same diagnostic a hand-written `init(token: Token?)`
produces today (`key.unsupported`; amended in Phase 4).

### Scenario: excluded members

**Given** an auto-init type with `static let shared`, `lazy var cache`, a computed `var name: String { … }`,
`let id = UUID()` and `var count = 0`
**When** the macro expands
**Then** none of them is a parameter.

### Scenario: struct with private properties

**Given** a `@Service(autoInit: true) struct` with `private let client: Client`
**When** generation runs
**Then** the generated init is used instead of Swift's private memberwise init, and the struct is injected.

### Scenario: actor

**Given** a `@Service(autoInit: true) actor` with `let store: Store`
**When** generation runs
**Then** the actor is constructed through `init(store:)`.

### Scenario: access level follows the type

**Given** auto-init types declared `public`, `open`, `package` and with no modifier
**When** the macro expands
**Then** their inits are `public`, `public`, `package` and unmodified respectively
**And** a public auto-init service in a local package satisfies the `package.notPublic` rule.

### Scenario: no included properties

**Given** an auto-init class whose stored properties all have initial values
**When** the macro expands
**Then** it emits an empty `init()`.

### Scenario: `@Inject` across extension and generated inits

**Given** an auto-init class whose extension declares a second initializer marked `@Inject`
**When** generation runs
**Then** the extension initializer is selected. Without `@Inject`, the existing ambiguity rule reports
the two candidates, and the generated init is one of them.

### Scenario: `@ObservationIgnored` is allowed

**Given** an auto-init `@Observable` class with `@ObservationIgnored private let clock: Clock`
**When** generation runs
**Then** `clock` is an ordinary parameter, and the fixture compiles.

### Scenario: autoInit false keeps today's output

**Given** the existing generator and macro fixtures, none of which uses `autoInit`
**When** generation runs
**Then** generated source and macro expansions are byte-identical to before this feature.

### Scenario: wrappers still apply on parameters

**Given** a module with an init `init(@Assisted item: Item, @Qualifier("x") d: D)`, a `@Bean` method
with the same parameters, and an auto-init service with marked `let` properties
**When** it compiles
**Then** parameter markers resolve to the property wrappers, property markers resolve to the macros,
and the module builds.

### Scenario: existing initializer conflicts (F1)

**Given** `@Service(autoInit: true)` on a class that declares `init(a: A)` in its body
**When** it compiles
**Then** `autoInit.existingInit` is reported at the initializer, and no init is emitted.

### Scenario: non-literal autoInit (F2)

**Given** `@Service(autoInit: flag)`
**When** it compiles
**Then** the macro reports `service.autoInit` at the argument once, and the generator emits no
provider for that type.

### Scenario: unknown property attribute (F3)

**Given** an auto-init class with `@Published var value: Int` and no initial value
**When** it compiles
**Then** `autoInit.propertyAttribute` is reported at the attribute.

### Scenario: unsupported pattern (F4)

**Given** an auto-init type with `let (a, b): (A, B)`
**When** it compiles
**Then** `autoInit.pattern` is reported at the pattern.

### Scenario: missing type annotation (F5)

**Given** an auto-init type whose included property has no type annotation, such as a `var` declared
without a type or a value inside a conditional block
**When** it compiles
**Then** `autoInit.missingType` is reported at the binding.

### Scenario: marker outside an auto-init service (F6)

**Given** `@Assisted let item: Item` in a `@Service` without `autoInit: true`, and
`@Qualifier("x") let d: D` in a type that isn't a service
**When** it compiles
**Then** `assisted.property` and `qualifier.property` are reported at each attribute with the new message.

### Scenario: marker on a non-stored or static property (F7)

**Given** an auto-init service with `@Assisted static let x: X` or `@Assisted var y: Y { … }`
**When** it compiles
**Then** `assisted.property` is reported at each attribute.

### Scenario: assisted and qualified together (F8)

**Given** an auto-init property marked with both `@Assisted` and `@Qualifier("x")`
**When** generation runs
**Then** `qualifier.assisted` is reported, as for parameters today.

### Scenario: invalid qualifier name on a property (F9)

**Given** `@Qualifier(name) private let d: D` in an auto-init service, where `name` is not a literal
**When** it compiles
**Then** the existing qualifier-name diagnostic is reported at the argument.

### Scenario: closure typealias limitation (F10)

**Given** an auto-init class with `private let make: MakeFn`, where `typealias MakeFn = () -> T`
**When** it compiles
**Then** Swift reports that a non-escaping parameter is assigned to a stored property. SwiftBeans emits
no diagnostic, and the README's auto-init section explains how to spell out the closure type or write
the init by hand.

### Scenario: subclass whose superclass needs arguments (F11)

**Given** an auto-init class inheriting from a superclass with no zero-argument designated init
**When** it compiles
**Then** Swift's own missing-`super.init` error is reported. SwiftBeans emits no diagnostic, and the
README documents the limitation.

### Scenario: example app and docs adopt auto-init

**Given** the example app and README after this feature
**When** they are reviewed
**Then** every example `@Service` uses `autoInit: true`, unless a one-line comment explains why it
keeps a hand-written init
**And** the README's concepts section shows auto-init as the first `@Service` example, with its rules,
property markers and limitations
**And** the macro doc comments mention `autoInit:`
**And** the example's unit tests and macOS / iOS Simulator builds pass.

## Out of scope

- A standalone `@AutoInit` macro for types that aren't services.
- Generating inits for `@Configuration`, `@Bean` or `@ChildContext`; `@ChildContext` keeps its own init.
- `super.init` forwarding, access-level overrides, custom labels or defaulted non-optional parameters.
- Treating `autoInit: true` as the default, or inferring it.
- Typealias-to-closure detection, which would need semantic information.
