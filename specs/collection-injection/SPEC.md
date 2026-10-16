# Spec: Collection Injection (multi-bind)

## Metadata

| Field | Value |
|-------|-------|
| Feature | `collection-injection` |
| Status | Draft — implemented on branch `cursor/collection-injection-53df`, pending human approval (Phase 1–2 gates were not held separately) |
| Builds on | `specs/compile-time-di/SPEC.md` (Generator rules: keys, providers, assisted providers, diagnostics) |
| Touches | `SwiftBeansGeneratorCore` only (scanner, resolver, validator, codegen). No runtime, macro or plugin change |
| Swift tools | 6.4+ |

## Goal

Let a bean receive **every** bean of a kind, the way Spring injects `List<Interceptor>`:

```swift
protocol AnalyticsTracker { func track(_ event: String) }

@Service final class ConsoleTracker: AnalyticsTracker { init() {} }
@Service final class FirebaseTracker: AnalyticsTracker { init() {} }

@Service
final class Analytics {
	init(trackers: [any AnalyticsTracker]) { … }
}

// Generated
extension AppContext {
	var analytics: Analytics {
		_swiftBeansRegistry.singleton(key: "analytics") {
			Analytics(trackers: [self.consoleTracker, self.firebaseTracker])
		}
	}
}
```

Typical uses: analytics trackers, HTTP interceptors, plugins, launch tasks.

## Why conformance and not only the key

Each key has exactly one provider (two providers for one key fail the build with `graph.duplicateProvider`, and both would produce the same accessor). So "every bean whose key is `P`" is at most one bean. To collect several, a bean also joins `[P]` when its type **declares** conformance to `P` in a scanned declaration. Every member keeps its own key and accessor; no new accessors, no change to the duplicate rule, and no qualifiers are needed.

## Public API surface

None. Collection injection is a generator rule: an initializer or `@Bean` parameter typed `[E]` / `Array<E>` (optionally `[any E]`).

## Terms

- **Collection parameter:** a non-`@Assisted` parameter whose key is `[E]` (`[E]`, `Array<E>`, `[any E]`, `Array<any E>`; parentheses and whitespace ignored as for any key).
- **Array bean:** a provider whose key is `[E]` itself, e.g. `@Bean static func tags() -> [String]`. This is today's single-provider value bean.
- **Element members of `E`:** the providers that can go into a `[E]` literal (see Rules → Members).
- **Multi-bind:** supplying a collection parameter with an array literal of member accessors.

## Rules

### When a collection parameter multi-binds

For a collection parameter with key `[E]`, in this order:

1. **An array bean wins.** If any provider's key is `[E]`, the parameter is wired to it exactly as today (`self.stringArray`). Element members are ignored for that parameter. (An assisted array bean keeps today's `assisted.notInjectable` error.)
2. **Otherwise, members multi-bind.** If `E` has at least one member, the parameter receives `[self.<member1>, self.<member2>, …]`.
3. **Otherwise, `any` gives an empty list.** If the element is spelled with `any` (`[any E]`, `Array<any E>`), the parameter receives `[]`. `any` is how the consumer says "zero or more implementations of this protocol".
4. **Otherwise, the dependency is missing.** `[E]` without `any`, with no array bean and no members (e.g. `[String]` with no `[String]` bean), fails the build with `graph.missingDependency` as today. An empty list is never invented for a plain value type.

### Members

A provider is a member of `E` when **all** of these hold:

1. **It matches `E`**, either:
	- its key is `E` (e.g. `@Service(boundTo: AnalyticsTracker.self)`, `@Bean static func x() -> any AnalyticsTracker`, or `@Service final class E`), or
	- its key names a scanned type (class, struct, actor, enum or protocol, matched by qualified name) that declares `E` in its inheritance clause, in its own declaration or in an extension in any scanned file, directly or through other scanned declarations (`final class Sub: Base`, `class Base: E`; `protocol Special: E`). Inheritance-clause entries are normalized and matched by spelling, like every key.
2. **It is not assisted.** An assisted provider needs runtime arguments, so it is never a member.
3. **It is not the consumer.** A provider's own collection parameter never includes that provider (composite pattern: `@Service(boundTo: AnalyticsTracker.self) final class AllTrackers { init(trackers: [any AnalyticsTracker]) }` gets the others, not itself).

### Order and output

1. Members are listed in ascending **accessor name** order (`consoleTracker` before `firebaseTracker`), never in file or declaration order.
2. Each element is the member's existing accessor, `self.<accessorName>`, typed as that accessor already is (`ConsoleTracker`, `any AnalyticsTracker`); Swift upcasts them in the array literal.
3. Members keep their own scope: a singleton member is the same instance in every list and in its own accessor; a transient member is created per list.
4. `{Context}Protocol` is unchanged. There is no aggregate accessor such as `analyticsTrackerArray`; lists are built only at call sites.

### Defaulted collection parameters

A defaulted collection parameter (`interceptors: [any Interceptor] = []`) follows the defaulted-parameter rule: it is injected when the graph can supply it — an array bean or at least one member — and otherwise keeps its default (it does not receive the `any` empty list, and is never missing).

### Graph checks

1. A multi-bound parameter depends on every member: cycle detection follows those edges (e.g. a member that injects the consumer is a `graph.cycle`).
2. Missing-dependency, duplicate-key and accessor-collision checks are otherwise unchanged.

### Compatibility

