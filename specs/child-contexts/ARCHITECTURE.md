# Architecture: Child Contexts

## Status and authority

| Field | Value |
|---|---|
| Status | Phase 2 approved in chat, 2026-10-25 |
| Design | [Approved system design](../../design/child-contexts/DESIGN.md), approved 2026-10-25 |
| Spec | [SPEC.md](SPEC.md), explicitly approved in chat 2026-10-25 |
| Architecture approved | 2026-10-25 (chat: “architecture approved”) |
| Scope | A1 child graphs and A2 managed teardown plus the coordinator-owned login example |
| Contract snapshots | [RuntimeContracts.swift](contracts/RuntimeContracts.swift), [ConsumerContracts.swift](contracts/ConsumerContracts.swift), [MacroContracts.swift](contracts/MacroContracts.swift) |

This replaces the original speculative ARC-only architecture. The snapshots are reviewable contract/consumer shapes under `specs/`; they are not production code, tests or macro implementations. Runtime methods use stubs and must never be executed. Compiler verification below checks signatures and isolation only. Behavior is verified after architecture approval.

## Module boundaries

| Target | Responsibility and changes |
|---|---|
| `SwiftBeans` | Add `ChildContextTeardown`, `ContextCleanup`, `SwiftBeansManagedRegistry` and macro declaration surface. Preserve `SwiftBeansRegistry` implementation and public contract. |
| `SwiftBeansMacros` | Add `ChildContextMacro` and `ContextInputMacro`; teach existing stereotypes their new ownership argument. Child macro emits storage, parent reference, initializer and managed close forwarding. No cross-file graph lookup. |
| `SwiftBeansSyntaxRules` | Recognize child/input attributes and share local shape, input, literal-owner, policy and managed-isolation checks. Keep runtime policy separate from syntax-only `TeardownLiteral`. |
| `SwiftBeansGeneratorCore` | One scan, provider/owner resolution, context visibility, one shared injection plan, validation, owner-aware Swift and dump output. No dependency on the SwiftBeans runtime target. |
| `SwiftBeansGenerator` | Retain result/diagnostic/write contract and existing options; publish outputs only after successful generation. |
| `SwiftBeansPlugin` | Retain existing scan discovery, request schema and invocation shape; no runtime graph decisions or module-name guessing. |
| Example app | Assemble the root coordinator and flow factory at entry; use a transient child coordinator, managed child services and explicit session-ending operation. |

No new library product, general runtime locator, context tree or default global actor is introduced. Runtime support is public only where consumer-generated Swift must call it; graph and scanner types stay internal/package as appropriate.

## Public runtime contracts

`ChildContextTeardown: String, Sendable` has cases `.arc` and `.managed`. The root macro and existing `BeanScope` contract remain unchanged. `ContextCleanup` is public, class-bound and MainActor-isolated; ordinary services need no conformance.

```swift
public enum ChildContextTeardown: String, Sendable {
	case arc
	case managed
}

@MainActor
public protocol ContextCleanup: AnyObject {
	func close() async
}
```

`SwiftBeansManagedRegistry` is a separate public MainActor support type for generated code:

```swift
@MainActor
public final class SwiftBeansManagedRegistry {
	public init(contextName: String)
	public func requireOpen()
	public func singleton<T>(key: String, create: @MainActor () -> T) -> T
	public func close() async
}
```

The declaration block above is a signature listing, not executable Swift. The corresponding snapshot supplies stub bodies and compiles as a separate module. No additional `Sendable`/`@unchecked Sendable` conformance is added. The pre-existing thread-safe root/ARC registry keeps its current conformance and locking.

