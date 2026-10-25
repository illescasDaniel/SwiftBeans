import SwiftUI

@main
struct SwiftBeansExampleApp: App {
	@State private var coordinator: AppCoordinator

	init() {
		let context = AppContext()
		_coordinator = State(initialValue: AppCoordinator(
			makeLogin: { context.loginViewModel },
			makeLoggedInFlow: { credentials in
				LoggedInFlow(context: LoggedInContext(parent: context, credentials: credentials))
			}
		))
	}

	var body: some Scene {
		WindowGroup {
			AppRootView(coordinator: coordinator)
		}
	}
}
