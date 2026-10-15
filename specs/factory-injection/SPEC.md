# Spec: Factory Injection

## Metadata

| Field | Value |
|-------|-------|
| Feature | `factory-injection` |
| Status | Draft (Phase 1) — 2026-10-15; written together with its implementation on branch `cursor/factory-injection-53df`, pending review |
| Amends | `specs/compile-time-di/SPEC.md` (Out of scope: injecting assisted factories; lazy cycle breaking) |
| Public API | None. Generator behavior only (no new macros, no runtime types) |

## Goal

Let a bean receive a **function** instead of a value, so it can create objects later or repeatedly without holding the whole context:

- **Assisted factory** `(Item) -> ItemDetailViewModel`: calls the assisted provider's method accessor.
- **Deferred factory** `() -> ExpensiveService`: calls the property accessor on each invocation (lazy; breaks cycles).

## Behavior

### Where function types are allowed

1. A function type is accepted **only as a dependency parameter** of the selected `@Service` initializer or `@Bean` method. Function types stay unsupported as provider keys (`@Service(boundTo:)`, `@Bean` return types) and in generic arguments of keys.
2. The parameter type may be wrapped in parentheses and may carry `@escaping`, `@Sendable`, or other attributes; those do not affect matching. Function-type labels are erased by Swift and ignored. `async` / `throws` in the function type are allowed (the generated synchronous, non-throwing closure converts to it).
3. A function type with an `inout` or variadic parameter, or whose return type is not a supported key (optional, tuple/`Void`, function, `some P`, …), fails the build at the parameter with `factory.unsupported`, unless the parameter has a default value (then it keeps its default).
4. A function type spelled optional (`((Item) -> VM)?`) is not a factory; it is an unsupported key (as today).

### Matching

The function type `(P1, …, Pn) -> R` is matched against the provider whose key is `R` (after `any` removal, as for any key):

| Provider for `R` | `n` | Result |
|------------------|-----|--------|
| none | any | `graph.missingDependency` at the parameter for key `R` (with did-you-mean hints), as for a plain dependency |
| non-assisted | `0` | **Deferred factory** → `{ self.<accessor> }` |
| assisted, assisted parameters `A1…An` | `n` | **Assisted factory** when each `Pi` equals `Ai`'s type (see below) → `{ self.<accessor>(<label>: $0, …) }` |
| non-assisted | `> 0` | `factory.unresolved`: `R` takes no runtime arguments |
| assisted | `0`, or `n` differs, or a type differs | `factory.unresolved`: names the expected signature, e.g. `(Item) -> ItemDetailViewModel` |

Rules:

1. **Type equality** compares normalized spellings of `Pi` and the assisted parameter's declared type: key normalization when the type is a valid key (whitespace, parentheses, `any`, `Array<T>`/`[T]` sugar do not matter), otherwise the whitespace-free spelling with `@escaping` removed (so `Item?` matches `Item?`, and `@escaping () -> Void` matches `() -> Void`). Typealiases and module-qualified spellings are matched by spelling, as for keys.
2. **Order** is positional, in the assisted parameters' declaration order. Labels are never used to match.
3. **Generated closure** passes `$0`, `$1`, … positionally to the method accessor with the assisted parameters' external labels: `{ self.search($0, page: $1) }`. A deferred factory is `{ self.t }`.
4. **Each call is a fresh resolution**: a deferred factory returns the singleton again (same instance) or a new transient instance, exactly like reading the accessor; an assisted factory creates a new instance per call.
5. **Defaulted parameters.** A factory parameter with a default value is wired when its function type matches; if it does not match (or `R` has no provider) it keeps its default and produces no error.
6. **Context lifetime.** The generated closure captures the context strongly. A singleton that stores a factory therefore keeps the context alive; hold factories in transient beans (e.g. a coordinator) or accept the context's app lifetime.

### Graph rules

1. **Factories are lazy: they add no cycle edge.** Neither kind of factory parameter takes part in cycle detection, so `A` may take `() -> B` while `B` takes `A`. The factory's target provider is still required to exist (missing-dependency and mismatch checks apply).
2. **Assisted providers stay non-injectable as plain values** (`assisted.notInjectable` is unchanged for a plain `ItemDetailViewModel` parameter); only a matching function type reaches them.
3. **Duplicates.** Two providers for the same key already fail with `graph.duplicateProvider`; no additional ambiguity error exists for factories.
4. **Unchanged output.** A graph without function-typed dependency parameters generates byte-identical output to before this feature.