- `requireOpen()` enforces the lifecycle precondition, with diagnostic text `cannot resolve from <contextName>: context is closing or closed`.
- `singleton` requires open state, returns a typed cached value, or constructs synchronously on MainActor and stores it once. It does not retain the creation closure. Reentry for a currently creating key traps consistently with the existing cyclic-singleton contract.
- `close()` is nonthrowing, actor-isolated and shares a single completion across callers. No status/error accessor is added to the public context surface.
- Root/ARC contexts use `SwiftBeansRegistry`; managed children use `SwiftBeansManagedRegistry`. Generated callers use the same registry storage name but distinct statically selected types.

## Public macro contracts

[MacroContracts.swift](contracts/MacroContracts.swift) fixes the declaration spelling and overload families. Its syntax has been parsed; plugin linkage and expansion remain Phase 3/4 work.

```swift
@attached(member, names: named(_swiftBeansRegistry), named(_swiftBeansParent), named(init), named(close))
public macro ChildContext(
	of parent: Any.Type,
	teardown: ChildContextTeardown = .arc
) = #externalMacro(module: "SwiftBeansMacros", type: "ChildContextMacro")

@attached(peer)
public macro ContextInput() = #externalMacro(module: "SwiftBeansMacros", type: "ContextInputMacro")
```

`ContextInput` is a marker peer macro, not a property wrapper. It emits no peer members. ChildContext emits the initializer assigning the original stored properties. Both share validation so input misuse is positioned at the source property. It does not add hidden input accessors.

Add `in owner: Any.Type? = nil` as the first argument of every existing Service/Bean overload and Configuration. Keep the remaining `boundTo:`, `named:`, `scope:` labels, order and defaults. For example:

```swift
public macro Service(
	in owner: Any.Type? = nil,
	boundTo: Any.Type,
	named name: String,
	scope: BeanScope = .singleton
) = #externalMacro(module: "SwiftBeansMacros", type: "ServiceMacro")
```

Retain four Service and two Bean overloads. Existing calls continue omitting the new first defaulted argument. An explicitly written `in: nil` is invalid syntax for ownership even though the declaration uses nil to represent omission. Ownership expressions must be accepted type literals. Policy syntax accepts `.arc`, `.managed` and their correctly qualified enum-case spellings; variables/calls are rejected.

Macro implementation registration adds the two new macro types to `SwiftBeansMacrosPlugin`. `ApplicationContextMacro` keeps its current member expansion. New root isolation metadata used by the child-aware generator does not alter root-only macro output.

## Generated members and access

For an ARC child, emit internal `_swiftBeansRegistry: SwiftBeansRegistry`, internal `_swiftBeansParent: any ParentProtocol`, and an internal initializer with `parent:` followed by input labels in declaration order. For a managed child, select `SwiftBeansManagedRegistry(contextName: <qualified child name>)` and also emit `func close() async` forwarding to it. Storage and initializers must be visible to same-module generated extensions in other files.

Children remain ordinary final classes. Protocols/accessors/conformance stay target-internal as in the current generated surface. Member access obeys Swift's normal visibility rules; the compiler diagnoses user declarations that cannot satisfy or be accessed by this surface. No public exported context-protocol API is added.

```swift
@MainActor
protocol LoggedInContextProtocol: AnyObject {
	var credentials: SessionCredentials { get }
	var userRepository: any UserRepository { get }
	var userTabViewModel: UserTabViewModel { get }
	func detailViewModel(item: Item) -> DetailViewModel
	func close() async
}
```

Stored inputs directly witness their protocol getters and keep their declared property names. Accessing an input is allowed after close. The child protocol lists no parent accessors. MainActor parent contexts expose MainActor protocol requirements in the child-aware output path; ordinary parents retain nonisolated requirements. Root-only output retains its existing form.

Reject generated-name conflicts, including two context simple names producing one top-level protocol name, initializer/input labels, lifecycle names and storage. Do not silently rename protocols or keys.

## Isolation and factory contract

The child-aware scanner records explicit MainActor annotation on contexts and relevant declarations/factory types. MainActor generated protocols, initializers and accessors preserve it. No actor hop is hidden inside a synchronous getter. Unsupported custom-global-actor requirements remain a positioned diagnostic/compiler error under the spec.

