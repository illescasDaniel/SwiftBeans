# Spec: Compile-Time Spring-Style DI

## Metadata

| Field | Value |
|-------|-------|
| Feature | `compile-time-di` |
| Status | Approved (Phase 1) — 2026-10-14; amendment "Generator rules" + "Singleton storage" approved — 2026-10-15; amendment "Runtime arguments (`@Assisted`)" approved — 2026-10-15 |
| Swift tools | 6.4+ (matches `Package.swift`) |
| Platforms | macOS first; Apple platforms + Linux as package allows |
| Related targets (planned) | `SwiftBeans` (public API + re-exported macros), `SwiftBeansMacros` (macro plugin), `SwiftBeansPlugin` / generator executable (build tool), tests |

## Goal

Provide a Swift Package that mimics Spring Boot’s ergonomics for dependency wiring using:

- `@ApplicationContext` — root of the compile-time bean graph (generated accessors live here)
- `@Configuration` — a type that declares bean factories
- `@Bean` — a **static** factory function that produces a dependency
- `@Service` — attribute-only stereotype on a concrete type; the scanner/plugin uses it to register the type and wire its initializer

Wiring is **discovered by an SPM build tool plugin** (auto-scan of annotated declarations) and **validated / generated at compile time**. There is **no runtime service-locator container** in v1. If compile-time generation proves infeasible after a serious attempt, fall back to a runtime dictionary-style container is an explicit later decision (out of scope until then).

Inspiration (prior art, not dependencies): Sword (`@Module`/`@Provider`/`@Dependency`), Pin (macro + build plugin), Needle (compile-time hierarchy).

## Why macros alone are not enough

Swift attached macros only see the declaration they are attached to. They cannot scan other files or modules for every `@Service`. Spring-style classpath scanning therefore requires a **build tool plugin** (or equivalent source scan) that emits generated Swift the compiler type-checks.

| Concern | Mechanism |
|---------|-----------|
| Local boilerplate / API surface | Attached macros (`@ApplicationContext`, `@Configuration`, `@Bean`, `@Service`) |
| Cross-file / cross-package discovery | SPM build tool plugin + optional YAML scan config |
| Missing / cyclic / duplicate deps | Fail the build (diagnostics from generator and/or type checker) |

## Public API surface (v1)

### Root: `@ApplicationContext`

The root of the DI graph. Chosen over `@Component` because in Spring `@Component` is a stereotype (peer of `@Service`), while `ApplicationContext` is the entry point from which beans are obtained. Ours is **compile-time generated**, not a runtime map.

```swift
@ApplicationContext
final class AppContext {
	// Generated: accessors for each provided type
}

let app = AppContext()
let users: UserService = app.userService
```

Consuming code obtains dependencies from the root (or a later child scope), not via a global service locator.

### Generated context protocol: `{ContextTypeName}Protocol`

For each `@ApplicationContext` type (e.g. `AppContext`), the generator also emits a protocol named **`{ContextTypeName}Protocol`** (e.g. `AppContextProtocol`) with a read-only getter per injectable key, and a method per assisted provider (see Runtime arguments) — same names and signatures as the concrete accessors — plus `extension AppContext: AppContextProtocol {}`.

```swift
// Generated
protocol AppContextProtocol: AnyObject {
	var userService: UserService { get }
}

extension AppContext {
	var userService: UserService { ... }
}

extension AppContext: AppContextProtocol {}
```

Apps type navigation / SwiftUI seams against `any AppContextProtocol` and hand-write fakes (e.g. `FakeAppContext`) for Previews and tests. **Generating fake / mock context implementations is out of scope.**

### Stereotypes & factories

`@Service` is **attribute-only for the scanner** in v1: it does not require or synthesize a protocol conformance marker.

`@Bean` methods **must be `static`**. Configuration types may be `enum`/`struct`/`class`; static factories keep configuration stateless and align with Sword-style providers. Users who want a namespaced config can use an `enum`.

```swift
@Configuration
enum AppConfiguration {
	@Bean
	static func urlSession() -> URLSession { ... }

	@Bean(scope: .singleton)
	static func apiClient(urlSession: URLSession) -> APIClient {
		DefaultAPIClient(urlSession: urlSession)
	}
}

@Service
final class UserService {
	init(apiClient: APIClient) { ... }
}

@Service(boundTo: PaymentProcessing.self)
final class StripePaymentProcessor: PaymentProcessing {
	init(apiClient: APIClient) { ... }
}
```

### Choosing an initializer: `@Inject`

