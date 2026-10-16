# Spec: Child Contexts

## Metadata

| Field | Value |
|-------|-------|
| Feature | `child-contexts` |
| Status | **Draft (Phase 1) — awaiting approval**, drafted 2026-10-15. No contracts, tests or code until approved |
| Extends | `specs/compile-time-di/SPEC.md` (resolves its "Subcontexts (candidate for v1.1)" and "Context arguments — deferred" out-of-scope items) |
| Swift tools | 6.4+ (matches `Package.swift`) |
| Affected targets (proposed) | `SwiftBeans` (macros, runtime), `SwiftBeansMacros`, `SwiftBeansGeneratorCore` (scanner / resolver / validator / codegen), `SwiftBeansSyntaxRules`; no new product |
| Priority doc order | This spec amends `compile-time-di` only where stated under "Changes to existing behavior"; everything else there stays in force |

## Goal

Let an app declare a **child context**: a second compile-time graph, created and destroyed at runtime, whose beans can depend on the beans of a **parent context** and on **values supplied when the child is created**. The canonical case is a logged-in-user scope:

- the app context lives for the whole process;
- a `UserSessionContext` is created at login with the `User`, holds user-scoped singletons (`FeedRepository`, `SyncEngine`), and is released at logout, taking all of its singletons with it;
- user-scoped beans freely use app-scoped beans (`URLSession`, `Analytics`), but app-scoped beans can never depend on user-scoped ones.

The result keeps the guarantees of v1: wiring is generated and validated at build time, there is no runtime service locator, and plain types stay manually constructible.

## Motivation

- **Per-session state without globals.** Today a logged-in-user object graph is either hand-wired next to the generated one, or stored in app-scoped singletons that must be manually reset at logout (stale data leaks between accounts).
- **Deterministic teardown.** Releasing the child context should release every user-scoped singleton, with no per-bean reset code.
- **Compile-time safety across lifetimes.** The classic bug "singleton captures a shorter-lived dependency" becomes a build error instead of a runtime surprise.
- **Prior art.** Spring's parent/child `ApplicationContext`, Needle's component hierarchy, and Dagger's subcomponents. We follow the Dagger/Needle model (compile-time, strict one-way visibility) with Spring's lookup rule (child sees parent, not vice versa).
- **Unblocks** "context arguments" (values handed to a context at creation), which a login-scoped context needs anyway.

## Terminology

| Term | Meaning |
|------|---------|
| Root context | The single `@ApplicationContext` of the target (unchanged) |
| Child context | A `class` annotated `@ChildContext(of: Parent.self)`; many allowed per target |
| Parent | The context named by `of:`; a root or (phase C) another child |
| Own provider | A `@Service` / `@Bean` assigned to a given context |
| Context input | A value passed to the child's initializer and injectable as a bean inside that child |
| Owner (of a bean) | The context whose registry stores its singleton |

Naming follows the existing surface: macro `@ChildContext` beside `@ApplicationContext`, and generated `{ContextTypeName}Protocol` for every context (`UserSessionContextProtocol`).

## Public API sketch

Illustrative only; exact signatures are fixed in Phase 2.

### Declaring a child context

```swift
@ChildContext(of: AppContext.self)
final class UserSessionContext {
	@ContextInput let user: User
}

// Generated (members added by the macro)
//   let _swiftBeansRegistry = SwiftBeansRegistry()
//   let _swiftBeansParent: any AppContextProtocol
//   init(parent: any AppContextProtocol, user: User)
```

- `parent` is typed as the parent's **protocol** (`any AppContextProtocol`), not the concrete class, so a child can be built over a hand-written `FakeAppContext` in tests and Previews.
- Each `@ContextInput` stored property becomes a labelled parameter of the generated initializer, in declaration order, after `parent`. Inputs are `let`, non-optional, with no default value. The macro owns the initializer; a hand-written initializer on a `@ChildContext` type is an error (see open questions).
- An input is a provider inside the child: `user: User` is injectable in the child's own beans under key `User` and appears as `var user: User { get }` on `UserSessionContextProtocol`.