Managed coordinator factories in the example explicitly carry actor types:

```swift
@MainActor
final class LoggedInCoordinator {
	private let makeUser: @MainActor () -> UserTabViewModel
	private let makeDetail: @MainActor (Item) -> DetailViewModel

	init(
		makeUser: @escaping @MainActor () -> UserTabViewModel,
		makeDetail: @escaping @MainActor (Item) -> DetailViewModel
	) { /* store the factories */ }
}
```

Matching still uses return key and assisted parameter types. Preserve source function attributes separately for isolation/Swift type checking; do not remove them from emitted consumer contracts or force a `@Sendable` conversion. Actor-compatible async/throwing factory contexts retain Swift's legal function conversions. An incompatible requested type must fail at a positioned diagnostic or generated Swift conversion, not be repaired by dropping actor annotations.

Every managed child-rooted factory checks open state, independently of the target's owner:

```swift
makeUser: { @MainActor in
	self._swiftBeansRegistry.requireOpen()
	return self.userTabViewModel
},
makeDetail: { @MainActor item in
	self._swiftBeansRegistry.requireOpen()
	return self.detailViewModel(item: item)
},
makeTransport: { @MainActor in
	self._swiftBeansRegistry.requireOpen()
	return self._swiftBeansParent.transport
}
```

Transient/assisted generated accessors also guard before construction; singleton accessors guard in the managed registry. Parent-owned factory expressions are emitted in the parent's accessor and capture/check that owner only. Direct context inputs remain unguarded, but a factory injected by the managed child targeting an input still checks the child's state.

## Managed lifecycle state and ownership

`SwiftBeansManagedRegistry` privately owns:

- State `open`, `closing`, or `closed`, and a shared `Task<Void, Never>?` for completion.
- Slots keyed by existing registry key spelling: `creating` or `ready(Any)`. Construction is synchronous and nonthrowing. MainActor serialization eliminates concurrent publication races; creating markers preserve reentrant-cycle detection.
- An ordered list of strong `any ContextCleanup` references and an `ObjectIdentifier` set. No stored enrollment closure captures the child. First successful creation/enrollment determines position; aliases returning the same object do not append another record.

After creation, attempt the marker cast on MainActor (`value as? any ContextCleanup`). This is participation detection, not provider search. It handles protocol-bound/erased singleton return types using the actual object. Only the managed singleton method enrolls; caller-owned inputs, transients and parent resolutions never go through it.

First close sets state to closing before creating/awaiting a shared **unstructured MainActor Task**. The new task is not a child task cancelled by a waiter; do not propagate caller cancellation into it. Each call awaits the same task value. It closes enrolled references in reverse order, clears all singleton slots and enrollment references, marks closed and drops the stored task reference. Capture the support registry, not the whole child, for this operation. A running task may retain the registry until completion; completion must break the stored-task capture cycle. All waiters finish only after the closed transition. Later close calls return immediately.

No creation/accessor suspends, so close cannot interleave inside synchronous materialization on MainActor. Once closing starts, reentrant calls from callbacks see the same resolution precondition. Recursive waiting on that same task is unsupported exactly as specified; no new recovery behavior or timeout is added.

The context's parent and input storage live outside the managed registry and survive cache release. Retaining the child, an escaped factory, a model, or a repository can extend the relevant objects' ARC lifetimes. Participating services implement their own inactive state and cancellation, and must await the completion of work they own. Closing the registry cannot intercept unrelated methods or cancel arbitrary tasks.

## Generator representation and pipeline

Keep existing `TypeKey`, `BeanKey`, `SourcePosition`, `GeneratorDiagnostic` and public/package generation entry points. Introduce a child-aware plan beside the legacy root path:

