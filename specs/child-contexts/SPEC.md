# Spec: Child Contexts

## Metadata

| Field | Value |
|-------|-------|
| Feature | `child-contexts`: compile-time login-scoped dependency graphs and optional managed cleanup |
| Status | **Approved (Phase 1)** in chat 2026-10-25; revised 2026-10-25 |
| System design | [design/child-contexts/DESIGN.md](../../design/child-contexts/DESIGN.md) |
| Design approved | 2026-10-25 (chat: “approved”) |
| Design decisions approved | 2026-10-25 (design approval plus “cool” confirming the proposed resource budget) |
| Spec approved | 2026-10-25 (chat: “i like it, i also like the managed teardown option. spec approved”) |
| Related | `compile-time-di`, `factory-injection`, `qualifiers`, `collection-injection`, `graph-dump`, `inter-bean-call-diagnostic` |
| Swift / platforms | Swift tools 6.4+; existing `Package.swift` platform minimums |
| Affected modules | `SwiftBeans`, `SwiftBeansMacros`, `SwiftBeansSyntaxRules`, `SwiftBeansGeneratorCore`; CLI/plugin integration and example coverage; no new product |
| Architecture | [ARCHITECTURE.md](ARCHITECTURE.md) contains the approved Phase 2 contracts replacing the historical sketch (2026-10-25) |

## Design decisions

### Success criteria

Deliver both A1 (single-level child graphs) and A2 (managed cleanup and the login example). Each child instance owns its singleton identities and runtime inputs; children share parent-owned instances and cannot leak visibility to parents or siblings. A root flow owner and transient child coordinator preserve the example's factory injection, `build(_:)` and view-owned `@State` models.

Managed close must invoke each participating singleton's cleanup once, await completion, and prevent subsequent generated resolution. The example must demonstrate a fresh navigation identity and user repository on the next login, stable app-repository identity across logins, and eventual release of solely session-owned objects once outgoing UI/tasks release their references. A1 alone does not complete this feature.

### Failure handling

Invalid declarations, graph relationships and supported-isolation violations produce positioned build diagnostics. Failed generation publishes no new Swift or graph-dump output; existing artifacts remain untouched. Missing/duplicate/cyclic dependencies retain existing diagnostic semantics with context ownership added.

Managed resolution after close begins fails a documented precondition naming the context. Close is async, nonthrowing and idempotent; repeated callers await shared completion. Cleanup implementations handle recoverable failures themselves. A suspended callback keeps close pending; no automatic timeout, cancellation of shared cleanup, or async deinit fallback is promised. Service behavior after cleanup is the service's responsibility.

### Performance and resource budget

Preserve byte-identical Swift and graph-dump output for existing root-only targets with no new ownership declarations. Parse each discovered source once per generator invocation; do not perform an additional whole-source scan for every child. Visibility analysis and generated output may scale with each context's own providers and visible parent dependencies; duplication of the parent's generated accessors into each child is unnecessary and prohibited.

Per-context singleton/lifecycle bookkeeping is proportional to instantiated child singletons; cleanup visits enrolled objects once, with identity deduplication. Generated resolution remains direct and does not search a runtime context hierarchy. There is no initial absolute millisecond or graph-size cap because there is no agreed benchmark baseline. Callback latency is application-controlled and excluded from a fixed close-time budget. Architecture/tests must record structural checks and representative multi-context comparisons without timing-sensitive pass thresholds.

### Trust boundary

Source declarations, local-package discovery and existing configuration enter through the current plugin/scanner boundary. Ownership and parent relationships are validated from syntax and the scanned graph; Swift type checking validates emitted source. No new remote input, runtime registration, context locator, or live hierarchy registry is introduced. Lifecycle enrollment observes instantiated objects for cleanup participation; it does not perform dependency lookup. Existing path/output validation continues to apply.

### Compatibility and rollout

Keep Swift 6.4+ and current platforms. Omitted `in:` assigns providers to the root; omitted `teardown:` selects `.arc`. Existing root-only sources, factory matching, qualifier keys, collection precedence and registry concurrency guarantees retain their behavior and generated output. Child adoption is opt-in. Managed children initially require explicit `@MainActor`; broader managed isolation support is deferred.

Deliver A1 then A2 under this spec and the subsequent approved architecture. Root context inputs, generated child factories, nested children and overrides remain separate work. Removing child declarations and moving ownership back to root restores root-only generation; applications migrating back must also restore their own login wiring.

## Goal and terminology

A child context is a second compile-time graph created at runtime with a parent and inputs. A logged-in flow owns one child, its transient coordinator, session repositories and work. The app context and its repositories live across logins. Children can use parent beans; the parent and sibling children cannot use child beans.