When a `@Service` type has more than one eligible initializer, mark the one the graph should call with `@Inject` (Spring's constructor `@Autowired`). It is a marker with a local macro check (it must be on an initializer); a type with a single eligible initializer does not need it. See Generator rules → Providers and dependencies.

```swift
@Service
final class ReportService {
	@Inject
	init(store: any Store, clock: Clock = .system) { … }

	convenience init() { … } // used by tests, not by the graph
}
```

### Runtime arguments: `@Assisted`

Some values are only known where an object is created: an item id, a navigation argument, a search query. Mark those parameters `@Assisted` (assisted injection, as in Dagger/Hilt) and the context exposes a **method** that takes them instead of a property; the graph fills in the remaining parameters.

```swift
@Service
@MainActor
final class ItemDetailViewModel {
	init(repository: ItemRepository, @Assisted item: Item) { … }
}

// Generated
protocol AppContextProtocol: AnyObject {
	func itemDetailViewModel(item: Item) -> ItemDetailViewModel
}

extension AppContext {
	func itemDetailViewModel(item: Item) -> ItemDetailViewModel {
		ItemDetailViewModel(repository: self.itemRepository, item: item)
	}
}

// Call site
let viewModel = context.itemDetailViewModel(item: selectedItem)
```

`@Assisted` is a property wrapper in `SwiftBeans` used on parameters (SE-0293). It only has `init(wrappedValue:)`, so callers pass a plain `Item` and the initializer body reads `item` as an ordinary value; it is a marker for the generator, and manual construction (`ItemDetailViewModel(repository: fake, item: item)`) needs nothing extra. It works the same on `@Bean` method parameters.

Use it for per-instance runtime data. Configuration and services belong in the graph as beans.

### Scopes (v1)

| Scope | Meaning |
|-------|---------|
| `.singleton` (default for `@Service` / `@Bean` unless stated otherwise) | One instance per `@ApplicationContext` lifetime |
| `.transient` / prototype | New instance per resolve |

Request/session scopes, property injection (`@Autowired` on stored properties), and AOP are out of scope.

### Binding to protocols

`@Service(boundTo: SomeProtocol.self)` and/or `@Bean` return types that are protocols register the implementation under the protocol type for injection.

### Multi-module / scan boundary

- Plugin always scans **the target it is applied to**.
- Additional local packages / targets that should participate in the graph are declared in a **YAML config file**, `.swiftbeans.yml`, at the package or project root. This supports **Xcode iOS apps that have no `Package.swift`**, while SPM packages can use the same file.
- Types in dependencies that are not scanned must be provided via `@Bean` in a `@Configuration`.
- Consumers attach the SwiftBeans build plugin to the app/root target that owns the `@ApplicationContext` (and any target that needs generated wiring).

```yaml
# .swiftbeans.yml
local_packages:
  - path: Packages/Networking
    targets:
      - Networking
  - path: "Packages/FeatureHome"   # quotes optional
    targets:
      - FeatureHome
```

### Source discovery

The scan set is defined by the build system and the config file, never by guessing from folder contents.

1. **Target sources come from the build system.** The plugin scans exactly the Swift files the build system reports as the target's compiled sources (SPM: the source target's source files; Xcode: the target's input files). It does not walk folders, infer a "source root", or look for specific file names (e.g. an `App` entry file or `Assets.xcassets`). Files on disk that are not members of the target (excluded files, other targets' files, test sources in the same folder) are never scanned.
2. **One config location, no upward search.** The config file is looked up only at the root of the package (SPM) or the folder containing the `.xcodeproj` (Xcode). The plugin passes its path to the generator explicitly. Neither the plugin nor the generator searches parent folders. A `.swiftbeans.yml` above that root (e.g. in `~` or an enclosing repo) has no effect. If the config file is absent, only the target's own sources are scanned.
3. **Local package sources are resolved from `Sources/<target>`.** Each `local_packages` entry's `path` is resolved relative to the folder containing the config file and normalized (`..` and symlinks resolved). The path must be a folder containing a `Package.swift`, and each listed target must have a `Sources/<target>/` folder; all `.swift` files under it (recursively) are scanned. Packages whose targets use a custom `path:` in their manifest are out of scope for v1.
4. **Every scanned file is a declared build input.** The target sources, every resolved local package source, and the config file itself are declared as inputs of the generation step, so editing any of them regenerates the wiring on the next build. (Adding a *new* file to a local package is picked up when the build system re-plans the plugin; see Known limitations.)
5. **Config mistakes fail the build.** A config that cannot be read, a `local_packages` path that does not exist or has no `Package.swift`, a missing `Sources/<target>/` folder, or YAML outside the documented schema (block lists of `path` / `targets`, optional single or double quotes, `#` comments) fails the build with a diagnostic naming the config file and the offending entry. Nothing is skipped silently.
6. **Stable scan order.** The scan set is de-duplicated by resolved path and sorted before parsing, so generated output does not depend on the order the build system lists files.

