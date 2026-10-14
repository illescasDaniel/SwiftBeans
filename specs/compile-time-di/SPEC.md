# Spec: Compile-Time Spring-Style DI

## Metadata

| Field | Value |
|-------|-------|
| Feature | `compile-time-di` |
| Status | Approved (Phase 1) — 2026-10-14 |
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
- Additional local packages / targets that should participate in the graph are declared in a **YAML config file** (name TBD in Phase 2; e.g. `.swiftbeans.yml` at the app or package root). This supports **Xcode iOS apps that have no `Package.swift`**, while SPM packages can use the same file.
- Types in dependencies that are not scanned must be provided via `@Bean` in a `@Configuration`.
- Consumers attach the SwiftBeans build plugin to the app/root target that owns the `@ApplicationContext` (and any target that needs generated wiring).

Example shape (illustrative; exact schema in Phase 2):

```yaml
# .swiftbeans.yml
local_packages:
  - path: Packages/Networking
    targets:
      - Networking
  - path: Packages/FeatureHome
    targets:
      - FeatureHome
```

## Behavioral rules

1. **Compile-time completeness:** If a required initializer parameter type is not provided by any `@Bean` / `@Service` / context argument in the scanned graph, the build fails with a clear diagnostic.
2. **No cycles:** Cyclic dependency graphs fail the build.
3. **Duplicates:** Two providers for the same injectable key (type + optional qualifier) without an explicit override rule fail the build.
4. **Plain types stay plain:** Prefer constructor injection. `@Service` types remain manually constructible in tests without the generated context.
5. **Thread safety:** Generated singleton storage must be concurrency-safe under Swift 6 (ApproachableConcurrency / `Mutex` or equivalent). Exact isolation (`@MainActor` root vs `Sendable` graph) is a Phase 2 contract decision.
6. **Deterministic generation:** Plugin output is pure given the same source inputs (stable ordering of declarations).

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
**And** no `@Bean` / `@Service` / context argument provides `Analytics`  
**When** the target builds  
**Then** the build fails with a diagnostic naming the missing type and the consumer

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

## Out of scope (v1)

- Runtime service-locator / `resolve(Type.self)` dictionary container (distinct from the `@ApplicationContext` **attribute**)
- Classpath-wide scan across arbitrary closed-source modules without YAML / plugin config
- `@Service` synthesizing protocol conformances or registration markers (attribute-only)
- Instance (non-static) `@Bean` methods
- `@Autowired` property injection, field injection, method injection
- Spring AOP, `@Transactional`, proxies, named qualifiers (deferred)
- Request / session / Web scopes
- SwiftUI `@Environment` bridges (may be later)
- Assisted injection / subcontexts (candidate for v1.1)
- Circular dependencies broken via lazy/`ObjectFactory` (fail instead)
- Drop-in compatibility with Sword, Pin, Needle, Swinject, or Factory

## Fallback policy

If, during Phase 4, compile-time generation + plugin scanning cannot satisfy the acceptance criteria with acceptable DX (e.g. fundamental Swift/plugin limitations), document the failure in `memory/decisions.md` and open a new spec for a **runtime container** path. Do not silently ship a half-runtime hybrid without a new Phase 1 approval.

## Resolved decisions

| Topic | Decision |
|-------|----------|
| Root attribute | `@ApplicationContext` (compile-time root; not a runtime map) |
| `@Service` shape | Attribute-only for the scanner; no required protocol conformance |
| Multi-module scan | YAML config (supports Xcode apps without `Package.swift`) |
| `@Bean` methods | Must be `static` |
| Named qualifiers | Deferred (no v1 BDD requirement) |

## Phase gate

Phase 1–2 approved 2026-10-14. Phase 3–4 implemented in package tests. Pending Xcode E2E via `Examples/SwiftBeansExample/`.
