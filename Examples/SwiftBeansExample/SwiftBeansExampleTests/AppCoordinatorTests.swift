import Testing

@testable import SwiftBeansExample

@Suite("AppCoordinator — composition")
@MainActor
struct AppCoordinatorTests {
	@Test func `Given injected factories When building login Then no child is created`() {
		let parent = FakeAppContext()
		var models = 0
		var actions = 0
		var flows = 0
		let session = AppSession(makeLoggedInFlow: { _ in
			flows += 1
			return LoggedInFlow(context: FakeLoggedInContext(parent: parent))
		})
		let coordinator = AppCoordinator(
			makeLogin: { models += 1; return parent.loginViewModel },
			signIn: { _ in actions += 1 }
		)
		_ = coordinator.build(.login)
		_ = AppRootView(coordinator: coordinator, session: session)
		#expect(models == 1)
		#expect(actions == 0)
		#expect(flows == 0)
		#expect(session.loggedIn == nil)
		#expect(!session.isEndingSession)
	}

	@Test func `Given session actions When screen callbacks run Then they operate on the composed session`() async {
		let parent = FakeAppContext()
		var children: [FakeLoggedInContext] = []
		let session = AppSession(makeLoggedInFlow: { credentials in
			let child = FakeLoggedInContext(parent: parent, credentials: credentials)
			children.append(child)
			return LoggedInFlow(context: child)
		})
		let login = LoginView(viewModel: parent.loginViewModel, onSubmit: { await session.signIn(using: $0) })
		let navigation = LoggedInNavigationView(
			onLogOut: { await session.logOut() },
			onSessionExpired: { await session.sessionExpired() }
		)
		await login.onSubmit(parent.loginViewModel)
		#expect(session.loggedIn != nil)
		await navigation.onLogOut()
		#expect(session.loggedIn == nil)
		#expect(children[0].closeCount == 1)
		await login.onSubmit(parent.loginViewModel)
		#expect(session.loggedIn != nil)
		await navigation.onSessionExpired()
		#expect(session.loggedIn == nil)
		#expect(children.count == 2)
		#expect(children[1].closeCount == 1)
	}
}