**Known limitations (v1):** a new `.swift` file added to a local package may need a clean build or project re-plan in Xcode before it joins the graph, because build plugins cannot watch folders.

### Generator rules

These rules define what the generator accepts, how it names and matches things, and how it reports problems. The guiding rule: **every declaration that carries a SwiftBeans attribute is either wired or reported — never skipped silently.**

#### Recognized declarations

1. **Attribute spelling.** `@ApplicationContext`, `@Configuration`, `@Bean`, `@Service` (and `@Inject`, below) are recognized unqualified or qualified with `SwiftBeans.` (e.g. `@SwiftBeans.Service`). Attributes qualified with another module (e.g. `@Other.Service`) are not SwiftBeans attributes and are ignored.
2. **Nesting.** Annotated declarations are recognized at top level, nested inside types, and inside extensions (`extension Outer { @Service final class Inner { … } }`). A nested type's key and construction use its qualified name (`Outer.Inner`).
3. **Kinds.**
	- `@Service` applies to a `class`, `struct` or `actor`. Generic types are not supported.
	- `@Configuration` applies to an `enum`, `struct`, `class` or `actor`.
	- `@Bean` applies to a `static func` declared in a `@Configuration` type's body or in an extension of that type (in any scanned file). A `@Bean` in a type that is not `@Configuration` fails the build.
	- `@ApplicationContext` applies to a `class` (top level or nested).
4. **`#if` blocks.** An annotated declaration inside an `#if` block fails the build ("not supported in v1"). The generator cannot know which branch the compiler will take.
5. **Local declarations** (types declared inside function bodies) are not scanned; they cannot be constructed from the context.

#### Application contexts

1. Only `@ApplicationContext` types in the **target's own sources** form the root. Contexts declared in local packages listed in `.swiftbeans.yml` are ignored (they belong to that package's own graph); their `@Service` / `@Bean` declarations still join the graph.
2. More than one root context in the target fails the build, naming every context.
3. A target with **no** root context generates an empty file and succeeds (e.g. a feature module that applies the plugin but owns no context).

#### Injectable keys

A key is the type a provider produces (`@Service` type or its `boundTo:`, `@Bean` return type) or a dependency requires (initializer / `@Bean` parameter type). Keys are compared after normalization:

1. **Spelling normalized from syntax**, not raw text: whitespace and redundant parentheses do not matter (`[String:Int]` ≡ `[String: Int]`, `(any P)` ≡ `any P`), and `Array<T>` / `Dictionary<K, V>` match their sugared forms `[T]` / `[K: V]`.
2. **`any P` ≡ `P`.** A protocol spelled with and without `any` is one key (e.g. `@Service(boundTo: Store.self)` satisfies `init(store: any Store)`). The generated accessor and protocol requirement use the `any P` spelling when any declaration in the graph spells that key with `any`; otherwise `P`.
3. **Qualified names and typealiases are matched by spelling.** `Swift.String` and `String` are different keys, as are a typealias and its underlying type. When a dependency is missing and a provider exists whose key has the same last component, the diagnostic names it as a likely match.
4. **Unsupported key types fail the build** at the declaration: optionals (`T?`, `T!`), tuples, function types, opaque types (`some P`), metatypes, `Self`, protocol compositions (`any A & B`), and generic parameters.

#### Accessor names

Each key produces one accessor on the context (and one requirement on `{Context}Protocol`), named from the normalized key with `any` dropped:

| Key | Accessor |
|-----|----------|
| `UserService` | `userService` |
| `URLSession`, `HTTPClient`, `ID` | `urlSession`, `httpClient`, `id` (a leading acronym is lowercased) |
| `Outer.Inner` | `outerInner` (components joined) |
| `[User]` | `userArray` |
| `[String: User]` | `stringUserDictionary` |
| `Cache<User>` | `userCache` (generic arguments, then the base name) |
| `Class` | `` `class` `` (Swift keywords are escaped with backticks) |

Two keys that produce the same accessor name fail the build, naming both providers.

#### Providers and dependencies

1. **`@Service` initializer selection.** Candidates are the initializers declared in the type's body or in extensions of the type in scanned files, excluding `private` / `fileprivate` and failable (`init?` / `init!`) initializers.
	- Exactly one candidate → it is used.
	- More than one → the one marked `@Inject` is used. With several candidates and zero or more than one `@Inject`, the build fails, listing the candidates.
	- None declared → a `struct` uses its memberwise initializer (stored properties in declaration order; `let` properties with an initial value are excluded, `var` properties with one become defaulted parameters); a `class` / `actor` uses `init()`. A `struct` with property-wrapper stored properties and no declared initializer fails the build ("declare an initializer").