### Assigning beans to a context

An optional `in:` argument on `@Service`, `@Bean` and `@Configuration` names the owning context. No `in:` means the root context, so every existing graph keeps its meaning.

```swift
@Service(in: UserSessionContext.self)
final class FeedRepository {
	init(api: APIClient, user: User) { … }   // APIClient: parent bean. User: context input.
}

@Service(in: UserSessionContext.self, boundTo: SyncEngine.self)
final class DefaultSyncEngine: SyncEngine { … }

@Configuration(in: UserSessionContext.self)   // default owner for the Beans below
enum UserSessionConfiguration {
	@Bean
	static func feedCache(user: User) -> FeedCache { … }

	@Bean(in: AppContext.self)               // per-bean override back to the root
	static func clock() -> Clock { … }
}
```

`in:` must be a type literal (`Name.self`, optionally module-qualified or nested) because the generator evaluates it from syntax.

### Generated code shape (child)

```swift
protocol UserSessionContextProtocol: AnyObject {
	var feedRepository: FeedRepository { get }
	var syncEngine: any SyncEngine { get }
	var user: User { get }
}

extension UserSessionContext {
	var feedRepository: FeedRepository {
		_swiftBeansRegistry.singleton(key: "feedRepository") {
			FeedRepository(api: self._swiftBeansParent.apiClient, user: self.user)
		}
	}
	// …
}

extension UserSessionContext: UserSessionContextProtocol {}
```

- The child protocol lists **only the child's own keys and inputs**. It does not re-export the parent's accessors and does not require a `parent` member (see open questions for the alternative).
- Parent keys are reached from child beans through `_swiftBeansParent`, which is the parent's protocol existential; a parent bean is therefore never duplicated and its singleton remains once-only in the parent's registry.

### Creating and destroying

```swift
final class SessionManager {
	private let app: any AppContextProtocol
	private(set) var session: UserSessionContext?

	func logIn(_ user: User) {
		session = UserSessionContext(parent: app, user: user)
	}

	func logOut() {
		session = nil              // user-scoped singletons are released with it
	}
}
```

The v1 of this feature has **no explicit `close()` / `dispose()`**: lifetime is ARC. Hooks are deferred (see Out of scope).

A convenience factory on the parent (`app.userSessionContext(user:)`) is a later phase.

## Behavioral rules

### Lifetime

1. A child context is an ordinary `final class` instance, created by its caller and owned by whoever retains it. There is no registration with the parent: the parent holds **no reference** to its children.
2. A child holds its parent **strongly** (`_swiftBeansParent`). A parent therefore outlives every child; a child can never observe a deallocated parent.
3. Each child instance has its own `SwiftBeansRegistry`. Two live children of the same type (e.g. two accounts) never share singletons, but share the parent's.
4. Singletons owned by a child live as long as that child instance (singleton-per-context, same as v1 semantics with "context" meaning the child).
5. Transient beans (`.transient`) are created on every access; assisted providers (`@Assisted`) behave exactly as in the parent graph (always transient, method accessors).
6. Singleton factories run at most once per child instance, with the same concurrency guarantees as the root (`SwiftBeansRegistry` contract is reused unchanged).

### Parent lookup (visibility)

1. A child's bean may depend on any key provided by the child (own providers and inputs) or by its parent. Keys visible to a child are the union of both.
2. A parent's bean may **not** depend on a child's keys. A `@Service` / `@Bean` owned by the root that needs a key only a child provides fails the build at that parameter, with a note explaining the narrower lifetime. Likewise (phase C) a bean may never depend on a key owned by a descendant.
3. Siblings are isolated: a bean owned by one child cannot depend on a key owned by another child.
4. A key resolved from the parent uses the parent's own scope: a parent singleton is the shared instance; a parent transient is created anew per access from the child as well.
5. Resolution never searches at runtime. The generator decides at build time whether each dependency is own, input, or parent, and emits `self.x` or `self._swiftBeansParent.x` accordingly.
6. Assisted providers owned by the parent are callable on the parent's protocol and remain not injectable (unchanged rule).