### Out of scope

- Function types as provider keys / `@Bean` return types (`() -> T` provided by the graph).
- Factories that return optionals, tuples, `Void`, or collections of factories.
- Optional factory parameters without a default (`((Item) -> VM)?`).
- Factories with arguments that are not `@Assisted` on the target (no partial application; arguments always map 1:1 to the target's assisted parameters).
- Weak/unowned context capture in generated closures.
- Factory injection into generated `{Context}Protocol` (the context already exposes the underlying accessors).

## Diagnostics

| Id | When |
|----|------|
| `factory.unsupported` | Function type with `inout`/variadic parameter or an unsupported return key, and no default |
| `factory.unresolved` | Return key is provided but arity/types do not match the provider (or it needs/does not need runtime arguments), and no default |
| `graph.missingDependency` | Return key has no provider |

## Acceptance (BDD)

### Scenario: Assisted factory is injected

**Given** assisted `ItemDetailViewModel` (`init(repository: ItemRepository, @Assisted item: Item)`) and `@Service final class Coordinator { init(makeDetail: @escaping (Item) -> ItemDetailViewModel) }`  
**When** the target builds  
**Then** `coordinator` is `Coordinator(makeDetail: { self.itemDetailViewModel(item: $0) })`

### Scenario: Deferred factory is injected

**Given** `@Service final class Heavy` and `@Service final class Screen { init(makeHeavy: () -> Heavy) }`  
**When** the target builds  
**Then** `screen` is `Screen(makeHeavy: { self.heavy })`

### Scenario: Deferred factory breaks a cycle

**Given** `A` taking `b: () -> B` and `B` taking `a: A`  
**When** the target builds  
**Then** there is no `graph.cycle` error  
**And** `A` receives `{ self.b }` and `B` receives `self.a`

### Scenario: Assisted factory breaks a cycle

**Given** assisted `Detail` taking `@Assisted item: Item` and `parent: Coordinator`, and `Coordinator` taking `makeDetail: (Item) -> Detail`  
**When** the target builds  
**Then** there is no `graph.cycle` error

### Scenario: Labels, positions and several arguments

**Given** assisted `Search` with `@Assisted _ query: String, api: API, @Assisted page pageIndex: Int` and a bean taking `(String, Int) -> Search`  
**When** the target builds  
**Then** the closure is `{ self.search($0, page: $1) }`

### Scenario: Function-type labels, attributes and parentheses do not matter

**Given** a parameter typed `@escaping (_ item: Item) -> ItemDetailViewModel` (or `((Item) -> ItemDetailViewModel)`)  
**When** the target builds  
**Then** it is wired as an assisted factory

### Scenario: Mismatched assisted factory fails

**Given** assisted `ItemDetailViewModel` taking `@Assisted item: Item` and a parameter `(String) -> ItemDetailViewModel`, `(Item, Int) -> ItemDetailViewModel` or `() -> ItemDetailViewModel`  
**Then** the build fails with `factory.unresolved` at the parameter, naming `(Item) -> ItemDetailViewModel`

### Scenario: Arguments given to a non-assisted target fail

**Given** non-assisted `Heavy` and a parameter `(Int) -> Heavy`  
**Then** the build fails with `factory.unresolved` at the parameter

### Scenario: Unknown factory target fails

**Given** a parameter `() -> Missing` with no provider for `Missing`  
**Then** the build fails with `graph.missingDependency` at the parameter

### Scenario: Plain injection of an assisted provider still fails

**Given** assisted `ItemDetailViewModel` and a parameter `detail: ItemDetailViewModel`  
**Then** the build fails with `assisted.notInjectable`

### Scenario: Unsupported function shapes fail

**Given** a parameter `(inout Item) -> VM`, `() -> Void` or `() -> Int?` without a default  
**Then** the build fails with `factory.unsupported` at the parameter  
**And** with a default value the parameter keeps its default and the build succeeds

### Scenario: Function types stay unsupported as provider keys

**Given** `@Bean static func make() -> () -> Heavy`  
**Then** the build fails with `key.unsupported` (unchanged)

### Scenario: Graphs without factories are unchanged

**Given** any graph without function-typed dependency parameters  
**Then** the generated file is byte-identical to the output before this feature
