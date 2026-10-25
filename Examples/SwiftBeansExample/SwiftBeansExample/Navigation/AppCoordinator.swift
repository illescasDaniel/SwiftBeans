import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppCoordinator {
	private let makeLogin: @MainActor () -> LoginViewModel
	private let makeLoggedInFlow: @MainActor (SessionCredentials) -> LoggedInFlow
	private(set) var loggedIn: LoggedInFlow?
	private(set) var isEndingSession = false
	private var attempt: UUID?
	private var loginTask: Task<SessionCredentials?, Never>?
	private var pendingModel: LoginViewModel?

	init(
		makeLogin: @escaping @MainActor () -> LoginViewModel,
		makeLoggedInFlow: @escaping @MainActor (SessionCredentials) -> LoggedInFlow
	) {
		self.makeLogin = makeLogin
		self.makeLoggedInFlow = makeLoggedInFlow
	}

	func signIn(using model: LoginViewModel) async {
		guard loggedIn == nil, !isEndingSession else { return }
		pendingModel?.cancelAuthentication()
		loginTask?.cancel()
		let identity = UUID()
		attempt = identity
		pendingModel = model
		let operation = Task { await model.authenticate() }
		loginTask = operation
		let credentials = await operation.value
		guard attempt == identity else { return }
		attempt = nil
		pendingModel = nil
		loginTask = nil
		guard !isEndingSession, loggedIn == nil, let credentials else { return }
		loggedIn = makeLoggedInFlow(credentials)
	}

	func logOut() async {
		attempt = nil
		pendingModel?.cancelAuthentication()
		pendingModel = nil
		loginTask?.cancel()
		loginTask = nil
		guard let flow = loggedIn else { return }
		isEndingSession = true
		loggedIn = nil
		await flow.close()
		isEndingSession = false
	}
	func sessionExpired() async { await logOut() }

	@ViewBuilder func build(_ route: AppRoute) -> some View {
		switch route {
		case .login:
			LoginView(viewModel: makeLogin()) { [weak self] model in await self?.signIn(using: model) }
		}
	}
}

enum AppRoute { case login }