### Key ownership and conflicts

1. Within one context, a key is provided at most once (existing duplicate rule), counting own providers and inputs.
2. A child key that is also provided by an ancestor fails the build (duplicate across the chain). Shadowing / overriding a parent bean in a child is not supported in this feature (see open questions).
3. Two sibling children may provide the same key independently.
4. Accessor names follow the existing rules and are checked **per context** across own keys and inputs; two different keys that produce the same accessor name within one context fail the build.
5. Providers declared in local packages cannot be assigned to a child context in this feature: `in:` on a declaration in a `local_packages` target fails the build (child contexts live in the app target; a package cannot name them).

### Disposal

1. Disposal is deallocation. When the last reference to a child instance is released, its registry and every singleton it solely holds are released, per ARC.
2. A bean created by a child may outlive it if another object retains the bean (a view model captured by a view that is still on screen). The library does not invalidate such beans. Guidance: hold child beans from objects whose lifetime is bounded by the session.
3. A child bean must not capture the child context itself strongly; a child is not injectable as a bean in v1 of this feature (no key for it), which prevents the most common retain cycle by construction. Beans are free to hold parent beans.
4. Teardown order is unspecified. No `deinit`-time callbacks are generated.
5. Resolving a bean while the child is being deallocated is impossible by ARC (resolution requires a reference).

### Generation rules (builds on "Generator rules" of `compile-time-di`)

1. **Recognition.** `@ChildContext` is recognized unqualified or as `@SwiftBeans.ChildContext`; it applies to a top-level or nested `final class` only (non-final → error; reuse the `@ApplicationContext` kind rules). `@ContextInput` applies only to a stored `let` property of a type annotated `@ChildContext` (error elsewhere, reported by the macro where visible from one declaration).
2. **Parent resolution.** `of:` must be a type literal naming an `@ApplicationContext` or (phase C) `@ChildContext` type in the target's own sources. Unknown, non-context or cyclic parents fail the build at the `of:` argument.
3. **Unchanged: one root.** Exactly one `@ApplicationContext` per target is still required to have a graph; a `@ChildContext` whose root is absent fails the build. Any number of children is allowed.
4. **Contexts in local packages are ignored** (same as roots today), and so are providers whose `in:` names an ignored context. A provider with `in:` naming a type that is not any context fails the build.
5. **Per-context validation.** Missing dependency, cycle, duplicate, unsupported key and `@Assisted` rules are validated on each context's **merged graph** (own providers + ancestors' providers). A cycle is only possible within one context's own providers plus parent edges, which cannot point back, so cycle detection runs per context over own edges.
6. **Missing dependency diagnostics** name the context: "no provider for `Analytics` visible from `UserSessionContext` (checked: own, inputs, `AppContext`)".
7. **Narrowing diagnostic.** A root-owned provider depending on a key that exists only in a child gets a dedicated message instead of "missing dependency".
8. **Determinism.** Contexts are emitted in sorted order, parent before child; output remains a pure function of the scanned sources.
9. **Byte-identical output for graphs without children.** If no `@ChildContext` and no `in:` exists, the generated file is byte-for-byte what v1 produces.

## Changes to existing behavior

| Existing text (compile-time-di) | Change |
|---|---|
| Out of scope: "Subcontexts (candidate for v1.1)" and "Context arguments" | Removed from out of scope once this spec ships (inputs on children first; root inputs in phase 0) |
| "More than one root context in the target fails the build" | Unchanged for `@ApplicationContext`; `@ChildContext` types are not counted as roots |
| README "qualifiers and subcontexts are not supported in v1" | Update to "child contexts: see the child-contexts spec" in the implementation PR |
| `ARCHITECTURE` "Generated code shape" | Gains a per-context section (see `specs/child-contexts/ARCHITECTURE.md`) |

