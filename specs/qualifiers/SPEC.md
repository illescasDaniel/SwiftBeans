# Spec: Qualifiers (named beans)

## Metadata

| Field | Value |
|-------|-------|
| Feature | Several beans of one type, told apart by a name |
| Extends | [`specs/compile-time-di/SPEC.md`](../compile-time-di/SPEC.md) (keys, accessor names, diagnostics, `{Context}Protocol`) |
| Swift tools | 6.4 (package), SE-0293 parameter property wrappers |
| Targets touched | `SwiftBeans` (macro overloads, `Qualifier` wrapper), `SwiftBeansSyntaxRules`, `SwiftBeansMacros`, `SwiftBeansGeneratorCore` |
| Design notes | 2026-10-15 discussion, recorded in `memory/progress.md` |

## Goal

An app often needs two beans of the same type configured differently: a snake-case and a camel-case `JSONDecoder`, a public and an authenticated `URLSession`. Today each key can have one provider, so the only workaround is a wrapper type per configuration. Qualifiers let a provider declare a name and a dependency ask for it, while keeping the graph checked at build time.

```swift
@Configuration
enum Coding {
	@Bean
	static func decoder() -> JSONDecoder { JSONDecoder() }

	@Bean(named: "snakeCase")
	static func snakeCaseDecoder() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return decoder
	}
}

@Service
final class ItemParser {
	init(@Qualifier("snakeCase") decoder: JSONDecoder, fallback: JSONDecoder) { … }
}

// Generated
protocol AppContextProtocol: AnyObject {
	var itemParser: ItemParser { get }
	var jsonDecoder: JSONDecoder { get }
	var snakeCaseJSONDecoder: JSONDecoder { get }
}

extension AppContext {
	var itemParser: ItemParser {
		_swiftBeansRegistry.singleton(key: "itemParser") {
			ItemParser(decoder: self.snakeCaseJSONDecoder, fallback: self.jsonDecoder)
		}
	}
	// …
}
```

## Public API surface

### Naming a provider: `named:`

`@Bean` and `@Service` gain overloads with a `named:` argument. The existing signatures are unchanged.

```swift
public macro Bean(named: String, scope: BeanScope = .singleton)
public macro Service(named: String, scope: BeanScope = .singleton)
public macro Service(boundTo: Any.Type, named: String, scope: BeanScope = .singleton)
```

### Asking for a named bean: `@Qualifier`

```swift
@propertyWrapper
@frozen
public struct Qualifier<Value> {
	public let wrappedValue: Value
	public init(wrappedValue: Value, _ name: String)
}
```

`@Qualifier("snakeCase")` is a marker property wrapper on initializer and `@Bean` parameters, the same trick as `@Assisted`. Under SE-0293 the caller passes a plain `JSONDecoder` and the body reads `decoder` as a plain value, so manual construction (`ItemParser(decoder: myDecoder, fallback: other)`) needs nothing extra. The wrapper stores nothing beyond the value; the name only matters to the generator.

## Rules

### Keys

1. **A key is (type, qualifier).** The qualifier is part of the key, not a global bean name: `named: "snakeCase"` on a `JSONDecoder` and on a `JSONEncoder` are two different, unrelated keys. Type normalization (`any P` ≡ `P`, sugar, spelling) is unchanged and applies to the type part.
2. **Unqualified is the default.** A provider without `named:` provides the unqualified key `(T, none)`; a parameter without `@Qualifier` requires it. Named and unnamed providers of the same type coexist.
3. **No implicit pick.** An unqualified parameter is only satisfied by the unqualified provider. If the graph has named providers of that type but no unqualified one, the build fails at the parameter, listing the named providers (with the `@Qualifier` to add) as notes. This holds even when there is exactly one named provider.
4. **Unknown pair.** A `@Qualifier("x")` parameter whose `(type, "x")` has no provider fails the build at the parameter. Providers of the same type under another name (or unnamed) are listed as "did you mean" notes.
5. **Defaulted parameters stay optional.** A defaulted parameter with `@Qualifier` is injected when its `(type, name)` is provided and otherwise keeps its default, exactly like an unqualified defaulted parameter (compile-time-di Providers and dependencies, rule 4). A defaulted unqualified parameter is never filled from a named provider.
6. **Duplicates** are per (type, qualifier): two providers with the same type and name fail the build at both, as today; an unnamed and a named provider of one type are not duplicates.
7. **Protocol bindings.** `@Service(boundTo: P.self, named: "x")` and a `@Bean(named: "x")` returning `any P` provide `(P, "x")`; `@Qualifier("x") store: any P` receives it.