2. **`@Bean` methods** must be `static`, declare a return type, and have no generic parameters.
3. **No `throws` / `async`.** A selected initializer or `@Bean` method that is `throws`, `rethrows` or `async` fails the build. (Accessors are synchronous, non-throwing properties.)
4. **Defaulted parameters are optional dependencies.** A parameter with a default value is injected when the graph provides its key (for `T? = …`, the key `T`) and otherwise left to its default. It never causes a missing-dependency error, and it only participates in cycle detection when it is injected. A parameter without a default must have a supported, provided key.
5. **Scope literal.** `scope:` must be `.singleton` or `.transient`, optionally spelled `BeanScope.…` or `SwiftBeans.BeanScope.…`. Any other expression fails the build (it cannot be evaluated at build time).
6. **Providers from local packages must be public.** A `@Service` declared in a local package target must be `public` / `open` with a `public` selected initializer (a memberwise initializer is never public); a `@Bean` must be `public static` in a `public` configuration type. Otherwise the build fails at that declaration, since the app's generated code cannot call it.
7. **Collection parameters.** A `[E]` parameter with no `[E]` provider may be supplied by every bean that is an `E` (multi-bind); see `specs/collection-injection/SPEC.md`.

#### Assisted providers

A provider whose selected initializer or `@Bean` method has at least one parameter marked `@Assisted` (unqualified or `@SwiftBeans.Assisted`) is an **assisted provider**.

1. **Method accessor.** It gets `func <accessorName>(<assisted parameters>) -> <Key>` on the context and the same requirement on `{Context}Protocol`, instead of a property. The accessor name follows the usual rules for its key. The method's parameters are the assisted parameters in declaration order, each with its external label, internal name and type spelled as in the source (`_` labels are kept). Assisted parameter types are not keys, so the key restrictions (optionals, tuples, functions…) do not apply to them.
2. **Construction.** The generated call passes every parameter in the initializer's order: assisted ones from the method's arguments, the rest from the graph under the normal rules (required keys must be provided; defaulted ones are optional dependencies).
3. **Always a new instance.** Each call constructs a new instance, so an assisted provider is transient whether or not `scope:` is written. An explicit `scope: .singleton` fails the build at the `scope:` argument.
4. **Not injectable.** The graph cannot supply runtime arguments, so another provider that depends on an assisted provider's key fails the build at that parameter, naming the method to call instead. A defaulted parameter with that key keeps its default. (Injecting a factory such as `(Item) -> ItemDetailViewModel` is deferred; see Out of scope.)
5. **Graph rules still apply.** Assisted providers count for duplicate keys, accessor-name collisions, and cycle detection over their injected parameters.
6. **Unsupported in v1** (each fails the build at the parameter): a default value on an `@Assisted` parameter, and `inout` or variadic `@Assisted` parameters.
7. **Parameters only.** `@Assisted` on a stored property of a scanned type fails the build at the attribute.
8. `@Assisted` on parameters of other initializers or functions (not the selected one) has no effect.
9. These rules are checked by the generator, not the macros, because the selected initializer may be declared in another file.

#### Imports in the generated file

1. The generated file imports `Foundation`, `SwiftBeans`, and every module imported by a scanned file, one line per module (the first path component: `import struct Foundation.URL` → `import Foundation`), sorted.
2. `@testable` and `@preconcurrency` are kept when any scanned import of that module carries them. Imports inside a top-level `#if` block are emitted inside the same condition.
3. For every local package target that provides at least one bean, the generated file imports that target's module, even if no app file imports it.

#### Diagnostics

1. Errors are printed as `<file>:<line>:<column>: error: <message>` (with `note:` lines for related locations), so Xcode and SwiftPM show them as clickable issues, and the build fails.
2. **Every** error found in one run is reported, sorted by file path, line, column, then message. Output is identical across runs.
3. Location rules:
	- Missing dependency → the parameter that needs it (message names the missing key and the consumer).
	- Duplicate provider → an error at each provider declaration.
	- Cycle → an error at the first provider in the cycle (by sort order) with a `note:` at each other provider in it.
	- Accessor-name collision → an error at each provider.
	- Unsupported declaration or key → the attribute or type that is unsupported.
4. **Misuse visible from one declaration is diagnosed by the macro** at that declaration (e.g. `@Bean` not `static`, no return type, `throws` / `async`; `@Service` on a protocol or enum; a non-literal `scope:`), so Xcode shows it inline while editing. The generator does not report the same problem a second time.

#### Generated file

1. The generator writes the output file only when its contents change, so unchanged wiring does not trigger downstream recompiles.
2. Output is a pure function of the scanned sources: declarations, imports and diagnostics are in a stable order.

### Singleton storage (runtime)