| Representation | Contract |
|---|---|
| `ContextID` | Qualified target declaration name; stable/hashable, independent of scan order |
| `ContextDecl` | Existing name/simpleName/location plus kind (root or declared parent reference), explicit isolation, teardown policy, inputs and source origin |
| `ContextInputDecl` | Owner, declared property spelling, normalized unqualified key, source type spelling, declaration index and location |
| `OwnerReference` | Omitted/root or explicit context type literal plus lexical declaration scope and argument location |
| `ProviderID` | `(owner: ContextID, key: BeanKey)`; key alone never identifies a multi-context provider |
| `GraphProvider` | ProviderID, accessor/type spelling, origin/location, storage (`input`, `singleton`, `transient`), construction, selected parameters and scanned conformances |
| `ContextPlan` | Own providers/inputs, parent ID, visible provider indexes, isolation and teardown policy |
| `ResolvedInjection` | Own/parent provider reference, ordered collection references, deferred/assisted factory target+argument mapping, runtime assisted argument, or use-default |
| `GraphPlan` | Sorted context plans and providers plus one resolved injection plan used by validators, Swift output and dumps |

These IR types are internal to generator core. Runtime `ChildContextTeardown` is not imported there; syntax rules expose a parallel `TeardownLiteral` with literal parsing. Ownership metadata is collected on Service, Bean and Configuration declarations before ProviderResolver applies initializer/scope rules.

Pipeline:

1. Read/deduplicate discovered paths as today and parse each source once through `DeclarationScanner`. Retain qualified context names, inputs, ownership locations, source origin, policy and isolation metadata. Existing import and conformance discovery remain shared.
2. Run declaration-local rules. New child/input violations produce error diagnostics and make generation fail, rather than publishing an incomplete graph. Macro diagnostics use the same violations; no second independent rule engine is added.
3. Resolve context references and ownership once. Require one target root; reject unknown/non-context/cyclic parents and child-of-child depth. Apply per-bean ownership override over configuration default, then root. Ignore local-package context declarations as roots/children and reject child ownership on their providers.
4. Reuse `ProviderResolver` selection, key, scope, assisted and conformance rules; convert definitions and inputs to owner-qualified GraphProviders. Validate own/cross-chain duplicate keys and generated-name collisions before dictionary construction.
5. Build parent visible indexes once and child own+parent views without duplicating owned records. Resolve each consumer in its **owner's** view, preserving input names and all existing qualifier/factory/collection/default rules. Extend `ParameterInjection`/`FactoryBinding` matching logic to provider references or expose a shared adapter; do not reimplement a second matching algorithm.
6. Validate eager dependencies/cycles and visibility diagnostics against resolved references. Factory edges are lazy; own/parent/collection eager edges obey the same validator semantics. If a key is absent from visibility but present in a sibling/descendant, report that owner in the error. Never resolve a parent consumer in a child's merged view.
7. Emit direct Swift access paths from the plan, root then sorted children. Managed factories include lifecycle guards. Emit dumps from the same owner-qualified identities. Aggregate diagnostics deterministically and return nil output/dumps on any error.

For targets with no child or explicit ownership declaration, retain the existing single-root generation/dump path and exact bytes. Route invalid child declarations to validation even if no valid child survives scanning. Do not accidentally treat invalid new syntax as an old root-only target.

### Qualified context references

The generator resolves lexical/nested references against target declarations. A qualified spelling whose local provenance cannot be proven from syntax can select a unique local candidate only with a generated compiler identity witness. It must never silently equate an arbitrary external suffix with a local type.

For each such parent or owner reference, emit an internal/private, never-called validation function containing both identity conversions, using the original reference spelling and the resolved local declaration spelling:

```swift
private func _swiftBeansValidateContextReference() {
	let _: (MyApp.AppContext) -> AppContext = { $0 }
	let _: (AppContext) -> MyApp.AppContext = { $0 }
}
```