### Names

1. **String literals only.** `named:` and the `@Qualifier` argument must each be a single string literal without interpolation. The generator cannot evaluate anything else.
2. **Identifier-shaped.** A name must be non-empty, start with an ASCII letter or `_`, and contain only ASCII letters, digits and `_`, because it becomes part of an accessor name.
3. Names are compared exactly (case-sensitive). Two names that differ only in their first letter's case produce the same accessor and fail as a collision (Accessor names, rule 3).

### Accessor names

1. **Qualifier + type.** A qualified key's accessor is the qualifier followed by the type's accessor pieces, with the usual leading-word lowercasing applied to the whole: `("snakeCase", JSONDecoder)` → `snakeCaseJSONDecoder`, `("public", URLSession)` → `publicURLSession`, `("primary", any Store)` → `primaryStore`, `("cached", [User])` → `cachedUserArray`.
2. The unqualified key's accessor is unchanged.
3. **Collisions fail at both declarations.** If a qualified accessor equals another key's accessor (e.g. `("snakeCase", JSONDecoder)` and a type `SnakeCaseJSONDecoder`, or `("URL", Session)` and `URLSession`), the build fails at every provider involved, naming both keys. There are no numeric suffixes (they would be unstable and unreadable). An `accessor:` override may come later.
4. The registry key is the accessor name without backticks, as today, so a named singleton gets its own slot.

### `{Context}Protocol`

Every qualified provider gets a requirement on `{Context}Protocol` with the same name and signature as its accessor, sorted by accessor name with everything else. An assisted provider with a name gets a method named after its qualified accessor.

### Where `@Qualifier` may appear

1. On a parameter of the selected `@Service` initializer or of a `@Bean` method. On other initializers or functions it has no effect.
2. `@Qualifier` on a stored property of a scanned type fails the build at the attribute ("parameters only").
3. `@Qualifier` together with `@Assisted` on one parameter fails the build at the `@Qualifier` attribute: a runtime argument is not looked up in the graph.
4. Recognized as `@Qualifier` or `@SwiftBeans.Qualifier`; `@Other.Qualifier` is ignored.

### Diagnostics ownership

- **Macros** (inline in Xcode): a `named:` argument that is not a string literal, or not identifier-shaped, fails at the argument. The generator drops such a provider without reporting it again.
- **Generator**: everything about `@Qualifier` (it is a property wrapper, not a macro): non-literal or invalid name, missing name, use with `@Assisted`, on a stored property; and the graph rules above (unknown pair, unqualified with only named providers, duplicates, accessor collisions).

Diagnostic messages spell a qualified key as `'JSONDecoder' named "snakeCase"`.

### Compatibility

**A graph that uses no qualifiers generates byte-identical output to the generator before this feature.** Ordering, accessor names, registry keys, imports and diagnostics for unqualified graphs do not change.

## Acceptance criteria (BDD)

### Scenario: Named bean gets a qualified accessor

**Given** `@Bean static func decoder() -> JSONDecoder` and `@Bean(named: "snakeCase") static func snakeCaseDecoder() -> JSONDecoder` in a `@Configuration` type  
**When** the target builds  
**Then** `AppContextProtocol` requires `var jsonDecoder: JSONDecoder { get }` and `var snakeCaseJSONDecoder: JSONDecoder { get }`  
**And** `snakeCaseJSONDecoder` is a singleton under registry key `"snakeCaseJSONDecoder"` calling `snakeCaseDecoder()`

### Scenario: Qualified parameter receives the named bean

**Given** the two decoders above and `@Service final class ItemParser { init(@Qualifier("snakeCase") decoder: JSONDecoder, fallback: JSONDecoder) }`  
**When** the target builds  
**Then** the context constructs `ItemParser(decoder: self.snakeCaseJSONDecoder, fallback: self.jsonDecoder)`

### Scenario: Same name on different types are different beans

**Given** `@Bean(named: "snakeCase")` returning `JSONDecoder` and `@Bean(named: "snakeCase")` returning `JSONEncoder`  
**When** the target builds  
**Then** the build succeeds with accessors `snakeCaseJSONDecoder` and `snakeCaseJSONEncoder`

### Scenario: Named service, bound to a protocol

**Given** `@Service(boundTo: Store.self, named: "memory") final class MemoryStore` and `@Service(named: "shared") final class DiskCache`  
**And** `@Service final class Sync { init(@Qualifier("memory") store: any Store, @SwiftBeans.Qualifier("shared") cache: DiskCache) }`  
**When** the target builds  
**Then** the context has `var memoryStore: any Store` and `var sharedDiskCache: DiskCache`  
**And** constructs `Sync(store: self.memoryStore, cache: self.sharedDiskCache)`