Output is byte-identical to the previous generator for every graph that builds today, **except** a defaulted collection parameter with no array bean and at least one member: before, it kept its default; now it receives the members. Graphs where a non-defaulted `[E]` had no array bean failed to build before, so they gain new behavior without changing existing output.

## Acceptance criteria (BDD)

### Scenario: Conformers are collected in accessor-name order

**Given** `protocol AnalyticsTracker`, `@Service final class FirebaseTracker: AnalyticsTracker` and `@Service final class ConsoleTracker: AnalyticsTracker`  
**And** `@Service final class Analytics { init(trackers: [any AnalyticsTracker]) }`  
**When** the target builds  
**Then** `Analytics` is constructed with `trackers: [self.consoleTracker, self.firebaseTracker]`  
**And** `{Context}Protocol` gains no collection accessor

### Scenario: Protocol-bound and concrete members are mixed

**Given** `@Service(boundTo: AnalyticsTracker.self) final class RemoteTracker` (key `AnalyticsTracker`), `@Service final class ConsoleTracker: AnalyticsTracker`, and `@Bean static func fileTracker() -> FileTracker` where `struct FileTracker: AnalyticsTracker` is declared in a scanned file  
**And** a consumer `init(trackers: [AnalyticsTracker])`  
**When** the target builds  
**Then** it receives `[self.analyticsTracker, self.consoleTracker, self.fileTracker]`

### Scenario: Conformance declared in an extension or inherited

**Given** `@Service final class A` with `extension A: AnalyticsTracker {}` in another file, and `@Service final class C: Base` where `class Base: AnalyticsTracker`  
**When** a consumer injects `[any AnalyticsTracker]`  
**Then** both `a` and `c` are in the list

### Scenario: Empty `any` collection

**Given** no provider matches `AnalyticsTracker`  
**And** `@Service final class Analytics { init(trackers: [any AnalyticsTracker]) }`  
**When** the target builds  
**Then** `Analytics` is constructed with `trackers: []`

### Scenario: Plain collection without providers is still missing

**Given** no `[String]` bean and no `String` provider  
**And** `@Service final class TagList { init(tags: [String]) }`  
**When** the target builds  
**Then** the build fails with `graph.missingDependency` for `[String]` at `tags`

### Scenario: An explicit array bean wins over members

**Given** `@Bean static func trackers() -> [any AnalyticsTracker]` and `@Service final class ConsoleTracker: AnalyticsTracker`  
**And** a consumer `init(trackers: [any AnalyticsTracker])`  
**When** the target builds  
**Then** it receives `self.analyticsTrackerArray`, not a literal

### Scenario: Value bean of collection type is unchanged

**Given** `@Bean static func tags() -> [String]` and a consumer `init(tags: [String])`  
**When** the target builds  
**Then** it receives `self.stringArray`

### Scenario: Assisted providers are excluded

**Given** `@Service final class ConsoleTracker: AnalyticsTracker { init() }` and `@Service final class SessionTracker: AnalyticsTracker { init(@Assisted session: Session) }`  
**When** a consumer injects `[any AnalyticsTracker]`  
**Then** it receives `[self.consoleTracker]`

### Scenario: The consumer is not its own member

**Given** `@Service(boundTo: AnalyticsTracker.self) final class AllTrackers { init(trackers: [any AnalyticsTracker]) }` and `@Service final class ConsoleTracker: AnalyticsTracker`  
**When** the target builds  
**Then** `AllTrackers` receives `[self.consoleTracker]` and the build has no cycle

### Scenario: Defaulted collection parameter

**Given** `@Service final class Client { init(interceptors: [any Interceptor] = []) }`  
**When** no provider matches `Interceptor`  
**Then** `Client()` keeps its default  
**When** `@Service final class AuthInterceptor: Interceptor` exists  
**Then** `Client(interceptors: [self.authInterceptor])`

### Scenario: Cycles through a collection fail the build

**Given** `@Service final class Analytics { init(trackers: [any AnalyticsTracker]) }` and `@Service final class LoopTracker: AnalyticsTracker { init(analytics: Analytics) }`  
**When** the target builds  
**Then** the build fails with `graph.cycle` naming both

### Scenario: Graphs without collection parameters are unchanged

**Given** a graph with no collection parameters (or only collection parameters wired to array beans)  
**When** the target builds  
**Then** the generated file is byte-identical to the previous generator's

## Out of scope

- Dictionaries / sets of beans (`[String: any P]`, `Set<…>`), and ordering hints (`@Order`, priorities)
- Variadic parameters (`P...`) as collections
- Conformance not written in a scanned inheritance clause: conformances in unscanned modules, conditional conformances (`extension Box: P where …`), retroactive conformance of unscanned types, and protocol-extension or generic-constraint reasoning
- Matching conformance across typealiases or different qualifications (`Module.P` vs `P`), consistent with key matching
- An aggregate accessor on the context or `{Context}Protocol`
- Collections of assisted factories (see factory injection backlog)
- Changing `graph.duplicateProvider`: two providers for the same key still fail, even if only consumed through a collection

## Resolved decisions

| Topic | Decision |
|-------|----------|
| Membership | Key equality **or** declared conformance in scanned inheritance clauses (transitive over scanned declarations), because keys are unique |
| Array bean vs members | Array bean wins |
| Empty list | Only for `any`-spelled elements; plain `[E]` stays a missing dependency |
| Assisted | Never members |
| Self | A consumer is never its own member (composite pattern) |
| Order | Ascending accessor name |
| Defaulted collection | Injected when an array bean or a member exists; otherwise default |