- **Root:** the target's one `@ApplicationContext`.
- **Child:** a top-level or nested, nongeneric `final class` annotated `@ChildContext(of: Root.self)` in the same target. A nested Swift type is allowed; a child-of-child relationship is deferred.
- **Own provider:** a service, bean or context input assigned to this context.
- **Owner:** the context responsible for resolution/caching of a provider.
- **Participating object:** an instantiated child singleton conforming to `ContextCleanup` in managed mode.

## Public API and contracts

The following declarations specify the client-facing behavior. Exact macro declarations, runtime helper signatures, access levels for generated members and module contracts are Phase 2 deliverables.

### Context declaration and inputs

```swift
@ChildContext(of: AppContext.self)
final class UserSessionContext {
	@ContextInput let user: User
}

// Generated initializer:
// init(parent: any AppContextProtocol, user: User)
```

`@ChildContext` is recognized unqualified or through `SwiftBeans`. `of:` must be a type literal naming the root context in the current target. Exactly one root is required when any child exists. Multiple sibling child types and instances are allowed; context declarations in scanned local packages do not become app contexts.

The child stores its parent strongly as `any {Parent}Protocol`, enabling fake parents. The parent holds no child references. The macro owns the child initializer; user-written initializers are errors.

An input must be a single named, instance, stored `let` with an explicit supported nonoptional type and no default or accessor body. Reject mutable, static, computed, destructured or multi-binding inputs and inputs outside children. The generated initializer accepts inputs in declaration order after `parent:`. An input named `parent`, a generated-member collision, or a duplicate key is an error.

Each input provides its unqualified type key. Its declared property name is the accessor used by generated dependencies and the protocol, even when it differs from the type-derived name (`currentUser: User` exposes `currentUser`). Inputs require no separate provider and remain readable after close. Inputs are retained as stored properties until child deallocation and are never automatically enrolled for cleanup.

### Provider ownership

```swift
@Service(in: UserSessionContext.self)
final class FeedRepository {
	init(api: APIClient, user: User) { /* ... */ }
}

@Configuration(in: UserSessionContext.self)
enum SessionConfiguration {
	@Bean
	static func cache(user: User) -> FeedCache { /* ... */ }

	@Bean(in: AppContext.self)
	static func clock() -> Clock { /* ... */ }
}
```

`in:` on `@Service`, `@Bean` and `@Configuration` is optional and must be a context type literal, including supported qualified/nested spellings. No `in:` means root; a configuration supplies the default for its beans, and per-bean ownership wins. Unknown/non-context owners fail at the argument. Scanned local-package providers remain root-owned by default and cannot be assigned to an app child.

### Generated protocol and resolution

Generate `{ContextTypeName}Protocol: AnyObject` and concrete conformance for each context. The child protocol exposes only its own providers and input properties. It does not refine or re-export its parent protocol and has no consumer-facing parent member. Assisted providers appear as methods with their runtime parameters; ordinary providers appear as getters. Managed child protocols additionally expose isolated `close() async`.

The generator selects each dependency's owner at build time. It emits direct own access or parent-protocol delegation. Parent instances are never cached as child-owned singletons. Parent providers always resolve dependencies in their own graph, even when requested from a child. Singleton identity is per owning context; transient providers create per access and assisted providers per call, following existing rules.

Retain once-only singleton materialization guarantees. ARC-only children use the existing registry concurrency model; managed resolution and lifecycle state are isolated to `MainActor`.

### Existing feature composition

1. Keys remain `(type, qualifier)`. Duplicate own keys or keys duplicated across the parent/child chain are errors, including inputs. Distinct siblings may provide the same key. No shadowing/overrides.
2. Check accessor collisions per generated context, including declared input names and lifecycle members. Distinct keys in different contexts may have the same accessor name; resolution always identifies the owner.
3. Deferred and assisted factories follow the shipped factory spec: match the visible unqualified return provider and assisted parameter types; apply existing defaults/mismatch diagnostics. Plain injection of an assisted provider still fails. Factory edges remain lazy for cycle analysis.
4. A child-rooted injected factory retains the child and checks the child's open state on every invocation, including when its target belongs to the parent. A factory created inside a parent-owned bean belongs to the parent graph and is not invalidated by a child's close.
5. Collection lookup uses the consumer's visible providers. An explicit visible array provider wins; otherwise select members, order by accessor name (owner name breaks cross-context ties), apply scope and self/assisted exclusions, and preserve existing empty/default rules. Parent collection consumers see only parent members. An input can supply an explicit array/type key; conformance-based membership uses the same scanned-type rules as other providers.
6. Generated factories can strongly capture contexts. A context-cached singleton that stores a factory capturing that context may form a retain cycle. Contexts themselves are not injectable beans, but that does not prevent all cycles. Keep the example's factory-holding coordinator transient and owned by the flow.
7. The existing direct inter-bean-call warning remains. No runtime proxies or method-body interception are added.