### Scenario: Qualified `@Bean` parameter and named assisted provider

**Given** `@Bean static func api(@Qualifier("public") session: URLSession) -> API` and `@Bean(named: "public") static func publicSession() -> URLSession`  
**And** `@Service(named: "draft") final class Editor { init(@Assisted text: String) }`  
**When** the target builds  
**Then** the context calls `Config.api(session: self.publicURLSession)`  
**And** has `func draftEditor(text: String) -> Editor` on the context and the protocol

### Scenario: Unknown qualifier fails at the parameter

**Given** only `@Bean(named: "snakeCase")` and an unnamed `@Bean` for `JSONDecoder`  
**And** a parameter `@Qualifier("camelCase") decoder: JSONDecoder` without a default  
**When** the target builds  
**Then** the build fails at that parameter with `missing dependency 'JSONDecoder' named "camelCase"`  
**And** notes point at the `snakeCase` and unnamed providers

### Scenario: Unqualified parameter with only named providers fails

**Given** `@Bean(named: "snakeCase")` and `@Bean(named: "camelCase")` for `JSONDecoder` and no unnamed one  
**And** a parameter `decoder: JSONDecoder` without `@Qualifier` and without a default  
**When** the target builds  
**Then** the build fails at that parameter saying only named providers exist  
**And** a note at each named provider names the `@Qualifier` to add  
**When** there is only one named provider  
**Then** the build still fails the same way

### Scenario: Defaulted parameters keep their default

**Given** `init(@Qualifier("missing") decoder: JSONDecoder = JSONDecoder(), plain: JSONDecoder = JSONDecoder())` and only a `snakeCase` decoder  
**When** the target builds  
**Then** the build succeeds and neither argument is passed

### Scenario: Duplicate names fail per type

**Given** two `@Bean(named: "snakeCase")` methods returning `JSONDecoder`  
**When** the target builds  
**Then** the build fails at both with a duplicate-provider error for `'JSONDecoder' named "snakeCase"`  
**When** one of them is unnamed instead  
**Then** the build succeeds

### Scenario: Qualified accessor colliding with a type's accessor fails at both

**Given** `@Bean(named: "snakeCase") static func a() -> JSONDecoder` and `@Service final class SnakeCaseJSONDecoder`  
**When** the target builds  
**Then** the build fails at both declarations with an accessor-name collision on `snakeCaseJSONDecoder`

### Scenario: Invalid names

**Given** `@Bean(named: prefix)` (not a literal), `@Bean(named: "snake-case")` or `@Bean(named: "")`  
**When** the macro expands  
**Then** it fails at the `named:` argument  
**Given** `@Qualifier(name)`, `@Qualifier("2x")` or `@Qualifier` without a name on a selected initializer parameter  
**When** the target builds  
**Then** the build fails at that `@Qualifier` attribute

### Scenario: Misplaced `@Qualifier`

**Given** `@Qualifier("x")` on a stored property of a `@Service` type, or `@Assisted @Qualifier("x")` on one parameter  
**When** the target builds  
**Then** the build fails at each `@Qualifier` attribute

### Scenario: Manual construction is unaffected

**Given** `init(@Qualifier("snakeCase") decoder: JSONDecoder)`  
**When** the initializer is called directly with a `JSONDecoder`  
**Then** it compiles and the body receives that value

### Scenario: Graphs without qualifiers are byte-identical

**Given** a graph without `named:` or `@Qualifier` covering singletons, transients, `any` bindings, collections, nested types, keyword accessors, defaulted parameters, assisted providers and conditional imports  
**When** the target builds  
**Then** the generated file is byte-for-byte the same as before this feature

## Out of scope

- `accessor:` override for a qualified (or any) accessor name
- Non-literal names (constants, enums, `static let` qualifiers) and qualifier types (`@Qualifier(SnakeCase.self)`)
- Implicit single-candidate selection for unqualified parameters
- Qualifiers on `@ApplicationContext` itself or on injected collections (collection injection is its own spec)
- Numeric or hashed suffixes to resolve accessor collisions
- Generating qualified fakes for `{Context}Protocol`

## Phase gate

Phase 1 content agreed in the 2026-10-15 discussion (`memory/progress.md`); spec, contracts, tests and implementation produced together on branch `cursor/qualifiers-53df` per the task brief, for review on the PR.