## Acceptance criteria (BDD)

### Scenario: Child bean uses a parent bean

**Given** `@Service final class APIClient` owned by the root  
**And** `@Service(in: UserSessionContext.self) final class FeedRepository { init(api: APIClient) }`  
**And** `@ChildContext(of: AppContext.self) final class UserSessionContext`  
**When** the target builds  
**Then** `UserSessionContext` exposes `feedRepository`  
**And** its `APIClient` is the same instance as `appContext.apiClient`

### Scenario: Child singletons are per child instance

**Given** a child-owned singleton `FeedRepository`  
**When** two `UserSessionContext` instances are created over the same parent  
**Then** each returns the same `FeedRepository` on repeated access  
**And** the two children return different `FeedRepository` instances

### Scenario: Parent singletons are shared between children

**Given** a root singleton `APIClient` used by a child bean  
**When** two children over the same parent each resolve a bean that depends on `APIClient`  
**Then** both beans hold the identical `APIClient` instance

### Scenario: Parent transient is recreated for child access

**Given** a root `@Service(scope: .transient) Validator`  
**And** a child-owned transient `Report` that depends on `Validator`  
**When** the child creates two `Report` instances  
**Then** their `Validator` instances are not identical

### Scenario: Context input is injectable inside the child

**Given** `@ChildContext(of: AppContext.self) final class UserSessionContext { @ContextInput let user: User }`  
**And** a child-owned `@Service` whose initializer takes `user: User`  
**When** `UserSessionContext(parent: app, user: alice)` is created  
**Then** the service receives `alice`  
**And** `UserSessionContextProtocol` exposes `var user: User { get }`

### Scenario: Context input replaces the need for a provider

**Given** a child bean requires `User` and `User` is only a `@ContextInput`  
**When** the target builds  
**Then** the build succeeds without any `@Bean` for `User`

### Scenario: Child created over a fake parent

**Given** a hand-written `FakeAppContext: AppContextProtocol`  
**When** `UserSessionContext(parent: FakeAppContext(), user: alice)` is created  
**Then** child beans receive parent dependencies from the fake  
**And** no concrete `AppContext` is needed

### Scenario: Parent bean cannot depend on a child key

**Given** a root-owned `@Service final class Analytics { init(feed: FeedRepository) }`  
**And** `FeedRepository` is owned only by `UserSessionContext`  
**When** the target builds  
**Then** the build fails at the `feed` parameter  
**And** the message says the key is provided only by `UserSessionContext`, a shorter-lived context

### Scenario: Siblings cannot see each other

**Given** child contexts `UserSessionContext` and `GuestSessionContext`, each over `AppContext`  
**And** a `GuestSessionContext` bean that depends on `FeedRepository` owned by `UserSessionContext`  
**When** the target builds  
**Then** the build fails at that parameter naming `UserSessionContext`

### Scenario: Siblings may provide the same key

**Given** `UserSessionContext` and `GuestSessionContext` each own a `SyncEngine`  
**When** the target builds  
**Then** the build succeeds and each child exposes its own `SyncEngine`

### Scenario: Child key duplicating a parent key fails

**Given** the root provides `Clock` and `UserSessionContext` also provides `Clock`  
**When** the target builds  
**Then** the build fails with a duplicate-provider error at both declarations, naming both contexts

### Scenario: Missing dependency in a child names the context

**Given** a child bean depending on `Analytics`  
**And** no provider for `Analytics` in the child or the root  
**When** the target builds  
**Then** the build fails at the parameter and names `UserSessionContext` and the checked contexts

### Scenario: Cycle inside a child fails