### Optional managed teardown

```swift
@MainActor
@ChildContext(of: AppContext.self, teardown: .managed)
final class LoggedInContext {
	@ContextInput let credentials: SessionCredentials
}

// Proposed public protocol shape; no implementation in Phase 1.
@MainActor
public protocol ContextCleanup: AnyObject {
	func close() async
}
```

The `teardown:` policy accepts `.arc` (default) and `.managed`; its public policy type is fixed in Phase 2. Unsupported/nonliteral policies are diagnosed. The class-bound cleanup protocol is a public library surface. No cleanup conformance is required of ordinary beans.

A managed child must explicitly declare `@MainActor`. Its initializer, protocol, generated accessors, factories and lifecycle state preserve that isolation. A caller outside the actor uses Swift's normal actor access rules. Generated source must compile with strict concurrency, compatible fake parents and main-actor screen-model factories; it must not rely on unsafe sendability promises. Parent isolation remains in force. Any declaration whose actor requirements cannot be preserved must fail compilation with a positioned diagnostic rather than silently erasing isolation.

Managed context state is `open → closing → closed`:

1. **Open:** accessors, assisted methods and injected factories resolve normally. Enroll a participating object only after successful singleton creation. Record its identity once, at first enrollment, even if several singleton keys return it.
2. **Start close:** the first call transitions to closing before any suspension. Join one shared cleanup operation for repeated callers. Caller cancellation never cancels that operation or lets close return before shared completion.
3. **Resolution boundary:** after closing starts, every generated provider accessor, assisted method and previously obtained child-rooted factory fails a documented precondition naming the context. No cached provider is returned and no new provider is constructed. Accessors stay nonthrowing. Direct reads of stored context inputs are exempt.
4. **Participation:** close only instantiated child-owned singleton objects conforming to `ContextCleanup`. Never instantiate unused providers for cleanup. Exclude parent beans, input values and transient/assisted instances, even when they conform; their owners must stop their work.
5. **Order:** await callbacks sequentially in reverse first-enrollment order (reverse successful creation for distinct objects). This is not reverse dependency order when factories defer construction. Shared cleanup ownership of the same object across managed children is unsupported; put such objects in the parent.
6. **Finish:** after all callbacks return, clear singleton cache references and cleanup records, mark closed and complete all waiters. This includes nonparticipating cached singletons. Parent and stored inputs remain retained until context deallocation. Later close calls return without work.
7. **Callback obligations:** callbacks are async and nonthrowing, handle their own recoverable failures and use already-held dependencies. They must not resolve through the closing child, recursively await that same child's close, or wait for work whose completion depends on that close completing. There is no implicit timeout for nonreturning callbacks.
8. **Escaped references:** cleanup runs even when a view/model/task retains a participating singleton. That object may deallocate later; its own implementation determines how later method calls behave. No interception or forced deallocation is promised. Nonparticipating objects have no generated shutdown behavior.
9. **ARC fallback:** releasing an unclosed managed child still releases solely held objects via ARC, but no async callbacks are promised. Deinit does not launch an unstructured cleanup task. The app must await flow close on logout/expiry. Default ARC-only contexts run no cleanup callbacks at all.

### Generation, diagnostics and dumps

Validate ownership, root/parent shape, keys, conflicts, supported input syntax, dependency availability, eager cycles, existing assisted/factory rules and actor constraints. Missing-dependency errors name the consumer's context and searched contexts. An ancestor or sibling consumer needing a known child-only key gets a lifetime/visibility diagnostic naming that child. Diagnostics are deterministic and source-positioned.

Emit contexts deterministically, root first and child types sorted by qualified name. Emit each provider once in its owner's extension. No-context/root-only targets retain current behavior unless new declarations require a diagnostic. Generation failure leaves prior output artifacts untouched; do not publish partial updated Swift or dumps.

With children, graph dumps identify nodes by both owner context and bean key, including input providers, so identical sibling keys cannot collapse. Show ownership and parent dependencies in the existing Markdown and DOT outputs; retain injected-edge semantics and correct source/target ownership. Sort by owner then existing key/location ordering. Inputs display their stored-property origin and input lifetime. Root-only dump bytes, CLI options and plugin output/resource handling remain unchanged. This is ownership correctness, not new per-context output files or visualization styling.

## Example application: coordinator-owned login flow