1. A singleton's factory runs **at most once per context instance**, including when several threads resolve it for the first time concurrently. Other callers wait for, and receive, that one instance.
2. A singleton factory may resolve other singletons (nested resolution) without deadlocking or aborting.
3. Singleton storage is keyed per accessor, so two beans can never share a slot.
4. The registry's own state is thread-safe. Whether a bean may be shared across actors follows the context's isolation; the registry does not require beans to be `Sendable` (see ARCHITECTURE → Concurrency).

## Behavioral rules

1. **Compile-time completeness:** If a required (non-defaulted, non-`@Assisted`) initializer or `@Bean` parameter type is not provided by any `@Bean` / `@Service` in the scanned graph (or, for a collection parameter, by multi-bind; see `specs/collection-injection/SPEC.md`), the build fails with a diagnostic at that parameter.
2. **No cycles:** Cyclic dependency graphs fail the build.
3. **Duplicates:** Two providers for the same injectable key (normalized type; see Generator rules → Injectable keys) fail the build.
4. **Plain types stay plain:** Prefer constructor injection. `@Service` types remain manually constructible in tests without the generated context.
5. **Thread safety:** Generated singleton storage must be concurrency-safe under Swift 6, and each singleton factory runs at most once per context (see Singleton storage). Exact isolation (`@MainActor` root vs `Sendable` graph) is a Phase 2 contract decision.
6. **Deterministic generation:** Plugin output — generated code and diagnostics — is pure given the same source inputs (stable ordering).

## Package layout (planned)

```
Sources/SwiftBeans/           # Public library: attributes, scopes, root protocols
Sources/SwiftBeansMacros/     # Macro implementation (@main)
Sources/SwiftBeansGenerator/  # CLI / tool invoked by the build plugin (optional split)
Plugins/SwiftBeansPlugin/     # BuildToolPlugin entry
Tests/SwiftBeansTests/        # Runtime/integration of generated graphs (fixtures)
Tests/SwiftBeansMacrosTests/  # Macro expansion tests
```

## Acceptance criteria (BDD)

### Scenario: Configuration bean is injectable

**Given** a `@Configuration` type with a static `@Bean` method returning `URLSession`  
**And** a `@Service` whose initializer requires `URLSession`  
**And** an `@ApplicationContext` root with the build plugin applied  
**When** the target builds  
**Then** the generated root exposes a `UserService` (or equivalent accessor)  
**And** resolving it uses the `URLSession` from the `@Bean`

### Scenario: Service stereotype wires constructor dependencies

**Given** `@Service class OrderService { init(api: APIClient, users: UserService) }`  
**And** `APIClient` and `UserService` are provided in the same scanned graph  
**When** the target builds  
**Then** `OrderService` is available from the `@ApplicationContext` root  
**And** its dependencies are the singleton instances from the graph

### Scenario: Protocol binding

**Given** `@Service(boundTo: APIClient.self) final class DefaultAPIClient: APIClient`  
**And** another service depends on `APIClient`  
**When** the target builds  
**Then** the dependent receives `DefaultAPIClient` as `APIClient`

### Scenario: Missing dependency fails the build

**Given** a `@Service` that depends on `Analytics`  
**And** no `@Bean` / `@Service` provides `Analytics`  
**When** the target builds  
**Then** the build fails with a diagnostic naming the missing type and the consumer  
**And** the diagnostic points at the consumer's `Analytics` parameter (`file:line:column`)

### Scenario: Cyclic dependency fails the build

**Given** `A` depends on `B` and `B` depends on `A` via constructor injection in the scanned graph  
**When** the target builds  
**Then** the build fails with a cycle diagnostic

### Scenario: Duplicate providers fail the build

**Given** two `@Bean` / `@Service` providers for the same unbound key `Foo`  
**When** the target builds  
**Then** the build fails with a duplicate-provider diagnostic

### Scenario: Transient scope creates distinct instances

**Given** a `@Bean(scope: .transient)` (or `@Service` with transient scope) for `Validator`  
**When** the `@ApplicationContext` root resolves `Validator` twice  
**Then** the two instances are not identical (`!==` for classes)

### Scenario: Singleton scope reuses the instance

**Given** a `@Service` (default singleton) `UserService`  
**When** the root resolves `UserService` twice  
**Then** both references are the same instance

### Scenario: Manual construction without the graph

**Given** a `@Service` type `UserService`  
**When** a unit test constructs `UserService(apiClient: MockAPIClient())` directly  
**Then** the type compiles and runs without requiring the generated `@ApplicationContext`

### Scenario: YAML extends the scan set

**Given** an iOS app (or package) with a `.swiftbeans.yml` listing a local package target that defines a `@Service`  
**And** the app target has an `@ApplicationContext` and the build plugin applied  
**When** the app builds  
**Then** that `@Service` is part of the graph and resolvable from the root