Both conversions are necessary: a subclass-to-superclass conversion alone would not prove type identity. Reference class names are concrete and nongeneric; the compiler rejects different nominal types, including another module's same-named context. A same-module-qualified spelling resolves to the actual local type and passes. Parent protocol fakes remain valid because the witness checks the declared context type, not the initializer's parent existential.

Place witnesses in a generated private namespace keyed by context/provider identity and use source-location directives to point compiler failures back to the original reference. Annotate a witness with MainActor where required by the referencing context; it performs no resolution and is never executed. Diagnose absent/ambiguous candidates in the generator instead of emitting a witness. Reject collisions with generated names.

This keeps GeneratorRequest/GeneratorInput and both build-plugin adapters unchanged. SwiftPM's API exposes moduleName, but the installed XcodeTarget API exposes displayName/product rather than the actual Swift module name; do not derive PRODUCT_MODULE_NAME from those labels. Phase 3 must cover true same-module qualification, nested references and a foreign-module lookalike rejected by the identity witness. ConsumerContracts contains a same-module witness compiled with the explicit module name `ChildContractConsumer`.

## Diagnostics and graph dumps

Retain current diagnostic IDs for existing errors. Add child-specific IDs for context kind/parent/owner/input/policy/isolation/name validation, and `graph.contextVisibility` for known but invisible keys. Messages name the relevant contexts; use related-location notes for conflicting declarations. Freeze exact IDs/messages in Phase 3 fixtures. Compiler-provided visibility/actor diagnostics remain valid for types the syntax scanner cannot semantically resolve.

In a child graph, Markdown adds an Owner column and lists context relationships. Each node's internal identity is the unambiguous serialized pair `[qualifiedContextName, canonicalBeanKey]`; DOT quotes/escapes that pair as its ID. Inputs show `input` storage and their source property origin. Parent edges point to the actual parent node; siblings cannot collapse onto one same-key node. Sort by owner then key/location and de-duplicate eager dependency edges. Factories remain lazy and do not add eager edges; resolved collection members do. Root-only dump format and bytes are preserved on the legacy path.

Keep current Swift/DOT/Markdown filenames, CLI options, write-if-changed behavior and plugin resource handling. Graph files remain undeclared as compiled build outputs. Validate the whole GraphPlan before the CLI writes any artifacts; no invalid graph yields partial updated output.

## Example application seams

- Follow-up ownership amendment approved with [example-session-lifecycle/SPEC.md](../example-session-lifecycle/SPEC.md), 2026-10-25: the app entry point constructs `AppSession` with the manual flow factory, composes root `AppCoordinator` with a login-model factory and injected sign-in action, and passes session and coordinator separately to `AppRootView`. The signed-in UI receives logout/expiry callbacks and no root coordinator environment dependency. Fakes/tests use the same composition seam. No root provider acquires an implicit child dependency. Detailed follow-up architecture is [approved separately](../example-session-lifecycle/ARCHITECTURE.md), 2026-10-25; original verification records the delivered baseline.
- `LoggedInCoordinator` is a transient MainActor child service with explicit actor-compatible deferred/assisted factories. It owns signed-in paths/tab selection and builds views. The child registry does not cache it.
- `LoggedInFlow` is a MainActor application-owned object with immutable UUID identity, a retained `LoggedInContext`, a retained coordinator and `close() async` forwarding to the child. The context can be private to composition code; views/models receive no context.
- Under the approved follow-up spec amendment, the app retains the session separately from the root coordinator; the session owns authentication attempt identity and explicit lifecycle state. Root presentation observes the session directly, while the coordinator only constructs screens using an injected sign-in action. Successful login installs one new flow. Logout/expiry invalidates pending attempts, clears presentation and awaits a locally retained flow; another login is gated until completion. Duplicate ending requests do not replace the in-flight operation. Late login results are checked against attempt identity before constructing a child.
- App-owned catalog/infrastructure services stay in `AppContext`; `UserRepository` and owned background work live in `LoggedInContext`. Only session-owned singleton services needing shutdown adopt ContextCleanup. Transient models use structured view tasks or explicit model-owned cancellation; registry close does not enroll them.
- A new presentation identity resets the signed-in subtree. Tab changes and ordinary navigation preserve the active flow. Persistent credential operations stay in authentication code. Cleanup tests observe service-owned work completion and weak-reference release, not SwiftUI deinit timing.

