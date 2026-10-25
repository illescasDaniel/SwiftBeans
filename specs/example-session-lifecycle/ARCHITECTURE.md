# Example session lifecycle — architecture

## Authority

- Design: [DESIGN.md](../../design/example-session-lifecycle/DESIGN.md), approved 2026-10-25, including separate composition with injected actions.
- Spec: [SPEC.md](SPEC.md), amended spec approved in chat 2026-10-25.
- Architecture: revised Phase 2 approved in chat 2026-10-25.
- Scope: internal example types and tests; no library, macro, generator or plugin changes.

## Contracts and dependency direction

All declarations below are internal proposed signatures in `SwiftBeansExample`, not production
implementations. Preserve existing Swift language mode and MainActor isolation.

```swift
@Observable
@MainActor
final class AppSession {
	init(makeLoggedInFlow: @escaping @MainActor (SessionCredentials) -> LoggedInFlow)
	var loggedIn: LoggedInFlow? { get }
	var isEndingSession: Bool { get }
	func signIn(using model: LoginViewModel) async
	func logOut() async
	func sessionExpired() async
}

@MainActor
final class AppCoordinator {
	private let makeLogin: @MainActor () -> LoginViewModel
	private let signIn: @MainActor (LoginViewModel) async -> Void

	init(
		makeLogin: @escaping @MainActor () -> LoginViewModel,
		signIn: @escaping @MainActor (LoginViewModel) async -> Void
	)
	// Existing @ViewBuilder build(_ route: AppRoute) -> some View remains.
}

struct AppRootView: View {
	let coordinator: AppCoordinator
	let session: AppSession
}

struct LoggedInNavigationView: View {
	@Environment(LoggedInCoordinator.self) private var coordinator
	let onLogOut: @MainActor () async -> Void
	let onSessionExpired: @MainActor () async -> Void
}
```

`AppSession.swift` belongs beside `LoggedInFlow.swift` in Navigation and imports Foundation and
Observation, with no SwiftUI or SwiftBeans dependency. `AppCoordinator` keeps SwiftUI screen
construction, passes `signIn` unchanged to `LoginView`'s existing `onSubmit` initializer parameter,
and stores no session reference, lifecycle state or forwarding members. Remove its `@Observable`
annotation: all its own dependencies are immutable.

### Composition and UI actions

`SwiftBeansExampleApp` retains session and coordinator in separate `@State` properties, initialized
from one root `AppContext`. Construct both once in app initialization, not during body evaluation:

```swift
let session = AppSession(makeLoggedInFlow: { credentials in
	LoggedInFlow(context: LoggedInContext(parent: context, credentials: credentials))
})
let coordinator = AppCoordinator(
	makeLogin: { context.loginViewModel },
	signIn: { model in await session.signIn(using: model) }
)
// Initialize each @State backing property, then render:
AppRootView(coordinator: coordinator, session: session)
```

`AppRootView` reads `session.loggedIn` and `session.isEndingSession` directly; neither reference
needs `@Bindable` because the root does not write through a binding. When signed in it constructs:

```swift
LoggedInNavigationView(
	onLogOut: { await session.logOut() },
	onSessionExpired: { await session.sessionExpired() }
)
.environment(flow.coordinator)
.id(flow.id)
```

The existing toolbar buttons launch tasks invoking their supplied actions. Remove the root
`AppCoordinator` environment lookup and root `.environment(coordinator)` injection. Retain the
child coordinator environment and its local `@Bindable` for path/tab bindings. Login presentation
continues to call `coordinator.build(.login)` and is disabled while session cleanup is in progress.
`LoginView` keeps its existing `onSubmit` action and view-owned model; no new view abstraction or
session dependency is added to that screen or the signed-in navigation view.

The sign-in closure strongly captures the session. This is intentional: the app also retains
that session, and the session never references the root coordinator. The session's flow factory
captures the app context; child factories capture their child context. No root provider acquires
an implicit child dependency and no generated factory or service registration is added.

## State and ownership

`AppSession` stores its flow factory and one observable private state, initially signed out:

```swift
private enum State {
	case signedOut
	case authenticating(LoginAttempt)
	case active(LoggedInFlow)
	case ending(LoggedInFlow)
}
```

`LoginAttempt` is a private value nested in `AppSession`, containing an immutable UUID, the model
and `Task<SessionCredentials?, Never>`. Its MainActor cancellation operation resets the model and
cancels the task. It is not independently observable and is never retained in a collection.
An attempt identity grants permission to install a flow; `LoginViewModel`'s separate identity
grants permission to update that model's presentation. Document this distinction at those seams.

`loggedIn` returns the flow only for active state. `isEndingSession` is true only for ending state.
The root view reads these properties directly from its session. Observation tracks session state
without an observable coordinator or forwarding properties. Verify this with
`withObservationTracking` on the session; do not introduce mirrored state.

The active/ending flow owns its existing coordinator → factories → child-context chain. The
session's factory captures only app-lifetime composition dependencies, never an outgoing flow.
Ended flows and completed attempts are removed from state; suspended obsolete call frames may
retain their own attempts until the underlying service returns. No forceful ARC guarantees are added.

## Transition algorithm and suspension boundaries

### Sign-in

1. Switch on state. Active and ending return without touching the supplied model. Signed out
   admits a request; authenticating cancels its previous attempt before admitting the replacement.
2. Construct one unstructured MainActor task for authentication and publish its attempt as the
   authenticating state before awaiting its value. The task checks its cancellation before calling
   `model.authenticate()` so a cancelled task that has not begun cannot start a stale model request.
   Actor isolation ensures task creation and state publication finish before that task runs.