- `AppContext` owns shared infrastructure, authentication dependencies and app-lifetime repositories such as a catalog repository. These repositories never capture child services or current-session credentials.
- `LoggedInContext` receives credentials and owns `UserRepository`, session work and transient screen models. A child model can also use app-owned repositories.
- `LoggedInCoordinator` is a transient child service. It receives deferred/assisted screen-model factories, owns navigation paths and exposes `build(_:)`, preserving the current example's composition style.
- Application-owned `LoggedInFlow` retains the context and coordinator, creates a unique presentation identity and delegates async close to the context. It is example code, not a library type.
- Example ownership amendment approved 2026-10-25 in [example-session-lifecycle/SPEC.md](../example-session-lifecycle/SPEC.md): the app entry point supplies a manual `(SessionCredentials) -> LoggedInFlow` factory to `AppSession`, composes root `AppCoordinator` with its login-model factory and an injected sign-in action, and supplies session and coordinator separately to `AppRootView`. The app retains the session, which owns the flow; the coordinator has no session property. Root presentation reads the session directly and signed-in UI receives logout/expiry callbacks. The closure creates `LoggedInContext(parent: app, credentials:)`. No automatic child factory or context injection is required. The follow-up architecture was approved separately on 2026-10-25; original child-context verification records the delivered baseline.
- `AppRootView` switches between login and the active flow. The signed-in navigation/tab subtree is keyed by flow identity and receives `LoggedInCoordinator` via the environment. It still calls `coordinator.build(.itemList)` and `.build(.user)`. Each view owns its model through `@State`; `UserTabViewModel` receives `UserRepository`, not a context.

Launch shows login and constructs no child services. Authentication success constructs a fresh flow. Logout/expiry invalidates pending login attempts, removes the signed-in flow from presentation and retains it locally until async cleanup completes. Duplicate logout/expiry requests do not start another cleanup. Another login is gated until cleanup completes. Late authentication results from an obsolete attempt cannot restore the ended flow. A failed login remains on login with no child created.

Switching tabs or ordinary navigation does not close the session. View disappearance/deinit timing is not used to trigger async cleanup. Participating work is cancelled/stopped and awaited by its owning service's cleanup implementation. Persistent credential deletion/revocation remains authentication-layer work. Once outgoing UI and tasks release references, session-owned models, coordinator, context and repositories deallocate; app repositories keep their identity across logins.

## Acceptance criteria


### Scenario: Child bean uses a parent bean

**Given** `@Service final class APIClient` owned by the root\
**And** `@Service(in: UserSessionContext.self) final class FeedRepository { init(api: APIClient) }`\
**And** `@ChildContext(of: AppContext.self) final class UserSessionContext`\
**When** the target builds\
**Then** `UserSessionContext` exposes `feedRepository`\
**And** its `APIClient` is the same instance as `appContext.apiClient`

### Scenario: Child singletons are per child instance

**Given** a child-owned singleton `FeedRepository`\
**When** two `UserSessionContext` instances are created over the same parent\
**Then** each returns the same `FeedRepository` on repeated access\
**And** the two children return different `FeedRepository` instances

### Scenario: Parent singletons are shared between children

**Given** a root singleton `APIClient` used by a child bean\
**When** two children over the same parent each resolve a bean that depends on `APIClient`\
**Then** both beans hold the identical `APIClient` instance

### Scenario: Parent transient is recreated for child access

**Given** a root `@Service(scope: .transient) Validator`\
**And** a child-owned transient `Report` that depends on `Validator`\
**When** the child creates two `Report` instances\
**Then** their `Validator` instances are not identical

### Scenario: Context input is injectable inside the child

**Given** `@ChildContext(of: AppContext.self) final class UserSessionContext { @ContextInput let user: User }`\
**And** a child-owned `@Service` whose initializer takes `user: User`\
**When** `UserSessionContext(parent: app, user: alice)` is created\
**Then** the service receives `alice`\
**And** `UserSessionContextProtocol` exposes `var user: User { get }`

### Scenario: Context input replaces the need for a provider

**Given** a child bean requires `User` and `User` is only a `@ContextInput`\
**When** the target builds\
**Then** the build succeeds without any `@Bean` for `User`

### Scenario: Child created over a fake parent

**Given** a hand-written `FakeAppContext: AppContextProtocol`\
**When** `UserSessionContext(parent: FakeAppContext(), user: alice)` is created\
**Then** child beans receive parent dependencies from the fake\
**And** no concrete `AppContext` is needed

### Scenario: Parent bean cannot depend on a child key

**Given** a root-owned `@Service final class Analytics { init(feed: FeedRepository) }`\
**And** `FeedRepository` is owned only by `UserSessionContext`\
**When** the target builds\
**Then** the build fails at the `feed` parameter\
**And** the message says the key is provided only by `UserSessionContext`, a shorter-lived context

### Scenario: Siblings cannot see each other

**Given** child contexts `UserSessionContext` and `GuestSessionContext`, each over `AppContext`\
**And** a `GuestSessionContext` bean that depends on `FeedRepository` owned by `UserSessionContext`\
**When** the target builds\
**Then** the build fails at that parameter naming `UserSessionContext`

### Scenario: Siblings may provide the same key