**Given** child-owned `A` depends on `B` and `B` depends on `A`  
**When** the target builds  
**Then** the build fails with a cycle diagnostic that names the child context

### Scenario: Unknown or invalid parent fails

**Given** `@ChildContext(of: NotAContext.self) final class Broken`  
**When** the target builds  
**Then** the build fails at the `of:` argument

### Scenario: `in:` naming a non-context fails

**Given** `@Service(in: String.self) final class Foo`  
**When** the target builds  
**Then** the build fails at the `in:` argument

### Scenario: Child without a root fails

**Given** a target with a `@ChildContext` and no `@ApplicationContext`  
**When** the target builds  
**Then** the build fails at the child declaration

### Scenario: Releasing the child releases its singletons

**Given** a child-owned singleton held only by the child's registry  
**When** the last strong reference to the child is released  
**Then** the singleton deinitializes  
**And** the parent and its singletons are unaffected

### Scenario: Child keeps its parent alive

**Given** a child created over a parent that the test then releases  
**When** the child still exists  
**Then** the parent is not deallocated and parent beans still resolve

### Scenario: Assisted provider owned by a child

**Given** a child-owned `@Service` with an `@Assisted` parameter  
**When** the target builds  
**Then** the child and `{Child}Protocol` expose a method accessor with the assisted parameters  
**And** each call returns a new instance with graph parameters taken from own or parent keys

### Scenario: Per-bean `in:` overrides configuration default

**Given** `@Configuration(in: UserSessionContext.self)` with one `@Bean(in: AppContext.self)`  
**When** the target builds  
**Then** that bean is exposed by `AppContext` and the others by `UserSessionContext`

### Scenario: Child singleton factory runs once under concurrent access

**Given** a child-owned singleton whose factory counts invocations  
**When** many threads resolve it for the first time at once  
**Then** every caller gets the same instance and the factory ran exactly once

### Scenario: Graphs without child contexts are unchanged

**Given** an existing target with no `@ChildContext` and no `in:` argument  
**When** the generator runs  
**Then** the generated file is byte-identical to the output before this feature

### Scenario: Local-package provider cannot target a child

**Given** a `@Service(in: UserSessionContext.self)` in a `local_packages` target  
**When** the target builds  
**Then** the build fails at the declaration explaining that child-owned providers must live in the app target

### Scenario: Plain types remain manually constructible

**Given** a child-owned `@Service` type `FeedRepository`  
**When** a unit test constructs it directly with fakes  
**Then** it compiles and runs without any context

## Out of scope

- Explicit lifecycle hooks (`@PostConstruct`, `@PreDestroy`, `Disposable`, async `close()`); teardown is ARC only
- Overriding or shadowing a parent bean in a child (the "child replaces `Clock` in tests" use case)
- Child contexts declared in local packages or in a different target than the root
- Injecting a child context or a context factory into beans (needs factory injection; see `memory/progress.md` backlog), including a parent-generated `makeUserSessionContext(user:)`
- Runtime registration, lookup by name, or a runtime tree of contexts; no enumeration of live children
- Beans that observe parent or child lifecycle events; no weak parent references
- SwiftUI `@Environment` bridges for child contexts
- Qualifiers, collection injection, and other items of the "Possible future improvements" list
- Auto-generated fake / mock contexts (apps keep hand-writing fakes against `{Context}Protocol`)
- Generics on contexts; `actor`-typed contexts (classes only, as for the root)

## Open questions