### Scenario: Nested folders are scanned without naming conventions

**Given** a target whose `@main` entry file has any name (no `MyApp.swift`) and no asset catalog  
**And** `@Service` types in nested subfolders of the target (e.g. `Domain/`, `Data/Remote/`)  
**When** the target builds  
**Then** every one of those services is in the graph and resolvable from the root

### Scenario: Files outside the target are not scanned

**Given** a `.swift` file inside the target's folder that is not a member of the target  
**And** that file declares a `@Service` with the same key as one in the target  
**When** the target builds  
**Then** the build succeeds without a duplicate-provider diagnostic  
**And** the graph contains only the target's provider

### Scenario: Config above the project root is ignored

**Given** no `.swiftbeans.yml` at the package / project root  
**And** a `.swiftbeans.yml` in a parent folder that lists a local package  
**When** the target builds  
**Then** only the target's own sources are scanned

### Scenario: Editing a local package source regenerates the wiring

**Given** a `.swiftbeans.yml` listing a local package target with `@Service final class Greeter { init() }`  
**And** the app has built once  
**When** `Greeter`'s initializer gains a dependency provided by the graph and the app builds again  
**Then** the generator runs again and the generated accessor passes the new dependency

### Scenario: Editing the config regenerates the wiring

**Given** an app that has built once  
**When** a local package target is added to `.swiftbeans.yml` and the app builds again  
**Then** that target's `@Service` types join the graph

### Scenario: Invalid local package entry fails the build

**Given** a `.swiftbeans.yml` whose `local_packages` entry points to a missing folder, a folder without `Package.swift`, or a target without `Sources/<target>/`  
**When** the target builds  
**Then** the build fails with a diagnostic naming the config file and that entry

### Scenario: Quoted config values

**Given** a `.swiftbeans.yml` with `path: "Packages/Networking"` and a quoted target name  
**When** the configuration is loaded  
**Then** the path and target name are read without the quotes

### Scenario: Generated context protocol

**Given** an `@ApplicationContext` type named `AppContext`  
**And** the scanned graph provides injectable keys (e.g. `UserService`, `any HTTPClient`)  
**When** the target builds  
**Then** the generated file declares `protocol AppContextProtocol: AnyObject` with a getter per key  
**And** declares `extension AppContext: AppContextProtocol`  
**And** a hand-written type may conform to `AppContextProtocol` without using the generated accessors

### Scenario: `any P` and `P` are the same key

**Given** `@Service(boundTo: Store.self) final class DiskStore: Store`  
**And** `@Service final class Repo { init(store: any Store) }`  
**When** the target builds  
**Then** `Repo` receives the `DiskStore`  
**And** the context has exactly one accessor for the key, `store`, typed `any Store`

### Scenario: Accessor names are valid identifiers for any supported key

**Given** `@Bean` methods returning `[String]`, `Cache<User>` and `Class`, and a nested `@Service` `Outer.Inner`  
**When** the target builds  
**Then** the generated accessors are `stringArray`, `userCache`, `` `class` `` and `outerInner`  
**And** the generated file compiles

### Scenario: Unsupported key fails at the declaration

**Given** a `@Bean` method returning `Logger?`  
**When** the target builds  
**Then** the build fails with an error at that method's return type saying optional keys are not supported

### Scenario: Accessor name collision fails the build

**Given** a `@Service` `HTTPClient` and a `@Bean` returning `HttpClient`, which both produce the accessor name `httpClient`  
**When** the target builds  
**Then** the build fails with an error at each provider naming the shared accessor

### Scenario: Throwing or async bean fails the build

**Given** `@Bean static func database() throws -> Database`  
**When** the target builds  
**Then** the `@Bean` macro reports an error at that method  
**And** the generator does not report it a second time

### Scenario: Initializer selection

**Given** `@Service final class ReportService` with `@Inject init(store: any Store)` and `convenience init()`  
**When** the target builds  
**Then** the accessor calls `ReportService(store: self.store)`

**Given** the same type without `@Inject`  
**When** the target builds  
**Then** the build fails listing both initializers and suggesting `@Inject`

### Scenario: Initializers in extensions and memberwise structs

**Given** `@Service final class A` whose only initializer is declared in an extension in another file  
**And** `@Service struct B { let a: A; var retries: Int = 3 }` with no declared initializer  
**When** the target builds  
**Then** `A` is built with the extension's initializer  
**And** `B` is built as `B(a: self.a)` (the defaulted `retries` is not provided by the graph, so its default is used)

### Scenario: Defaulted parameters are optional dependencies