**Given** `UserSessionContext` and `GuestSessionContext` each own a `SyncEngine`\
**When** the target builds\
**Then** the build succeeds and each child exposes its own `SyncEngine`

### Scenario: Child key duplicating a parent key fails

**Given** the root provides `Clock` and `UserSessionContext` also provides `Clock`\
**When** the target builds\
**Then** the build fails with a duplicate-provider error at both declarations, naming both contexts

### Scenario: Missing dependency in a child names the context

**Given** a child bean depending on `Analytics`\
**And** no provider for `Analytics` in the child or the root\
**When** the target builds\
**Then** the build fails at the parameter and names `UserSessionContext` and the checked contexts

### Scenario: Cycle inside a child fails

**Given** child-owned `A` depends on `B` and `B` depends on `A`\
**When** the target builds\
**Then** the build fails with a cycle diagnostic that names the child context

### Scenario: Unknown or invalid parent fails

**Given** `@ChildContext(of: NotAContext.self) final class Broken`\
**When** the target builds\
**Then** the build fails at the `of:` argument

### Scenario: `in:` naming a non-context fails

**Given** `@Service(in: String.self) final class Foo`\
**When** the target builds\
**Then** the build fails at the `in:` argument

### Scenario: Child without a root fails

**Given** a target with a `@ChildContext` and no `@ApplicationContext`\
**When** the target builds\
**Then** the build fails at the child declaration

### Scenario: Releasing the child releases its singletons

**Given** a child-owned singleton held only by the child's registry\
**When** the last strong reference to the child is released\
**Then** the singleton deinitializes\
**And** the parent and its singletons are unaffected

### Scenario: Child keeps its parent alive

**Given** a child created over a parent that the test then releases\
**When** the child still exists\
**Then** the parent is not deallocated and parent beans still resolve

### Scenario: Assisted provider owned by a child

**Given** a child-owned `@Service` with an `@Assisted` parameter\
**When** the target builds\
**Then** the child and `{Child}Protocol` expose a method accessor with the assisted parameters\
**And** each call returns a new instance with graph parameters taken from own or parent keys

### Scenario: Per-bean `in:` overrides configuration default

**Given** `@Configuration(in: UserSessionContext.self)` with one `@Bean(in: AppContext.self)`\
**When** the target builds\
**Then** that bean is exposed by `AppContext` and the others by `UserSessionContext`

### Scenario: Child singleton factory runs once under concurrent access

**Given** a child-owned singleton whose factory counts invocations\
**When** many threads resolve it for the first time at once\
**Then** every caller gets the same instance and the factory ran exactly once

### Scenario: Graphs without child contexts are unchanged

**Given** an existing target with no `@ChildContext` and no `in:` argument\
**When** the generator runs\
**Then** the generated file is byte-identical to the output before this feature

### Scenario: Local-package provider cannot target a child

**Given** a `@Service(in: UserSessionContext.self)` in a `local_packages` target\
**When** the target builds\
**Then** the build fails at the declaration explaining that child-owned providers must live in the app target

### Scenario: Plain types remain manually constructible

**Given** a child-owned `@Service` type `FeedRepository`\
**When** a unit test constructs it directly with fakes\
**Then** it compiles and runs without any context

### Scenario: Context inputs preserve declaration order and property names

**Given** inputs `currentUser: User` and `credentials: SessionCredentials` in that order\
**When** the child initializer and protocol are generated\
**Then** the initializer labels are `parent:`, `currentUser:`, `credentials:` in that order\
**And** a dependency on `User` reads `self.currentUser` and the protocol exposes that name

### Scenario: Root and child protocols expose their own graph

**Given** a root with app services and an ARC-only child with input and session services\
**When** source is generated\
**Then** each protocol lists only its own keys and inputs, with assisted providers as methods\
**And** the child does not refine the parent protocol or expose a parent member

### Scenario: Invalid context shapes and parent relationships fail (F1)

**Given** separate fixtures with a non-final class, struct, actor or generic child, a nonliteral parent, self/cyclic parent, child-of-child parent, or multiple roots\
**When** the target builds\
**Then** each fixture fails with a positioned diagnostic explaining its invalid shape or relationship\
**And** the existing unknown-parent and missing-root scenarios also apply

### Scenario: Invalid inputs fail at their declaration (F3)

**Given** separate fixtures with an input outside a child, mutable/static/computed input, missing type, unsupported/optional type, default, destructuring, or multiple bindings\
**When** the target builds\
**Then** each fixture fails with a positioned diagnostic explaining the unsupported input

### Scenario: Reserved names and accessor collisions fail (F2, F3)

**Given** separate fixtures with an input named `parent`, a hand-written child initializer, a generated-storage collision, two own keys sharing an accessor name, or a managed provider/input colliding with `close`\
**When** the target builds\
**Then** each fails at the conflicting declaration with a diagnostic naming the reserved/generated member

