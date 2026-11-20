# Service auto-init — system design

- **Date:** 2026-11-20
- **Status:** Phase 0 approved in chat on 2026-11-20.
- **Design approved:** 2026-11-20 (chat).
- **Spec:** [specs/service-auto-init/SPEC.md](../../specs/service-auto-init/SPEC.md) (approved 2026-11-20).

## Problem and outcome

`@Service` classes repeat every dependency three times: stored property, init parameter and
assignment. `LoggedInCoordinator` in the example spends 16 lines on four factories. Closures add
`@escaping` noise on top. Structs avoid this through the memberwise init, but only when every
property is at least `internal`. Swift lowers the memberwise init to `private` as soon as one stored
property is `private`. And `@Observable` and identity-carrying types must stay classes.

Outcome: a `@Service` type can opt into a generated initializer built from its stored properties.
The DI generator then sees and calls that initializer as if the user had written it.

## Options considered

| Option | Verdict |
|---|---|
| 1. "Boxed" structs: declare the service as a struct and box it for reference semantics | **Rejected.** `@Observable` cannot apply to structs. The box would change identity semantics (`===`, observation, `@State` ownership) and add a wrapper type users must unwrap. Plain structs with `internal` properties already get memberwise injection today, so the only real gain is `private` properties, and option 3 covers that. |
| 2. Standalone `@AutoInit` macro | **Viable, not first.** It is useful beyond DI, but that is outside this package's scope. It is also one more attribute to stack on an already busy type (`@Service @Observable @MainActor @AutoInit`). It leaves open whether the generator should trust `@AutoInit` on non-service types. |
| 3. `@Service(..., autoInit: true)` | **Recommended.** It has one attribute, reads as "SwiftBeans owns construction", and is scoped to the types the generator already scans. The init-shape rules live in `SwiftBeansSyntaxRules`, so a standalone `@AutoInit` can be added later with no behavior fork. |

Target result for the example:

```swift
@Service(in: LoggedInContext.self, scope: .transient, autoInit: true)
@Observable
@MainActor
final class LoggedInCoordinator {
	var path = NavigationPath()
	var selectedTab = LoggedInTab.items
	private let makeItemList: @MainActor () -> ItemListViewModel
	private let makeItemDetail: @MainActor (Item) -> ItemDetailViewModel
	private let makeUser: @MainActor () -> UserTabViewModel
	private let makeFeaturesDemo: @MainActor () -> FeaturesDemoViewModel
	// generated:
	// init(makeItemList: @escaping @MainActor () -> ItemListViewModel, makeItemDetail: …, …)
}
```

## Public surface

- Each of the four `@Service` overloads gains a trailing `autoInit: Bool = false`. The argument must
	be a Boolean literal, which the syntax rules check the same way as `scope:`.
- `@Service` declares `names: named(init)`. Nothing is emitted unless `autoInit: true`.
- No new runtime types.

## Generated initializer rules (single source of truth in `SwiftBeansSyntaxRules`)

**Included properties, in declaration order:** stored instance properties (`let` or `var`) that have
no initial value, whatever their access level. `private` is fine because the init is a member.

**Excluded:** `static`/`class`/`lazy`, computed properties, and properties with an initial value.
`let x = …` and `var path = NavigationPath()` are state, not dependencies. This differs on purpose
from Swift's memberwise init, which would turn `path` into a defaulted parameter. If that happened,
a later `NavigationPath` bean would silently be injected.

**Optional `var x: T?` without a value** becomes a defaulted `x: T? = nil` parameter. The graph then
resolves it as an optional dependency, the same as today's memberwise rule.

**Parameter types:**
- A syntactic function type, with or without attributes (`@MainActor () -> T`, `@Sendable (A) -> B`),
	gets `@escaping`. Optional closures are already escaping and stay unchanged.
- Known limitation: a typealias that names a function type cannot be detected from syntax. Swift then
	reports "assigning non-escaping parameter". The diagnostic text and docs tell the user to spell the
	closure type or write the init by hand.

**Allowed property attributes:** `@ObservationIgnored` and other non-wrapper attributes that
`@Observable` accepts. A property-wrapper stored property is a positioned error, the same rule as
`init.propertyWrapper` today.

**Runtime arguments and qualifiers** (the "extra properties"): you mark the stored property with
`@Assisted` or `@Qualifier("…")`, which can stay a `private let`. The generated parameter carries the
same marker, and the assignment is a plain `self.x = x`:

```swift
@Service(autoInit: true)
final class ItemDetailViewModel {
	private let repository: ItemRepository
	@Assisted let item: Item
	@Qualifier("snakeCase") private let decoder: JSONDecoder
	// generated:
	// init(repository: ItemRepository, @Assisted item: Item, @Qualifier("snakeCase") decoder: JSONDecoder)
}
```

