import Foundation
import Observation

/// Owns authentication admission and the managed lifetime of the current flow.
@Observable
@MainActor
final class AppSession {
	private enum State {
		case signedOut
		case authenticating(LoginAttempt)
		case active(LoggedInFlow)
		case ending(LoggedInFlow)
	}

	/// This identity admits a flow; the model's request identity protects its own presentation.
	private struct LoginAttempt {
		let id = UUID()
		let model: LoginViewModel
		let task: Task<SessionCredentials?, Never>

		func cancel() {
			model.cancelAuthentication()
			task.cancel()
		}
	}

	private let makeLoggedInFlow: @MainActor (SessionCredentials) -> LoggedInFlow
	private var state = State.signedOut

	init(makeLoggedInFlow: @escaping @MainActor (SessionCredentials) -> LoggedInFlow) {
		self.makeLoggedInFlow = makeLoggedInFlow
	}

	var loggedIn: LoggedInFlow? {
		guard case .active(let flow) = state else { return nil }
		return flow
	}

	var isEndingSession: Bool {
		if case .ending = state { return true }
		return false
	}

	func signIn(using model: LoginViewModel) async {
		switch state {
		case .active, .ending:
			return
		case .authenticating(let previous):
			previous.cancel()
		case .signedOut:
			break
		}

		// Session ownership, rather than the submitting caller, controls cancellation.
		let attempt = LoginAttempt(model: model, task: Task {
			guard !Task.isCancelled else { return nil }
			return await model.authenticate()
		})
		state = .authenticating(attempt)
		let credentials = await attempt.task.value
		guard case .authenticating(let current) = state, current.id == attempt.id else { return }
		if let credentials {
			state = .active(makeLoggedInFlow(credentials))
		} else {
			state = .signedOut
		}
	}

	func logOut() async {
		switch state {
		case .signedOut, .ending:
			return
		case .authenticating(let attempt):
			state = .signedOut
			attempt.cancel()
		case .active(let flow):
			state = .ending(flow)
			await flow.close()
			state = .signedOut
		}
	}

	func sessionExpired() async {
		await logOut()
	}
}