**Given** `@Service final class Feed { init(api: API, clock: Clock = .system) }`  
**When** the graph provides `API` but not `Clock` and the target builds  
**Then** the build succeeds and `Feed` is built with the default `clock`  
**When** a `@Bean` providing `Clock` is added and the target builds  
**Then** `Feed` receives the graph's `Clock`

### Scenario: Nested and qualified declarations are wired

**Given** `enum Features { @Service final class Search { init() } }`  
**And** `@SwiftBeans.Service final class Ranker { init(search: Features.Search) }`  
**When** the target builds  
**Then** both are in the graph and `Ranker` receives `Features.Search`

### Scenario: Assisted service gets a method accessor

**Given** `@Service final class ItemDetailViewModel { init(repository: ItemRepository, @Assisted item: Item) }` and a provided `ItemRepository`  
**When** the target builds  
**Then** `AppContextProtocol` requires `func itemDetailViewModel(item: Item) -> ItemDetailViewModel`  
**And** the context implements it as `ItemDetailViewModel(repository: self.itemRepository, item: item)`  
**And** there is no `itemDetailViewModel` property  
**And** two calls return two different instances

### Scenario: Assisted parameters keep labels and order

**Given** `@Service final class Search { init(@Assisted _ query: String, api: API, @Assisted page pageIndex: Int) }`  
**When** the target builds  
**Then** the context has `func search(_ query: String, page pageIndex: Int) -> Search`  
**And** it calls `Search(query, api: self.api, page: pageIndex)`

### Scenario: Assisted `@Bean`

**Given** `@Bean static func report(store: any Store, @Assisted title: String) -> Report` in a `@Configuration` type  
**When** the target builds  
**Then** the context has `func report(title: String) -> Report` that calls the method with `self.store` and `title`

### Scenario: Assisted provider cannot be injected

**Given** assisted `ItemDetailViewModel` and `@Service final class Coordinator { init(detail: ItemDetailViewModel) }`  
**When** the target builds  
**Then** the build fails at `Coordinator`'s `detail` parameter, saying `ItemDetailViewModel` takes runtime arguments and naming `itemDetailViewModel(item:)`

### Scenario: Assisted provider cannot be a singleton

**Given** `@Service(scope: .singleton)` on a type whose selected initializer has an `@Assisted` parameter  
**When** the target builds  
**Then** the build fails at the `scope:` argument  
**When** `scope:` is omitted  
**Then** the build succeeds and each call creates a new instance

### Scenario: Unsupported `@Assisted` usage fails the build

**Given** an `@Assisted` parameter with a default value, an `@Assisted` variadic parameter, or `@Assisted` on a stored property of a `@Service` type  
**When** the target builds  
**Then** the build fails with an error at each of them

### Scenario: Declarations inside `#if` fail the build

**Given** a `@Service` declared inside `#if DEBUG`  
**When** the target builds  
**Then** the build fails with an error at that `@Service` saying `#if` is not supported in v1

### Scenario: Non-literal scope fails the build

**Given** `@Service(scope: defaultScope) final class Cache`  
**When** the target builds  
**Then** the build fails with an error at the `scope:` argument

### Scenario: Local package beans are imported and must be public

**Given** `.swiftbeans.yml` lists target `Networking`, which declares `public final class APIClient` with `@Service` and a `public init()`  
**And** no app file imports `Networking`  
**When** the app builds  
**Then** the generated file imports `Networking` and the app's context exposes `apiClient`  
**When** the initializer is `internal` instead  
**Then** the build fails at that `@Service` saying local package providers must be public

### Scenario: Contexts in local packages are not roots

**Given** a local package target that declares its own `@ApplicationContext`  
**And** the app target declares `@ApplicationContext final class AppContext`  
**When** the app builds  
**Then** the build succeeds and only `AppContext` gets generated accessors

### Scenario: Target without a context

**Given** a target with `@Service` types, no `@ApplicationContext`, and the plugin applied  
**When** the target builds  
**Then** the build succeeds and the generated file contains no declarations

### Scenario: Imports are copied faithfully

**Given** one scanned file with `import struct Foundation.URL` and `@preconcurrency import Legacy`  
**And** another with `#if canImport(UIKit)` / `import UIKit` / `#endif` at top level  
**When** the target builds  
**Then** the generated file contains `import Foundation`, `@preconcurrency import Legacy`, and `import UIKit` inside the same `#if canImport(UIKit)`

### Scenario: All errors are reported, in a stable order

**Given** a graph with two missing dependencies in different files and one duplicate key  
**When** the target builds twice  
**Then** each build reports all of them as `file:line:column: error:` lines  
**And** both builds print them in the same order

### Scenario: Unchanged output is not rewritten

**Given** a target that has built once  
**When** a scanned file changes in a way that does not change the wiring (e.g. a method body) and the target builds again  
**Then** the generated file's contents and modification date are unchanged