This works because the `SwiftBeans` runtime declares **marker peer macros** with the same names as
the existing property wrappers, `@attached(peer) macro Assisted()` and `macro Qualifier(_ name: String)`.
Swift resolves the attribute by where it appears:
- On a stored property, the macro wins. It expands to nothing, so no wrapper storage is created and
	`let` is allowed.
- On a parameter, which can't host an attached macro, the property wrapper wins. Existing
	initializers and `@Bean` methods are unchanged.

A probe with Swift 6.4.2 confirmed both resolutions: `swiftc -typecheck` with the real plugin, using
`let` properties together with `init(@Assisted item:, @Qualifier("x") decoder:)`. Phase 3 adds a
compiler fixture that pins this behavior.

The marker macros validate where they appear. On a stored property of an `autoInit: true` service
they are fine. On any other stored property they produce a positioned error, `assisted.property` or
`qualifier.property`, telling the user to use `autoInit: true` or move the marker to an init
parameter. The existing scanner diagnostics for marked properties become this rule. The qualifier
name follows the existing string-literal rules.

**Access level:** the init matches the type's declared access, with `open` lowered to `public`.
Otherwise it is `internal`. Public local-package services then satisfy `package.notPublic` without
extra work.

**Isolation and inheritance:** the init has no explicit isolation and inherits it from the type
(`@MainActor` classes stay main-actor). There is no `super.init` call, so a subclass works only when
its superclass has a zero-argument designated init. Swift reports anything else; the macro cannot
tell a superclass from a protocol in syntax.

**Conflicts (positioned errors):**
- `autoInit: true` on a type that already declares an initializer in its body.
- `autoInit: true` on an `enum`, which `@Service` already rejects.
- Extension initializers are still allowed. Today's `@Inject` selection then applies across them and
	the generated init.

## Module seams and flow

| Module | Change |
|---|---|
| `SwiftBeans` | Add `autoInit:` to the `@Service` overloads and `names: named(init)`. Add the `Assisted()` / `Qualifier(_:)` marker peer macros next to the existing wrappers. |
| `SwiftBeansMacros` (markers) | New no-op peer macros that only run the placement diagnostics |
| `SwiftBeansSyntaxRules` | New `autoInitParameters(of:)`, returning a parameter model plus violations. It is the only place the inclusion rules live. |
| `SwiftBeansMacros` (`ServiceMacro`) | Calls the rules, renders `init(...) { self.x = x … }`, and diagnoses |
| `SwiftBeansGeneratorCore` (`DeclarationScanner`) | When it sees `autoInit: true`, it synthesizes an `InitializerInfo` from the same rules. This is needed because the plugin scans source before macro expansion. Resolution, validation and codegen stay unchanged. |
| Plugin / generator CLI | No change |

The key invariant: the macro and the generator compute the init from one shared function. A test
asserts that their parameter lists match for every fixture.

## Testing approach

- Macro expansion tests (`assertMacroExpansion`): class, struct, actor, private properties,
	closures with and without attributes, optionals, excluded state, conflicts and access levels.
- Generator tests: an auto-init service resolves dependencies, optional dependencies and factories,
	and handles `@Inject` across extension inits.
- Compiler fixture: an auto-init `@Observable @MainActor` class compiles together with the generated context.
- Compiler fixture: same-name resolution, with markers on `let` properties and wrappers on init and
	`@Bean` parameters in the same module.
- Example: broad adoption (see "Adoption and documentation"). Existing example tests are the
	regression check, and they must still construct these types directly through the generated inits.

## Adoption and documentation

The flag is opt-in but is the **recommended default style**. It must not be buried:
- **README:** auto-init is the first `@Service` example in the concepts section. A short section covers
	the inclusion rules, `@Assisted`/`@Qualifier` on properties, the closure-typealias limitation and
	when to write an init by hand.
- **Example app:** every `@Service` that can use `autoInit: true` switches to it, including the
	coordinators, view models, repositories and use cases. A hand-written init stays only where it
	shows something auto-init can't do, and a one-line comment says why. That keeps the existing
	initializer-selection and `@Inject` coverage visible.
- **Macro doc comments** on the `@Service` overloads mention `autoInit:` and link the README section.

## Decisions (chat, 2026-11-20)

1. `@Assisted` and `@Qualifier` mark `let` properties through same-named marker peer macros, not
	property-wrapper storage. See "Runtime arguments and qualifiers".
2. Opt-in (`autoInit: false` by default), presented as the recommended style in the README and used
	throughout the example.
3. A `Bool` flag for v1; there is no enum.
