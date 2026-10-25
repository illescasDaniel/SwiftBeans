# Example session lifecycle

## Metadata

- **Feature:** Simplify example authentication and logout ownership with an explicit session lifecycle.
- **System design:** [DESIGN.md](../../design/example-session-lifecycle/DESIGN.md).
- **Design approved:** 2026-10-25 (chat), including explicit selection of separate composition with injected actions.
- **Design decisions approved:** 2026-10-25 (chat, spec approval).
- **Spec approved:** 2026-10-25 (chat), including separate-composition/action-injection amendment.
- **Architecture approved:** 2026-10-25 (chat); [ARCHITECTURE.md](ARCHITECTURE.md).
- **Related:** [Child contexts](../child-contexts/SPEC.md), completed in `68bae10`.

## Design decisions

### Success criteria

An example-local `AppSession` owns authentication attempts, admission and flow teardown with one
explicit lifecycle state. `AppCoordinator` constructs screens and receives an asynchronous sign-in action. The app composes
and retains coordinator and session separately; the coordinator has no session property. Preserve existing login, error, navigation, cleanup and ownership
behavior while eliminating independently mutable coordinator lifecycle fields.

### Failure handling

Authentication errors remain on `LoginViewModel` and construct no child. Superseded or invalidated
attempts cannot publish a flow or overwrite the current model state. Cleanup is nonthrowing and
awaited; no timeout or forced completion is added. Repeated ending requests return without starting
another cleanup. Cancellation of a sign-in caller alone does not cancel the separately owned
authentication task; session replacement or ending cancels that task explicitly, as today.

### Performance and resource budget

One current authentication attempt or one active/ending flow is retained by the session. Invalidated
tasks can remain suspended until their authentication implementation returns; cancellation cannot
force a noncooperative operation to finish. No history of attempts, polling, timer, extra cleanup
task, event bus or global singleton is introduced. Transition bookkeeping is constant-size.
No absolute timing budget applies to externally controlled authentication or cleanup.

### Trust boundary

Credentials come from the existing injected `AuthenticationService`; this change adds no network,
persistence or credential validation. A successful result is admitted only when its attempt is still
current. DI contexts are constructed at the app composition boundary, retained by `LoggedInFlow`
and never passed to views. Session transitions and presentation reads are MainActor-isolated.

### Compatibility and rollout

Example-only internal refactor; no public library API, generated output, supported-platform or Swift
language-mode change. Move presentation reads to the root view's session and inject session actions into screen construction and signed-in UI; preserve SwiftUI observation.
Update example construction sites and tests together. No package version, tag, release or push is
part of this work. Existing child-context lifetime contracts continue to apply.

## Public API and contracts

There is no new public package API. The example introduces one internal observable MainActor
`AppSession` with these behavioral responsibilities:

- Receives the flow factory `(SessionCredentials) -> LoggedInFlow` at composition time.
- Exposes the active flow and whether cleanup is in progress as derived read-only presentation values.
- Handles sign-in, logout and session expiry through the same session lifecycle.
- Uses one private state: signed out, authenticating, active or ending. Authenticating owns one
  attempt value containing its identity, model and task; active/ending owns the appropriate flow.
- Installs state before suspension and verifies attempt identity after authentication returns.
- Resets the invalidated model and cancels its task through one attempt cancellation operation.
- Retains the outgoing flow through awaited cleanup, hiding it from presentation immediately.

`AppCoordinator` retains its login model factory and an injected
`@MainActor (LoginViewModel) async -> Void` sign-in action. Its login screen passes that action
to the existing `LoginView.onSubmit` callback. It declares no session property, session action
methods or forwarding presentation properties. All its own dependencies are immutable, so it
needs no `@Observable` conformance.

The app entry point composes and retains the session and coordinator separately. Its injected
sign-in action calls that session's `signIn(using:)`. `AppRootView` receives both objects, reads
`session.loggedIn` and `session.isEndingSession`, and passes asynchronous MainActor logout and
expiry callbacks to `LoggedInNavigationView`. Those callbacks call the same session's `logOut()`
and `sessionExpired()`. The signed-in view no longer reads a root coordinator from the environment.
Keep the child `LoggedInCoordinator` environment for signed-in navigation and screen factories.
Observation follows `AppSession` directly; coordinator observation or mirrored session state is
unnecessary. A closure may retain the session, which must not retain the root coordinator.


`LoginViewModel` retains its local request identity for presentation protection. `LoggedInFlow`
continues to own the child context and transient coordinator and delegate `close()` to the context.
The root app context and shared repositories keep their current lifetime.

### Amendment to the completed child-context example contract

Approval of this amended spec approves a narrow replacement of the example composition paragraph
in `specs/child-contexts/SPEC.md` and corresponding architecture wording: the app entry point
supplies the manual flow factory to `AppSession`, composes `AppCoordinator` with its login model
factory and injected sign-in action, and supplies both objects separately to `AppRootView`.
The app retains the session; the session owns the flow. The coordinator has no session property.
Existing fresh child construction, transient child coordinator, explicit cleanup and factory-built
screen requirements remain in force. Update the older wording after approval; this amendment
does not retroactively alter the completed feature's recorded verification.