### Scenario: Inputs participate in duplicate-key validation (F2)

**Given** separate fixtures with two inputs of the same key, an input duplicating a child provider, or an input duplicating a parent key\
**When** the target builds\
**Then** each fails with a duplicate-key diagnostic naming the owners and conflicting declarations

### Scenario: Invalid ownership and teardown policies fail (F3)

**Given** separate fixtures with nonliteral `in:`, an unknown owner, or an unsupported/nonliteral teardown policy\
**When** the target builds\
**Then** each fails with a positioned diagnostic at the invalid argument

### Scenario: Generated output is deterministic with sibling contexts

**Given** the same root and sibling child declarations scanned in different input orders\
**When** generation succeeds\
**Then** Swift and both graph dumps are byte-identical across runs\
**And** root precedes children and child types sort by qualified name

### Scenario: Child deferred and assisted factories use the visible owner

**Given** a transient child coordinator with a deferred model factory and an assisted detail-model factory\
**And** their models depend on a child repository and a parent catalog repository\
**When** the factories are called repeatedly\
**Then** they create fresh transient/assisted models with supplied arguments and the correct owner's dependencies\
**And** factory matching/default/cycle rules remain those of the shipped factory spec

### Scenario: Parent-owned providers remain in the parent graph

**Given** a parent provider containing a factory or collection dependency, also used by a child\
**When** the child resolves that provider\
**Then** its dependencies are selected solely from the parent graph\
**And** another child's providers never influence it

### Scenario: Assisted and factory diagnostics apply within each context (F2)

**Given** separate fixtures with a plain dependency on a visible assisted provider, a mismatched factory signature, or a missing/unsupported factory target without a default\
**When** the target builds\
**Then** existing assisted/factory diagnostics are emitted at the parameter and identify the consumer context

### Scenario: Qualifiers and collections respect visible keys

**Given** distinct named members of one protocol in parent and child and a qualified dependency in the child\
**When** child and parent collection consumers resolve\
**Then** the child collection contains visible members from both contexts, using each owner's accessor and scope\
**And** the parent collection contains only parent members\
**And** the qualified dependency selects only its exact visible key

### Scenario: Visible array provider wins over collection members

**Given** an explicit array provider visible from a child plus individual matching members\
**When** the child injects that array type\
**Then** the array provider is used without merging members\
**And** without such a provider the shipped ordering, self-exclusion, assisted exclusion and empty/default rules apply to visible members

### Scenario: Child dump nodes retain ownership and sibling identity

**Given** sibling contexts providing the same key, a context input and a child bean using a parent dependency\
**When** generation succeeds\
**Then** Markdown and DOT distinguish both sibling nodes, identify the input origin and show the edge to the parent-owned node\
**And** existing output-file names and plugin resource handling are preserved

### Scenario: Invalid child graph does not publish partial output (F1, F2, F3, F4)

**Given** previous valid generated artifacts and a newly invalid child declaration or graph\
**When** generation fails\
**Then** positioned diagnostics are returned and no new Swift or graph dump is published\
**And** existing artifacts remain untouched

### Scenario: Multiple children do not rescan all sources

**Given** one generator invocation with a fixed discovered source set and several child declarations\
**When** graphs and output are built\
**Then** each discovered source is parsed once rather than once per child\
**And** parent providers are emitted once in the parent instead of copied into child extensions

### Scenario: Managed isolation is preserved through fake parent and factory use

**Given** a managed MainActor child over a compatible hand-written parent protocol fake and a transient coordinator with actor-compatible model factories\
**When** generated source and client usage compile under strict concurrency\
**Then** child construction, protocol requirements, resolution, factories and cleanup preserve MainActor isolation\
**And** fake-parent dependencies resolve without unsafe sendability assertions

### Scenario: Unsupported managed isolation fails (F4)

**Given** separate fixtures with managed mode on a nonisolated child, an unsupported actor annotation or actor-incompatible consumer factory\
**When** the target builds\
**Then** a positioned macro/generator or Swift compiler diagnostic identifies the incompatible declaration or use

### Scenario: Managed protocol exposes close

**Given** a managed child referenced as `any LoggedInContextProtocol`\
**When** a caller awaits its close on the actor\
**Then** the managed cleanup boundary is accessible through the protocol\
**And** a hand-written fake can implement that contract

### Scenario: Default ARC mode does not invoke cleanup (F8)

**Given** an ARC-only child whose singleton conforms to `ContextCleanup`\
**When** all child and singleton references are released\
**Then** objects deallocate without invoking async cleanup\
**And** the child protocol has no generated close requirement

### Scenario: Managed close automatically cleans up enrolled singletons

