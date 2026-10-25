import SwiftUI

@MainActor
final class AppCoordinator {
	private let makeLogin: @MainActor () -> LoginViewModel
	private let signIn: @MainActor (LoginViewModel) async -> Void

	init(
		makeLogin: @escaping @MainActor () -> LoginViewModel,
		signIn: @escaping @MainActor (LoginViewModel) async -> Void
	) {
		self.makeLogin = makeLogin
		self.signIn = signIn
	}

	@ViewBuilder func build(_ route: AppRoute) -> some View {
		switch route {
		case .login:
			LoginView(viewModel: makeLogin(), onSubmit: signIn)
		}
	}
}

enum AppRoute { case login }
