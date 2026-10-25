# Example session lifecycle

## Status and scope

- Date: 2026-10-25.
- Phase 0 design approved in chat on 2026-10-25. Revised design selected explicitly in chat: app-owned session and coordinator composed separately, with injected actions.
- Example application only. No library API, generated output, package version or release changes.
- Follow-up to completed child contexts A1/A2, committed as `68bae10`.

## Problem

`AppCoordinator.signIn(using:)` manages authentication task ownership, cancellation, attempt identity,
view-model reset, session admission and flow construction. `logOut()` invalidates authentication,
removes the visible flow and awaits managed cleanup. Three optional authentication fields plus a
flow and a Boolean represent the lifecycle implicitly. `LoginViewModel` also tracks an attempt,
for the separate purpose of preventing outdated authentication from updating presentation state.

The concurrency protections are necessary; their placement makes the example harder to understand.
Merely extracting private helpers would leave session policy inside the navigation coordinator.

## Proposed responsibilities

Introduce one example-local, MainActor-isolated observable `AppSession` beside `LoggedInFlow`.
It owns session transitions and the injected `(SessionCredentials) -> LoggedInFlow` factory.
`AppCoordinator` owns screen factories and an injected asynchronous sign-in action. It has no
`AppSession` property or session presentation/action members.
`LoggedInFlow` continues to own the child context and transient child coordinator, and remains the
boundary for `close()`. Views continue to receive view models and coordinators, never DI contexts.

Represent session lifetime with a single private state:

| State | Owned data | Allowed transitions |
|---|---|---|
| Signed out | None | Authenticating |
| Authenticating | One attempt containing identity, model and task | Replacement attempt, signed out, active |
| Active | LoggedInFlow | Ending |
| Ending | Outgoing flow retained until close completes | Signed out |

Expose the active flow and ending flag as derived read-only presentation values on `AppSession`.
`AppRootView` receives the session and coordinator separately. It reads `session.loggedIn` and
`session.isEndingSession` and passes logout/expiry callbacks into `LoggedInNavigationView`.
The coordinator passes its injected sign-in action to `LoginView`. The signed-in navigation view
needs only its existing child coordinator environment and callbacks, with no root coordinator
environment reference.

The attempt is one private value, with a single cancellation operation that cancels its task and
resets its model. This replaces independently mutable `attempt`, `pendingModel` and `loginTask`.
Attempt identity still guards the result after suspension. `LoginViewModel` retains its local
request identity because it protects its own observable loading/error state even when used directly;
the two identities have distinct purposes and should be documented rather than conflated.

## Transition rules

1. Sign-in is admitted only while signed out or authenticating. Replacing an attempt invalidates
   and cancels the previous attempt before publishing the replacement.
2. Authentication failure creates no child context and leaves the model's error visible.
3. A result installs a flow only when its attempt is still current. Cancellation alone is
   insufficient because authentication may ignore it.
4. Logout or expiry invalidates any pending attempt. From an active session, move to ending
   synchronously, hiding the outgoing flow before awaiting `LoggedInFlow.close()`.
5. While ending, reject sign-in. Repeated logout/expiry returns without initiating another close,
   preserving the current example's behavior; only the original ending call awaits cleanup.
6. Retain the outgoing flow through cleanup, then return to signed out. A subsequent sign-in
   creates a fresh child context and navigation coordinator.

All transitions execute on MainActor. Authentication and cleanup can suspend, so state must be
established before every await and checked after authentication returns. Preserve existing caller
cancellation semantics in this refactor; changing them needs a separate behavioral decision.

## Dependency direction and composition

`SwiftBeansExampleApp` constructs and retains `AppSession` and `AppCoordinator` separately. It
supplies the flow factory to the session and a sign-in closure capturing the session to the
coordinator. `AppRootView` receives both objects; logout/expiry callbacks capture the same session.
`AppSession` depends on credentials, `LoginViewModel` and `LoggedInFlow`; it does not resolve
dependencies or import SwiftUI. Screen construction stays in `AppCoordinator`. The injected
sign-in closure may retain the session, but the session has no reference back to the root
coordinator, so this creates no ownership cycle.
The library runtime, macros, generator and plugin are untouched.

## Alternatives

- Private coordinator helper methods: fewer lines per method, but lifecycle ownership stays mixed
  with navigation and the independently mutable fields remain.
- Perform authentication in the view and pass credentials to the coordinator: weakens the central
  protection against a late success after logout unless another admission mechanism is added.
- Put lifecycle logic in `LoggedInFlow`: a flow exists only after successful authentication, so it
  cannot own pending sign-in or the transition between sessions.

The proposed session owner adds one type and one explicit state representation. Do not add a
protocol, generic task manager, event bus or separate use-case types for this example.

## Validation and compatibility

Retain coordinator integration coverage for successful login, failure, supersession, late results
after logout, logout/expiry during suspended cleanup, fresh navigation and ownership release.
Exercise transition details directly through `AppSession` tests, using continuation gates rather
than timing assumptions. Keep coordinator tests focused on action injection/composition instead of
repeating all session tests. Run macOS example tests and an iOS Simulator build after implementation;
run package tests if package code or configuration changes.

No user-visible behavior is intentionally changed. Existing child-context acceptance criteria
remain requirements; later spec/architecture artifacts must identify any ownership wording that
needs an approved amendment before implementation.

## Approval requested

The user selected separate composition and injected actions in chat. The amended spec and then
the revised architecture each require approval before production changes.