**Given** two instantiated participating child singletons plus an unused participating provider, a transient participating instance, a cleanup input and a parent cleanup bean\
**When** managed close completes\
**Then** only the instantiated participating child singletons have received callbacks, in reverse first-enrollment order\
**And** the unused provider was never constructed and excluded objects were never enrolled\
**And** all cached child singleton and cleanup references are cleared, including nonparticipating singletons

### Scenario: Cleanup deduplicates object identity

**Given** two own singleton keys return the same participating object\
**When** the child closes\
**Then** that object is cleaned once at the reverse-order position established by its first enrollment

### Scenario: Repeated and overlapping close calls share completion (F6)

**Given** close has entered a suspended cleanup callback\
**When** a second caller awaits close, the first waiter is cancelled, and the callback is then allowed to finish\
**Then** cleanup continues and all close waiters complete only after shared cleanup finishes\
**And** subsequent close calls invoke no additional callbacks

### Scenario: Cancelling all waiters does not abandon cleanup (F6)

**Given** managed cleanup is suspended and all current waiting tasks are cancelled\
**When** the callback is allowed to finish and another caller awaits close\
**Then** cleanup has continued exactly once and the new caller observes completed close

### Scenario: Resolution through generated accessors fails once closing starts (F5)

**Given** a managed child with cached and unresolved providers and an assisted method, referenced concretely and through its protocol\
**When** separate subprocess fixtures attempt resolution during suspended cleanup or after closed state\
**Then** each provider accessor/method fails a precondition naming the context\
**And** no cached provider is returned and no new construction occurs

### Scenario: Retained child-rooted factories cannot reopen a closed graph (F5)

**Given** deferred and assisted factories obtained through child injection, including a deferred factory targeting a parent bean\
**When** separate subprocess fixtures invoke them after child closing starts or completes\
**Then** each fails the child's lifecycle precondition without invoking its target provider\
**And** parent-rooted factories remain usable in their own graph

### Scenario: Parent and inputs remain owned until child deallocation

**Given** a managed child holding reference-type inputs and a parent with otherwise released references\
**When** close finishes while the child itself is retained\
**Then** input properties remain readable and the parent and inputs remain alive\
**And** releasing the final child reference permits their normal ARC release

### Scenario: Escaped participating singleton is cleaned before deallocation (F7)

**Given** a model retains a participating child repository after the flow leaves presentation\
**When** close completes\
**Then** repository cleanup has run despite that external reference\
**And** its service-defined inactive behavior applies\
**And** it deinitializes only after the model and other owners release it

### Scenario: Nonparticipating escaped objects are not automatically invalidated (F7)

**Given** an externally retained child object that does not participate in cleanup\
**When** its managed context closes\
**Then** the object's arbitrary methods are not intercepted and no shutdown callback is invented\
**And** its deallocation still follows ARC

### Scenario: Unclosed managed context uses ARC without async fallback (F8)

**Given** a managed child with a resolved participating singleton and no external references or capture cycles\
**When** the final child reference is released without close\
**Then** solely retained objects deinitialize\
**And** no async cleanup task or callback is launched from deinit

### Scenario: Suspended cleanup keeps close pending without an implicit timeout (F9)

**Given** a cleanup implementation suspended behind a controllable test gate\
**When** close begins and another caller joins it\
**Then** neither finishes or skips the callback before that gate is released\
**And** releasing the gate permits both to finish without repeated cleanup

### Scenario: Cleanup resolving from its own closing child violates the lifecycle boundary (F5, F9)

**Given** a callback retains a child-rooted factory\
**When** a subprocess fixture invokes that factory from cleanup\
**Then** the generated precondition fails instead of resolving new dependencies\
**And** recursive awaiting of the same close is documented as unsupported, with no completion guarantee

### Scenario: Example launch and login follow coordinator construction

**Given** the example app starts without an authenticated session\
**When** the root coordinator builds login and authentication later succeeds\
**Then** no child existed before success and a fresh flow/context/transient coordinator is created afterward\
**And** the signed-in subtree is keyed by flow identity and uses coordinator `build(_:)` factories

### Scenario: User tab receives its repository through the child graph

**Given** a logged-in flow with a user tab and an item-list screen\
**When** the child coordinator builds their models from factories\
**Then** the user model receives the child user repository and the list model can use an app-owned catalog repository\
**And** views/models receive no context and views own their models through State

### Scenario: Tab switching and navigation preserve the login scope

**Given** an active flow whose session services have resolved\
**When** the user switches tabs, pushes a detail screen or returns to the list\
**Then** no session close occurs and singleton repository identity remains the same

### Scenario: Logout and expiry share one cleanup boundary (F10)

**Given** an active signed-in subtree with ongoing participating session work\
**When** logout or authentication expiry ends the flow and another ending request arrives during cleanup\
**Then** the root removes the active flow from presentation and awaits its cleanup once\
**And** session work is stopped/cancelled and awaited by its owner\
**And** another login cannot create a flow until cleanup finishes