1. **Ownership syntax.** `in: Context.self` on each declaration (proposed) vs. ownership by file/target/folder vs. a dedicated `@ChildService` stereotype. `in:` is explicit and greppable, but repetitive; a `@Configuration(in:)` default helps for beans, not for `@Service`.
2. **Child protocol shape.** Own-keys-only (proposed; small fakes) vs. refining the parent protocol (`protocol UserSessionContextProtocol: AppContextProtocol`, single object to pass around, but every fake must implement the parent's whole surface).
3. **Inputs mechanism.** `@ContextInput let` stored properties (proposed) vs. `@Assisted` on a user-written initializer vs. a macro argument (`@ChildContext(of:, inputs: User.self)`). Should the same mechanism later apply to the root (phase 0)?
4. **Hand-written initializers.** Forbid (proposed) vs. allow with `@Inject`-style marking so apps can add extra state.
5. **Shadowing.** Keep duplicate-across-chain an error (proposed) or support explicit overrides (`@Service(in:, overrides: true)`)? Tests might want it, but fakes of `AppContextProtocol` already cover that need.
6. **Actor isolation.** If the parent is `@MainActor`, is `any AppContextProtocol` accessed from a nonisolated child bean legal? Needs a decision on generated isolation annotations and `Sendable`, tied to the existing "context isolation" decision.
7. **Parent access for consumers.** Should consumers be able to reach the parent from the child (`child.parent`)? Not proposed: it would blur the layering.
8. **Depth.** One level first (phase A) vs. an arbitrary tree. The design is tree-shaped, but diagnostics and ownership resolution get harder with depth.
9. **Hierarchy declaration.** `@ChildContext(of: Parent.self)` (proposed, child knows parent) vs. the parent listing its children, which would create a reverse dependency from root to child types.
10. **Retention footguns.** Would a debug-only leak check ("child released but a bean still alive") be worth a later spec?
11. **Interaction with inter-bean calls and factory injection** (other backlog items): does a `@Bean` body calling another bean cross contexts? Resolve when those specs are written.
12. **Local packages.** Allow a package to declare child-owned providers by naming a context protocol/type it owns? Rejected for now.

## Phased delivery proposal

Each phase is independently shippable and each needs its own Phase 2 approval.

| Phase | Ships | Why this order |
|-------|-------|----------------|
| **0 — Context inputs on the root** (optional prerequisite) | `@ContextInput` on `@ApplicationContext`, generated `init`, input as a provider and protocol member | Smallest useful slice; exercises the generated-init and input-as-provider machinery without any graph partitioning; closes the "Context arguments" deferral |
| **A — Single-level child contexts (MVP)** | `@ChildContext(of:)`, `in:` on `@Service` / `@Bean` / `@Configuration`, own-keys-only child protocol, parent delegation through `any ParentProtocol`, narrowing / sibling / duplicate diagnostics, ARC disposal | Delivers the logged-in-user scope end to end; manual creation (`UserSessionContext(parent:user:)`) |
| **B — Convenience and ergonomics** | Parent-side factory (`app.userSessionContext(user:)` returning `any UserSessionContextProtocol`), example app login/logout scene, optional protocol refinement | Needs a decision on open questions 2 and 9; the factory overlaps with factory injection |
| **C — Nested children** | Child of child, chain duplicate checks, descendant narrowing | Pure generalization of A once the single-level shape is proven |
| **D — Lifecycle and overrides** | `@PreDestroy`-style hooks, explicit `close()`, shadowing, graph dump per context | Has the most open design and depends on separate specs (graph dump, factory injection) |

## Fallback policy

If per-context partitioning cannot be generated with acceptable DX, record the failure in `memory/decisions.md` and open a new spec; do not ship a hybrid that uses a runtime context lookup.

## Resolved decisions (for this draft)

| Topic | Decision |
|-------|----------|
| Macro name | `@ChildContext(of:)` beside `@ApplicationContext`; generated `{Context}Protocol` for every context |
| Parent visibility | Child sees parent, never the reverse; siblings isolated; checked at build time |
| Parent type in the child | The parent's `{Context}Protocol` existential, so fakes work |
| Lifetime | ARC: child strongly holds parent; parent holds no children; no explicit dispose in phase A |
| Registry | One `SwiftBeansRegistry` per context instance; contract unchanged |
| Baseline | No-child graphs generate byte-identical output |
