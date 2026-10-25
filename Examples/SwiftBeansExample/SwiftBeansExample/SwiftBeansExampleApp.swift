import SwiftUI

@main
struct SwiftBeansExampleApp: App {
	@State private var coordinator: AppCoordinator
	@State private var session: AppSession

	init() {
		let context = AppContext()
		let session = AppSession(makeLoggedInFlow: { credentials in
			LoggedInFlow(context: LoggedInContext(parent: context, credentials: credentials))
		})
		_session = State(initialValue: session)
		_coordinator = State(initialValue: AppCoordinator(
			makeLogin: { context.loginViewModel },
			signIn: { model in await session.signIn(using: model) }
		))
	}

	var body: some Scene {
		WindowGroup {
			AppRootView(coordinator: coordinator, session: session)
		}
	}
}