### Scenario: Singleton factory runs once under concurrent first access

**Given** a singleton bean whose factory counts its invocations  
**When** many threads resolve it for the first time at the same moment  
**Then** every caller receives the same instance  
**And** the factory ran exactly once

### Scenario: Nested singleton resolution

**Given** singleton `B` whose factory resolves singleton `A`  
**When** `B` is resolved first (from any thread)  
**Then** both are created once and resolution does not deadlock or abort

## Out of scope (v1)

- Runtime service-locator / `resolve(Type.self)` dictionary container (distinct from the `@ApplicationContext` **attribute**)
- Classpath-wide scan across arbitrary closed-source modules without YAML / plugin config
- `@Service` synthesizing protocol conformances or registration markers (attribute-only)
- Instance (non-static) `@Bean` methods
- `@Autowired` property injection, field injection, method injection
- Spring AOP, `@Transactional`, proxies, named qualifiers (deferred)
- Context arguments (values passed into the `@ApplicationContext` initializer and injected as beans) — deferred
- Annotated declarations inside `#if` blocks (fail the build in v1)
- Matching keys across typealiases or module-qualified spellings (matched by spelling; diagnostics hint at near matches)
- Generic `@Service` types; optional / tuple / function / opaque keys
- Request / session / Web scopes
- SwiftUI `@Environment` bridges (may be later)
- Subcontexts (candidate for v1.1)
- Injecting assisted factories into other beans (e.g. a bean taking `(Item) -> ItemDetailViewModel`); assisted providers are only reachable from the context in v1
- Default values on `@Assisted` parameters
- Circular dependencies broken via lazy/`ObjectFactory` (fail instead)
- Drop-in compatibility with Sword, Pin, Needle, Swinject, or Factory
- Generating fake / mock `@ApplicationContext` implementations (apps hand-write fakes against `{Context}Protocol`)

## Fallback policy

If, during Phase 4, compile-time generation + plugin scanning cannot satisfy the acceptance criteria with acceptable DX (e.g. fundamental Swift/plugin limitations), document the failure in `memory/decisions.md` and open a new spec for a **runtime container** path. Do not silently ship a half-runtime hybrid without a new Phase 1 approval.

## Resolved decisions

| Topic | Decision |
|-------|----------|
| Root attribute | `@ApplicationContext` (compile-time root; not a runtime map) |
| `@Service` shape | Attribute-only for the scanner; no required protocol conformance |
| Multi-module scan | YAML config (supports Xcode apps without `Package.swift`) |
| Source discovery | Build-system file list + `.swiftbeans.yml` at the package/project root only; no folder heuristics or upward search (2026-10-15) |
| `@Bean` methods | Must be `static` |
| Named qualifiers | Deferred (no v1 BDD requirement) |
| Context protocol name | `{ContextTypeName}Protocol` (e.g. `AppContextProtocol`); fakes are user-owned |
| Key matching | Normalized syntax; `any P` ≡ `P`; qualified names / typealiases by spelling (2026-10-15) |
| Accessor names | Derived from the key with defined rules for nested, collection and generic types; keywords escaped; collisions fail (2026-10-15) |
| Multiple initializers | `@Inject` marks the one to use; ambiguity fails the build (2026-10-15) |
| Defaulted parameters | Injected when provided, else default (2026-10-15) |
| Throwing / async factories | Not supported; macro error (2026-10-15) |
| Diagnostics | `file:line:column`, all errors per run, stable order; single-declaration misuse via macros (2026-10-15) |
| Singleton creation | Factory runs at most once per context, even under concurrent first access (2026-10-15) |
| Runtime arguments | `@Assisted` parameter wrapper; assisted providers become context methods, are always transient and not injectable (2026-10-15) |
| Collection injection | `[E]` multi-binds every bean that is an `E` when no `[E]` bean exists; own spec `specs/collection-injection/SPEC.md` (2026-10-15) |

## Phase gate

Phase 1–2 approved 2026-10-14. Phase 3–4 implemented in package tests. Xcode E2E via `Examples/SwiftBeansExample/` (coordinator demo + `SwiftBeansExampleTests`) green on macOS 2026-10-14.

`{Context}Protocol` generation: Phase 1 approved with plan 2026-10-14; Phase 3–4 follow in package tests + example `FakeAppContext` / Previews.

Generator rules + Singleton storage (review #5–11, #13–16): Phase 1 approved 2026-10-15; Phase 2 in ARCHITECTURE.md.

Runtime arguments (`@Assisted`): Phase 1–2 approved 2026-10-15; Phases 3–4 implemented 2026-10-15 (`swift test`: 133 tests). The example app adopts it in `ItemDetailViewModel` (replacing `load(seed:)`'s two-step setup) as its compile check.