The flow owns the coordinator → factories → context chain. Neither a singleton cache entry nor a callback stored in the context may retain that coordinator. Broader application capture cycles remain the application's responsibility.

## Verification evidence and Phase 3 seams

On 2026-10-25, Apple Swift 6.4 type-checked RuntimeContracts (including marker-cast and cleanup-task shapes) as a separate module and ConsumerContracts (including a type-identity witness) against that module with `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`. The consumer passed both with ordinary default isolation and `-default-isolation MainActor`. MacroContracts passed parser validation. Scratch negative compiler probes also rejected actor erasure (`loses global actor 'MainActor'`) and both conversions between a local AppContext and an external module's same-named class. This proves proposed signature/accessibility/isolation compatibility for the snapshots, not cleanup behavior, macro linkage, graph generation or production output.

Reproduce without editing production sources; set `contractWork` to a fresh temporary directory:

```sh
contractWork=$(mktemp -d /private/tmp/swiftbeans-child-contracts.XXXXXX)
swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors \
	-module-cache-path "$contractWork/cache" -emit-module -module-name SwiftBeansContracts \
	-emit-module-path "$contractWork/SwiftBeansContracts.swiftmodule" \
	specs/child-contexts/contracts/RuntimeContracts.swift
swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors \
	-module-name ChildContractConsumer -module-cache-path "$contractWork/cache" -I "$contractWork" -typecheck \
	specs/child-contexts/contracts/ConsumerContracts.swift
swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors \
	-default-isolation MainActor -module-name ChildContractConsumer -module-cache-path "$contractWork/cache" \
	-I "$contractWork" -typecheck specs/child-contexts/contracts/ConsumerContracts.swift
swiftc -frontend -parse specs/child-contexts/contracts/MacroContracts.swift
```

Phase 3 adds meaningful behavior coverage in these seams:

| Suite / fixture | Scope |
|---|---|
| `SwiftBeansMacrosTests` | ChildContext/ContextInput expansions, policy/ownership overloads and positioned local errors |
| `GeneratorChildContextTests` / `GeneratorChildContextDiagnosticsTests` | Ownership, visibility, codegen, inputs, existing feature matching and deterministic failures |
| `ChildContextGraphDumpTests` | Owner-qualified identities, input nodes, parent edges, stable output and no partial publication |
| `SwiftBeansManagedRegistryTests` in `SwiftBeansTests` | Cleanup enrollment/order, identity deduplication, suspended/repeated/cancelled close, cache release and ARC fallback |
| `SwiftBeansChildContextIntegrationTests` | New package test target using the build plugin, one root plus ARC/managed siblings; execute actual generated accessors/factories, singleton identity and release scenarios |
| `GeneratedChildContractCompileTests` | Compile isolated positive/negative generated-source fixtures for MainActor parents, fake protocols, cross-file use and incompatible factory types; never substitute hand-written snapshots for generator coverage |
| `ChildContextLifecycleProcessFixtures` | Separate-process precondition checks so the test runner survives traps; invocations bounded by the harness |
| Example coordinator/model tests | Login/expiry/logout state machine, user-tab factory wiring, attempt identities, fresh session/shared app repositories and release chain |

The generated-source compiler harness receives explicit compiler, runtime-module and macro-plugin paths from the test/build environment. Use local built modules/plugin, isolated temporary directories and no dependency downloads or nested build of the current package. The new integration target compiles real macro/plugin output; additional compile fixtures cover mutually exclusive root isolation shapes. Test actor-safe concurrency without introducing Sendable promises for beans merely to launch threads. The ARC concurrent-once scenario uses the existing registry synchronization fixture approach.