### Scenario: Failed login creates no child (F10)

**Given** the login flow with an authentication attempt\
**When** authentication fails\
**Then** login remains presented with failure state and no child or signed-in coordinator is created

### Scenario: Late authentication completion cannot restore an ended flow (F10)

**Given** a login attempt invalidated by logout/expiry or superseded by a newer attempt\
**When** its result arrives late\
**Then** that result creates no flow and cannot replace the current authentication/navigation state

### Scenario: New login resets session identity and preserves app repositories

**Given** one flow has logged out and cleanup has completed\
**When** another user logs in\
**Then** the new flow has a different context, user repository, navigation state and presentation identity\
**And** app-owned repository identity is unchanged

### Scenario: Releasing the flow breaks the coordinator factory ownership chain

**Given** a flow owns a transient coordinator whose screen factories retain the child\
**And** outgoing UI and tasks have released session references\
**When** cleanup finishes and the flow is released\
**Then** weak references to the coordinator, context, models and solely owned repositories become nil\
**And** the app context remains usable

## Failure-path traceability

| Design failure | Acceptance scenarios |
|---|---|
| F1 | Invalid context shapes/parents, unknown parent, missing root, failure publishes no partial output |
| F2 | Missing dependency, narrowing/sibling visibility, duplicates/accessor collisions, eager cycles, factory diagnostics |
| F3 | Invalid inputs, ownership/policy literals, local-package owner and generated-name conflicts |
| F4 | Unsupported managed isolation; strict-concurrency fake-parent/factory compile coverage |
| F5 | Generated accessor/assisted/factory preconditions during and after close; cleanup resolution violation |
| F6 | Overlapping/repeated close and cancellation of one/all waiting callers |
| F7 | Escaped participating and nonparticipating objects |
| F8 | Default ARC behavior and unclosed managed-context ARC fallback |
| F9 | Suspended cleanup and callback contract violations; recursive close has no completion guarantee |
| F10 | Login failure, duplicate logout/expiry, gated next login and stale authentication results |

## Delivery and verification

| Slice | Required outcome |
|---|---|
| A1 | Single-level child declarations, inputs, ownership, per-context graph validation/codegen, existing feature composition, owner-correct dumps and ARC lifetime coverage |
| A2 | Managed teardown state machine/participation, strict actor-safe contracts, cleanup/release checks and the coordinator-owned login/logout example |

After spec approval, Phase 2 defines the public macro/runtime signatures, generator data model, lifecycle/cache seams, isolation-preserving factory types, minimal dump serialization changes and scenario-to-test mapping. Stop for architecture approval before feature tests and implementation. The current architecture sketch is historical and is not the contract for this revision.

Phase 3 tests use Swift Testing, macro expansion and generated-source compile fixtures. Precondition failures use subprocess fixtures so they do not terminate the test runner. Async lifecycle tests use controllable gates and counters rather than sleeps. Recursive-close contract violations must not leave permanently hung test tasks; document the no-completion guarantee rather than adding an unbounded test. Example lifecycle/navigation behavior is tested through coordinators and models; no new UI-test workflow is required.

Phase 4 quality checks include `swift test`, an example macOS test/build pass and an iOS example build using the repository's established Xcode workflow, plus the documented strict-concurrency compile fixtures. Phase 5 independently grades the completed change against approved design/spec/architecture. Every required scenario must be mapped or explicitly decomposed into focused tests; A1 alone is not feature completion.

## Out of scope

- Root context inputs, child-of-child graphs, provider overrides/shadowing, cross-target or local-package child declarations.
- Automatically generated child/flow factories or injecting contexts themselves into beans; the example supplies its flow factory manually.
- Managed teardown on arbitrary actors or nonisolated contexts, weak parents, runtime registration or enumeration of live children.
- Lifecycle annotations such as PostConstruct/PreDestroy, throwing cleanup callbacks, timeout policies, automatic async cleanup from deinit, and automatic lifecycle ownership of transients/inputs/parent objects.
- Forced deallocation, interception of arbitrary service methods, blanket prevention of application retain cycles, or detection/cleanup of one object shared across multiple child owners.
- New matching rules for factories, qualifiers or collections; runtime inter-bean proxies or macro rewriting of bean bodies.
- Separate per-context graph files, graph rendering/styling features, automatic fake generation and library-provided SwiftUI environment bridges.
- Production authentication/backends, credential storage/revocation policy, and automatic observation of app authentication/UI state by SwiftBeans.

## Fallback policy

If an approved contract cannot compile safely or reveals a design flaw, return to the affected design/spec gate and obtain approval before changing behavior. Do not substitute runtime service lookup or unsafe sendability to bypass the contract.
