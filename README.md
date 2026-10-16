# SwiftBeans

[![CI](https://github.com/illescasDaniel/SwiftBeans/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/illescasDaniel/SwiftBeans/actions/workflows/ci.yml)

Spring-style dependency injection for Swift, wired at **compile time**.

You annotate types and factories. A build tool plugin scans your target, checks the graph, and generates plain Swift accessors on your context. A missing, duplicate or cyclic dependency fails the build with a clickable `file:line:column` error. There is no runtime container and no `resolve(Type.self)`.

```swift
@ApplicationContext
final class AppContext {}

@Service
final class UserService {
	init(apiClient: any APIClient) { … }
}

let context = AppContext()
let users = context.userService // generated, type-checked, no lookup
```

Requirements: Swift 6.4 toolchain; iOS 18, macOS 15, tvOS 18, watchOS 11, Mac Catalyst 18.

## Contents

- [Installation](#installation)
- [Concepts](#concepts)
- [Scopes](#scopes)
- [Binding to protocols](#binding-to-protocols)
- [Choosing an initializer: `@Inject`](#choosing-an-initializer-inject)
- [Runtime arguments: `@Assisted`](#runtime-arguments-assisted)
- [Testing and Previews: `{Context}Protocol`](#testing-and-previews-contextprotocol)
- [Beans from local packages: `.swiftbeans.yml`](#beans-from-local-packages-swiftbeansyml)
- [Rules worth knowing](#rules-worth-knowing)
- [Example app](#example-app)
- [Project docs](#project-docs)

## Installation

SwiftBeans is pre-1.0: any `0.x` minor release may break the API, so pin with `.upToNextMinor` rather than `from:`.

The package exports two products: the `SwiftBeans` library and the `SwiftBeansPlugin` build tool plugin. Attach the plugin to the target that declares your `@ApplicationContext`.

### Swift Package Manager

```swift
dependencies: [
	.package(url: "https://github.com/illescasDaniel/SwiftBeans", .upToNextMinor(from: "0.1.0")),
],
targets: [
	.target(
		name: "App",
		dependencies: [.product(name: "SwiftBeans", package: "SwiftBeans")],
		plugins: [.plugin(name: "SwiftBeansPlugin", package: "SwiftBeans")]
	),
]
```

### Xcode app project

1. Add the package and link the `SwiftBeans` library to the app target.
2. In the app target's **Build Phases → Run Build Tool Plug-ins**, add `SwiftBeansPlugin`.
3. Trust the plugin and macros when Xcode asks (on CI, pass `-skipPackagePluginValidation -skipMacroValidation` to `xcodebuild`).

The plugin writes `SwiftBeansGenerated.swift` into the build folder. You never edit or commit it.

Next to it the plugin writes `SwiftBeansGraph.md` (providers and dependencies as tables) and `SwiftBeansGraph.dot` (Graphviz: `dot -Tsvg SwiftBeansGraph.dot -o graph.svg`), a quick way to see what is wired to what. With SwiftPM they are under `.build/plugins/outputs/<package>/<target>/destination/SwiftBeansPlugin/`; with Xcode, in the target's plugin work folder inside DerivedData (search for `SwiftBeansGraph.md`). They are only written when generation succeeds.

## Concepts

| Annotation | On | Meaning |
|------------|----|---------|
| `@ApplicationContext` | a `class` | The root of the graph. Generated accessors are added to it as an extension. One per target. |
| `@Service` | a `class`, `struct` or `actor` | Register the type. Its initializer parameters are injected by type. |
| `@Configuration` | an `enum`, `struct`, `class` or `actor` | Holds `@Bean` factories. |
| `@Bean` | a `static func` in a `@Configuration` | Register the return value. Use it for types you don't own (`URLSession`, third-party clients) or that need custom setup. |
| `@Inject` | an `init` | Pick the initializer the graph calls when a service has several. |
| `@Assisted` | an initializer or `@Bean` parameter | A value the caller passes at creation time instead of the graph. |

```swift
import SwiftBeans

@Configuration
enum AppConfiguration {
	@Bean
	static func urlSession() -> URLSession { .shared }

	@Bean
	static func apiClient(urlSession: URLSession) -> any APIClient {
		DefaultAPIClient(urlSession: urlSession)
	}
}

@Service
final class UserService {
	private let apiClient: any APIClient
	init(apiClient: any APIClient) { self.apiClient = apiClient }
}

@ApplicationContext
final class AppContext {}
```

Generated (simplified):

```swift
extension AppContext {
	var urlSession: URLSession {
		_swiftBeansRegistry.singleton(key: "urlSession") { AppConfiguration.urlSession() }
	}
	var apiClient: any APIClient {
		_swiftBeansRegistry.singleton(key: "apiClient") { AppConfiguration.apiClient(urlSession: self.urlSession) }
	}
	var userService: UserService {
		_swiftBeansRegistry.singleton(key: "userService") { UserService(apiClient: self.apiClient) }
	}
}
```

Accessor names come from the type: `UserService` → `userService`, `URLSession` → `urlSession`, `Outer.Inner` → `outerInner`, `[User]` → `userArray`, `[String: Int]` → `stringIntDictionary`.

Your types stay plain Swift: tests can call `UserService(apiClient: FakeAPIClient())` directly, without any context.

## Scopes

| Scope | Behavior |
|-------|----------|
| `.singleton` (default) | One instance per context instance, created on first access. Thread-safe: the factory runs at most once even under concurrent first access. |
| `.transient` | A new instance on every access. Good for view models. |

```swift
@Service(scope: .transient)
@MainActor @Observable
final class ItemListViewModel {
	init(fetchItems: FetchItemsUseCase) { … }
}
```

`scope:` must be a literal (`.singleton` / `.transient`), because the generator reads it at build time.

SwiftBeans does not force an isolation on your graph. Put `@MainActor` on the context (or use default main-actor isolation) for app code; leave it off for server or CLI code.

## Binding to protocols

Register an implementation under a protocol so consumers depend on the abstraction:

```swift
@Service(boundTo: ItemRepository.self)
final class JSONPlaceholderItemRepository: ItemRepository {
	init(httpClient: any HTTPClient) { … }
}

@Service
final class FetchItemsUseCase {
	init(repository: any ItemRepository) { … } // `any P` and `P` are the same key
}
```

A `@Bean` whose return type is a protocol (`-> any APIClient`) does the same.

## Choosing an initializer: `@Inject`

With exactly one eligible initializer there is nothing to do. With several, mark the one the graph calls:

```swift
@Service
final class TagSummary {
	@Inject
	init(tagCounts: [String: Int]) { … }

	convenience init(tags: [String]) { … } // for tests and manual use
}
```

A parameter with a default value is an optional dependency: it is injected if the graph provides that type, and left to its default otherwise.

## Runtime arguments: `@Assisted`

Some values only exist where an object is created: the selected item, a navigation argument, a search query. Mark those parameters `@Assisted` and the context exposes a **method** instead of a property. The graph fills in the rest.

```swift
@Service
@MainActor @Observable
final class ItemDetailViewModel {
	init(repository: any ItemRepository, @Assisted item: Item) { … }
}

// Generated
extension AppContext {
	func itemDetailViewModel(item: Item) -> ItemDetailViewModel {
		ItemDetailViewModel(repository: self.itemRepository, item: item)
	}
}

// Call site
let viewModel = context.itemDetailViewModel(item: selectedItem)
```

- `@Assisted` is a marker property wrapper: callers pass a plain `Item` and the initializer body sees a plain `Item`.
- Labels and order are kept (`@Assisted _ id: Int` → `itemDetailViewModel(_ id: Int)`).
- An assisted provider is always transient. An explicit `scope: .singleton` is a build error.
- Other beans cannot inject an assisted type (the graph has no runtime arguments to give); the error names the method to call. Injecting factories such as `(Item) -> ItemDetailViewModel` is planned.
- Default values, `inout` and variadic `@Assisted` parameters are not supported yet.

## Testing and Previews: `{Context}Protocol`

For each context the plugin also generates a protocol with the same accessors and methods, and conforms the context to it:

```swift
// Generated
protocol AppContextProtocol: AnyObject {
	var itemRepository: any ItemRepository { get }
	var itemListViewModel: ItemListViewModel { get }
	func itemDetailViewModel(item: Item) -> ItemDetailViewModel
	// …
}
extension AppContext: AppContextProtocol {}
```

Type the code that creates screens (a coordinator, a factory) against `any AppContextProtocol`, and hand-write a fake for Previews and tests:

```swift
#if DEBUG
@MainActor
final class FakeAppContext: AppContextProtocol {
	let itemRepository: any ItemRepository
	// …
	var itemListViewModel: ItemListViewModel {
		ItemListViewModel(fetchItems: FetchItemsUseCase(repository: itemRepository))
	}
	func itemDetailViewModel(item: Item) -> ItemDetailViewModel {
		ItemDetailViewModel(repository: itemRepository, item: item)
	}

	init(itemRepository: (any ItemRepository)? = nil) {
		self.itemRepository = itemRepository ?? InMemoryItemRepository()
	}
}
#endif

#Preview {
	let context = FakeAppContext()
	ItemListView(viewModel: context.itemListViewModel)
}
```

When the graph gains a bean, the fake stops compiling until you add it, so it can't silently drift.

Keep the context out of views: views receive their view model; the coordinator holds the context and builds screens.

## Beans from local packages: `.swiftbeans.yml`

The plugin scans exactly the files the build system compiles for the target. To let types from local packages join the graph, list them in `.swiftbeans.yml` at the package root (SPM) or next to the `.xcodeproj` (Xcode):

```yaml
local_packages:
  - path: Packages/GreetingKit   # relative to this file
    targets:
      - GreetingKitLive
```

- Every `.swift` file under `Packages/GreetingKit/Sources/GreetingKitLive/` is scanned, and the generated file imports `GreetingKitLive` for you, so the app can depend on just the protocol module.
- Providers in local packages must be `public` (type, selected initializer, or `public static` `@Bean` in a `public` configuration).
- A wrong path, missing target folder or unsupported YAML fails the build with an error pointing at the entry.
- Types from other dependencies (remote packages, SDKs) are registered with `@Bean`.
- Adding a file under a listed target (or creating/editing `.swiftbeans.yml`) regenerates the wiring on the next build; no clean build needed. Edge case: files added to a folder that was itself created after the last plugin planning may need a re-plan (edit any file in the app target).

## Rules worth knowing

- Every annotated declaration is wired or reported; nothing is skipped silently. All errors from one build are reported together, in a stable order.
- `@Bean` methods are `static`, have a return type, no generics, and may not `throw` or be `async`; the same goes for selected initializers.
- Annotated declarations inside `#if` blocks are a build error (the generator can't know which branch compiles). `#if` inside a function body is fine.
- Unsupported key types: optionals, tuples, functions, `some P`, metatypes, `any A & B`, generic parameters. Wrap them in a named type or provide a protocol.
- Keys match by spelling after normalization: `[String: Int]` ≡ `Dictionary<String, Int>`, `any P` ≡ `P`, but a typealias and its underlying type are different keys.
- Generic `@Service` types, property injection, qualifiers and subcontexts are not supported in v1.

## Example app

[`Examples/SwiftBeansExample`](Examples/SwiftBeansExample) is a multiplatform SwiftUI app (iOS + macOS) that uses every feature above: `@Configuration` beans for an HTTP client, a protocol-bound repository, transient view models, `@Inject`, `@Assisted`, a local package via `.swiftbeans.yml`, a coordinator over `AppContextProtocol`, and a `FakeAppContext` for Previews and tests. Debug builds use an offline fake HTTP handler; Release builds use `URLSession.shared`.

```bash
cd Examples/SwiftBeansExample && xcodebuild test -project SwiftBeansExample.xcodeproj -scheme SwiftBeansExample -destination 'platform=macOS' -skipPackagePluginValidation -skipMacroValidation
```

## Project docs

- [SPEC](specs/compile-time-di/SPEC.md): behavior, generator rules and acceptance scenarios.
- [ARCHITECTURE](specs/compile-time-di/ARCHITECTURE.md): module seams, generator pipeline, generated code shape.
- [AGENTS.md](AGENTS.md): how this repo is developed (spec-driven, phase gates).

## License

MIT. See [LICENSE](LICENSE).