3. Await the task value. No caller cancellation handler cancels the owned task, preserving the
   approved independence of caller and authentication lifetimes.
4. After the await, require authenticating state with the same attempt UUID. An obsolete completion
   returns without resetting any model or state. If the current result is nil, become signed out
   without cancelling/resetting the model again, preserving its failure or cancellation presentation.
5. For current credentials, invoke the synchronous nonthrowing flow factory once and become active.
   No suspension separates the identity check, factory call and active-state publication.

### Logout and expiry

- Signed out: return.
- Authenticating: invalidate state to signed out, cancel the captured attempt and return. Late
  results fail the admission check. No asynchronous cleanup exists before flow construction.
- Active: capture the flow, publish ending state, then await `flow.close()`. After completion become
  signed out. The state and local reference retain the flow for the duration of cleanup.
- Ending: return immediately, retaining the original ending state and operation.

`sessionExpired()` delegates to `logOut()`. No second task is created around cleanup; the managed
context already provides cancellation-independent cleanup completion. Cancelling the initiating
caller does not bypass the final signed-out transition. No competing operation can install another
flow while ending, so cleanup completion cannot overwrite a newer session.

`LoggedInFlow`, `LoginViewModel`, generated contexts, managed registry and screen factories retain
their current responsibilities. No public protocol, generic task abstraction or use-case layer is needed.

## Files and migration

| File or area | Change |
|---|---|
| `Navigation/AppSession.swift` | New observable lifecycle owner and private state/attempt values |
| `Navigation/AppCoordinator.swift` | Keep model factory and injected sign-in action; remove session policy and observation |
| `Navigation/AppNavigationView.swift` | Root receives session separately; signed-in view receives logout/expiry actions; remove root coordinator environment dependency |
| `SwiftBeansExampleApp.swift` | Retain session/coordinator separately; wire one shared session into actions and root presentation |
| Example tests constructing AppCoordinator | Use action injection; move lifecycle tests to AppSession |
| `AppSessionTests.swift` | Direct lifecycle, cancellation, observation and ownership coverage with existing child fakes |
| `AppCoordinatorTests.swift` | Screen factory construction and action composition coverage |
| Child-context spec/architecture | Apply approved ownership amendment while retaining original verification evidence |

Use existing Xcode source-discovery conventions and verify new target membership through the
example build. No package manifest change is required.

## Scenario-to-test map

Use Swift Testing and assert observable behavior instead of inspecting private state. Existing
coordinator lifecycle tests move to the session seam, with composition checks retained separately.

| Approved scenario | Planned assertions and test seam |
|---|---|
| Launch constructs no child | Compose root/session/coordinator, build login, assert zero flow calls and signed-out session values |
| Current authentication succeeds | Exact credentials, one flow call, installed identity |
| Authentication fails | No flow, failed model state, subsequent retry admitted |
| Authentication reports cancellation | Idle model, no flow, subsequent retry admitted |
| A newer login supersedes an older one | Gated obsolete task observes cancellation, old model idle, late result rejected |
| Reusing the same login model preserves the newest request | Distinct request IDs; old completion during replacement loading, after failure and after success cannot overwrite current presentation |
| Logout or expiry invalidates pending login | Parameterized logout/expiry, cancellation observed, model idle, late success rejected |
| Ending hides the flow before cleanup finishes | Suspended cleanup, outgoing flow weak reference alive, session presentation changes, initiating call remains suspended |
| Repeated ending requests do not duplicate cleanup | Logout/expiry combinations return before gate release; close counter stays one |
| Sign-in cannot enter an active or ending session | No authentication or factory call; supplied model and existing session preserved |
| Cleanup completion permits a fresh login | Fresh flow/context/coordinator/repository, reset navigation, stable app repository |
| Logout while signed out is harmless | Repeated logout/expiry creates/closes nothing |
| Caller cancellation preserves independently owned authentication | Cancel caller while gated; service task remains uncancelled and success installs a flow |
| Caller cancellation does not abandon cleanup | Cancel initiating caller, release cleanup, assert one completion and signed-out state |
| Session ownership releases after cleanup | Weak flow/context/coordinator release; escaped model keeps cleaned repository until released; completed attempt model released after call returns |
| Separate composition preserves observation and injected actions | Track session directly before activation/ending/completion; callback checks on concrete LoginView and LoggedInNavigationView; composition wiring inspection and example build confirm coordinator forwards injected action into login and root wires the same session |

Continuation gates support distinct requests even when a model/name is reused. Capture
`Task.isCancelled` inside the service after releasing each gate; stale-result rejection alone does
not prove cancellation. Drain every suspended request. Re-register one-shot Observation tracking
between transitions and use concurrency-safe callback counters. Test supplied view callbacks
through their stored internal actions without executing SwiftUI body outside a host. Do not add
reflection, UI tests or production accessors solely to extract an opaque coordinator-built view.
The final reviewer also inspects app/root/coordinator wiring against these contracts.

## Test-first execution and gates

After architecture approval, read the modernize-tests skill. Add a minimal compilable session
scaffold with the approved interface and adapt composition/tests before implementing transitions.
Run focused behavioral tests and record intended assertion failures; missing symbols or compiler
errors are not red-phase evidence. Replace the scaffold with the full implementation before final
verification. Behavioral preservation tests need not fail against the completed baseline; the new
session contract must compile and fail meaningfully against its unimplemented scaffold.

Run `swift test`, macOS example tests and a generic iOS Simulator build. Record scenario mapping
and outcomes in verification evidence, then have an independent read-only reviewer grade against
the approved artifacts and conventions. Resolve findings and rerun affected gates. This approval
does not request another commit, push, version, tag or release.