## Acceptance criteria

### Scenario: Launch constructs no child

**Given** a newly composed root coordinator and session
**When** the login screen is built
**Then** no flow factory has run, `loggedIn` is nil and `isEndingSession` is false.

### Scenario: Current authentication succeeds

**Given** a signed-out session and login model
**When** sign-in returns credentials for the current attempt
**Then** the factory receives those credentials once and the resulting flow becomes active.

### Scenario: Authentication fails (F1)

**Given** a signed-out session and authentication that throws a non-cancellation error
**When** sign-in completes
**Then** no flow is constructed, the session is signed out and the model retains its failure state.

### Scenario: Authentication reports cancellation (F2)

**Given** a current authentication operation that throws `CancellationError`
**When** sign-in completes
**Then** no flow is constructed, the session is signed out and the model returns to idle.

### Scenario: A newer login supersedes an older one (F3)

**Given** an authentication attempt suspended in a controllable service
**When** a second sign-in replaces it and the old service later returns success despite cancellation
**Then** the old task has been cancelled, its model is idle and its result cannot install a flow
or change the replacement attempt's presentation state.

### Scenario: Reusing the same login model preserves the newest request (F3)

**Given** a pending attempt and the same model used for a replacement attempt
**When** the obsolete request returns after the replacement has started
**Then** the obsolete request cannot reset or overwrite the replacement's loading, failure or success state.

### Scenario: Logout or expiry invalidates pending login (F4)

**Given** a pending authentication attempt
**When** logout or expiry invalidates it and the service later returns success despite cancellation
**Then** the attempt task is cancelled, the model is idle, no flow is constructed and login remains presented.

### Scenario: Ending hides the flow before cleanup finishes

**Given** an active flow with cleanup suspended at a controllable gate
**When** logout or expiry begins
**Then** `loggedIn` becomes nil and `isEndingSession` becomes true before cleanup completes,
the outgoing flow stays alive and the initiating ending call remains suspended until cleanup finishes.

### Scenario: Repeated ending requests do not duplicate cleanup (F5)

**Given** an ending session with cleanup suspended
**When** another logout or expiry request arrives
**Then** that request returns without starting another close, the session remains ending and the
original ending call still waits for cleanup.

### Scenario: Sign-in cannot enter an active or ending session (F6)

**Given** an active session or a session whose cleanup is suspended
**When** sign-in is requested
**Then** the supplied model is not authenticated, no replacement flow is constructed and the
existing session state is preserved.

### Scenario: Cleanup completion permits a fresh login

**Given** an ending session
**When** cleanup finishes and a subsequent sign-in succeeds
**Then** the ending flag clears, a fresh flow/context/coordinator and session repository are
created, navigation is reset and the app repository retains its identity.

### Scenario: Logout while signed out is harmless

**Given** a signed-out session without a pending attempt
**When** logout or expiry is requested repeatedly
**Then** no flow is constructed or closed and the presentation remains signed out.

### Scenario: Caller cancellation preserves independently owned authentication

**Given** sign-in is waiting for its independently owned authentication task
**When** the calling task is cancelled without replacement or session ending and authentication succeeds
**Then** caller cancellation alone does not invalidate the attempt and the current success installs its flow.

### Scenario: Caller cancellation does not abandon cleanup

**Given** the initiating logout or expiry call is waiting on suspended managed cleanup
**When** its calling task is cancelled and cleanup is subsequently released
**Then** cleanup completes once and the session returns to signed out with the ending flag cleared.

### Scenario: Session ownership releases after cleanup

**Given** an active flow whose context is retained by its transient coordinator's factories
**When** the session ends and outgoing views/tasks release their references
**Then** the session retains no completed attempt or ended flow and weak references to solely
session-owned context, coordinator and repositories become nil; escaped models keep only their
own dependencies alive, with managed cleanup already completed.

### Scenario: Separate composition preserves observation and injected actions

**Given** a root view receiving coordinator and session separately, a coordinator with an injected
sign-in action and a signed-in view with injected logout/expiry callbacks
**When** login submission invokes that action and logout or expiry transitions the session through ending to signed out
**Then** each action reaches the same session, observation reports its changed presentation values,
the signed-in subtree uses the flow identity, the signed-in view requires no root coordinator
environment, and coordinator-built screens still use injected factories without receiving a context.

## Verification requirements

Use Swift Testing with controllable continuations and counters for suspended operations; no sleeps
or wall-clock timing assertions. Cover replacement and invalidation with noncooperative authentication,
and test Swift Observation directly through the root view's session. Session tests cover lifecycle
policy; integration tests cover injected action delivery, separate composition and representative ownership flows.

Run `swift test` as the repository quality gate, macOS example tests and a generic iOS Simulator
build. Perform independent read-only grading against approved artifacts after implementation.

## Out of scope

- Library runtime, macros, generator, plugin, managed-registry semantics or public API changes.
- Real authentication, persistence, credential revocation, automatic expiry detection or retries.
- Awaiting shared completion from repeated coordinator logout calls, timeouts or forced cancellation.
- A generic lifecycle framework, new protocols, use-case layers or dependency containers in views.
- UI redesign, new UI-test infrastructure or changing caller cancellation semantics.