Async runtime tests use controllable continuation gates, counters and weak references. Verify stalled-close behavior before releasing the gate; never leave tasks permanently hung to test unsupported recursion. Factory misuse uses subprocesses. Source-parse counting and deterministic representative graph comparisons cover the structural budget without wall-clock thresholds. Root-only golden snapshots include the generator's current output and both dumps.

The following table maps every current SPEC scenario in order to its verification seam. Numbers are traceability labels here, not permanent scenario identifiers; retain the scenario title when implementing tests.

| # | Spec scenario | Verification seam |
|---|---|---|
| 1 | Child bean uses a parent bean | Generated integration + registry/lifetime fixtures |
| 2 | Child singletons are per child instance | Generated integration + registry/lifetime fixtures |
| 3 | Parent singletons are shared between children | Generated integration + registry/lifetime fixtures |
| 4 | Parent transient is recreated for child access | Generated integration + registry/lifetime fixtures |
| 5 | Context input is injectable inside the child | GeneratorChildContextTests + macro expansion + generated compile |
| 6 | Context input replaces the need for a provider | GeneratorChildContextTests + macro expansion + generated compile |
| 7 | Child created over a fake parent | Generated integration + registry/lifetime fixtures |
| 8 | Parent bean cannot depend on a child key | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 9 | Siblings cannot see each other | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 10 | Siblings may provide the same key | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 11 | Child key duplicating a parent key fails | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 12 | Missing dependency in a child names the context | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 13 | Cycle inside a child fails | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 14 | Unknown or invalid parent fails | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 15 | `in:` naming a non-context fails | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 16 | Child without a root fails | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 17 | Releasing the child releases its singletons | Generated integration + registry/lifetime fixtures |
| 18 | Child keeps its parent alive | Generated integration + registry/lifetime fixtures |
| 19 | Assisted provider owned by a child | GeneratorChildContextTests + macro expansion + generated compile |
| 20 | Per-bean `in:` overrides configuration default | GeneratorChildContextTests + macro expansion + generated compile |
| 21 | Child singleton factory runs once under concurrent access | Generated integration + registry/lifetime fixtures |
| 22 | Graphs without child contexts are unchanged | Root-only Swift/dump golden compatibility fixtures |
| 23 | Local-package provider cannot target a child | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 24 | Plain types remain manually constructible | Generated integration + registry/lifetime fixtures |
| 25 | Context inputs preserve declaration order and property names | GeneratorChildContextTests + macro expansion + generated compile |
| 26 | Root and child protocols expose their own graph | GeneratorChildContextTests + macro expansion + generated compile |
| 27 | Invalid context shapes and parent relationships fail (F1) | Shared syntax/macro diagnostics + generator failure fixtures |
| 28 | Invalid inputs fail at their declaration (F3) | Shared syntax/macro diagnostics + generator failure fixtures |
| 29 | Reserved names and accessor collisions fail (F2, F3) | Shared syntax/macro diagnostics + generator failure fixtures |
| 30 | Inputs participate in duplicate-key validation (F2) | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 31 | Invalid ownership and teardown policies fail (F3) | Shared syntax/macro diagnostics + generator failure fixtures |
| 32 | Generated output is deterministic with sibling contexts | ChildContextGraphDumpTests + deterministic generator snapshots |
| 33 | Child deferred and assisted factories use the visible owner | Generator child factory/qualifier/collection tests + generated integration |
| 34 | Parent-owned providers remain in the parent graph | Generator child factory/qualifier/collection tests + generated integration |
| 35 | Assisted and factory diagnostics apply within each context (F2) | GeneratorChildContextDiagnosticsTests; valid sibling cases in generator tests |
| 36 | Qualifiers and collections respect visible keys | Generator child factory/qualifier/collection tests + generated integration |
| 37 | Visible array provider wins over collection members | Generator child factory/qualifier/collection tests + generated integration |
| 38 | Child dump nodes retain ownership and sibling identity | ChildContextGraphDumpTests + deterministic generator snapshots |
| 39 | Invalid child graph does not publish partial output (F1, F2, F3, F4) | GenerationResult/CLI artifact-publication fixtures |
| 40 | Multiple children do not rescan all sources | Single-scan observer + representative GraphPlan/output comparisons |
| 41 | Managed isolation is preserved through fake parent and factory use | GeneratedChildContractCompileTests + managed protocol integration |
| 42 | Unsupported managed isolation fails (F4) | GeneratedChildContractCompileTests + managed protocol integration |
| 43 | Managed protocol exposes close | GeneratedChildContractCompileTests + managed protocol integration |
| 44 | Default ARC mode does not invoke cleanup (F8) | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 45 | Managed close automatically cleans up enrolled singletons | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 46 | Cleanup deduplicates object identity | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 47 | Repeated and overlapping close calls share completion (F6) | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 48 | Cancelling all waiters does not abandon cleanup (F6) | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 49 | Resolution through generated accessors fails once closing starts (F5) | Lifecycle subprocess fixtures; unsupported-recursion contract review for #56 |
| 50 | Retained child-rooted factories cannot reopen a closed graph (F5) | Lifecycle subprocess fixtures; unsupported-recursion contract review for #56 |
| 51 | Parent and inputs remain owned until child deallocation | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 52 | Escaped participating singleton is cleaned before deallocation (F7) | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 53 | Nonparticipating escaped objects are not automatically invalidated (F7) | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 54 | Unclosed managed context uses ARC without async fallback (F8) | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 55 | Suspended cleanup keeps close pending without an implicit timeout (F9) | SwiftBeansManagedRegistryTests + generated integration/lifetime fixtures |
| 56 | Cleanup resolving from its own closing child violates the lifecycle boundary (F5, F9) | Lifecycle subprocess fixtures; unsupported-recursion contract review for #56 |
| 57 | Example launch and login follow coordinator construction | Example coordinator/model/flow tests; generated integration for dependency identity |
| 58 | User tab receives its repository through the child graph | Example coordinator/model/flow tests; generated integration for dependency identity |
| 59 | Tab switching and navigation preserve the login scope | Example coordinator/model/flow tests; generated integration for dependency identity |
| 60 | Logout and expiry share one cleanup boundary (F10) | Example coordinator/model/flow tests; generated integration for dependency identity |
| 61 | Failed login creates no child (F10) | Example coordinator/model/flow tests; generated integration for dependency identity |
| 62 | Late authentication completion cannot restore an ended flow (F10) | Example coordinator/model/flow tests; generated integration for dependency identity |
| 63 | New login resets session identity and preserves app repositories | Example coordinator/model/flow tests; generated integration for dependency identity |
| 64 | Releasing the flow breaks the coordinator factory ownership chain | Example coordinator/model/flow tests; generated integration for dependency identity |

## Approval boundary and remaining implementation checks

Architecture approval authorizes Phase 3 tests, then Phase 4 implementation and required checks, followed by the independent read-only grade. It does not authorize changes to approved behavior. All 64 scenarios must receive an implementation mapping; generated-source contract coverage and example session-lifetime coverage are required.

Exact lifecycle behavior, cancellation immunity, new macro expansions, registry cleanup storage, qualified-reference identity witnesses and generated code remain unimplemented at this gate. Phase 3/4 must prove these against the approved spec. If a supported isolation or module-qualification contract cannot be delivered safely, return to the design/spec gate rather than relaxing it silently.

Quality gates: `swift test`, strict-concurrency generated-source fixtures, example macOS tests/build and iOS build under the repository's documented Xcode workflow, then independent conformance review. Do not broaden the public surface to solve a failing fixture without updating the approved contract.
