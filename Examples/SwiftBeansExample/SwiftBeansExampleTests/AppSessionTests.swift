import Foundation
import SwiftUI
import Testing

@testable import SwiftBeansExample

@Suite("AppSession — login lifetime")
@MainActor
struct AppSessionTests {
	@Test func `Given login success When sign in completes Then a flow is installed and logout closes it`()
		async throws
	{
		let parent = FakeAppContext()
		var sessions: [FakeLoggedInContext] = []
		let app = AppSession(
			makeLoggedInFlow: { credentials in
				let child = FakeLoggedInContext(parent: parent, credentials: credentials)
				sessions.append(child)
				return LoggedInFlow(context: child)
			})
		#expect(app.loggedIn == nil)
		#expect(sessions.isEmpty)
		await app.signIn(using: parent.loginViewModel)
		let first = try #require(app.loggedIn)
		#expect(sessions.count == 1)
		let model = sessions[0].userTabViewModel
		#expect(model.repository.catalog as AnyObject === parent.itemRepository as AnyObject)
		first.coordinator.push(.featuresDemo)
		await app.logOut()
		#expect(app.loggedIn == nil)
		#expect(model.repository.isClosed)
		#expect(sessions[0].closeCount == 1)
		await app.signIn(using: parent.loginViewModel)
		let second = try #require(app.loggedIn)
		#expect(second.id != first.id)
		#expect(second.coordinator.path.isEmpty)
		#expect(sessions[1].userRepository !== model.repository)
		#expect(sessions[1].userRepository.catalog as AnyObject === parent.itemRepository as AnyObject)
		await app.logOut()
	}

	@Test func `Given authentication failure When signing in Then no child is constructed`() async {
		let model = LoginViewModel(
			authentication: AuthenticationService(authenticate: { _ in
				throw AuthenticationService.Failure.emptyName
			}))
		var constructed = 0
		let app = AppSession(
			makeLoggedInFlow: { _ in
				constructed += 1
				return LoggedInFlow(context: FakeLoggedInContext(parent: FakeAppContext()))
			})
		await app.signIn(using: model)
		#expect(constructed == 0)
		#expect(app.loggedIn == nil)
		if case .failed = model.state {
		} else {
			Issue.record("authentication failure must remain on login with failure state")
		}
	}
	final class CloseGate {
		var entered = false
		var started: CheckedContinuation<Void, Never>?
		var pending: CheckedContinuation<Void, Never>?
		func wait() async {
			entered = true
			started?.resume()
			started = nil
			await withCheckedContinuation { pending = $0 }
		}
		func waitForEntry() async { if !entered { await withCheckedContinuation { started = $0 } } }
		func release() {
			pending?.resume()
			pending = nil
		}
	}

	final class AuthenticationGate {
		var pending: [String: CheckedContinuation<SessionCredentials, Never>] = [:]
		var started: [String: CheckedContinuation<Void, Never>] = [:]
		func request(_ name: String) async -> SessionCredentials {
			await withCheckedContinuation { continuation in
				pending[name] = continuation
				started.removeValue(forKey: name)?.resume()
			}
		}
		func waitForEntry(_ name: String) async {
			if pending[name] == nil { await withCheckedContinuation { started[name] = $0 } }
		}
		func finish(_ name: String) {
			pending.removeValue(forKey: name)?.resume(
				returning: SessionCredentials(userID: UUID(), displayName: name))
		}
	}

	@Test(arguments: [false, true])
	func
		`Given cleanup in progress When ending repeats or login is attempted Then one teardown gates another session`(
			_ expiry: Bool
		) async throws
	{
		let parent = FakeAppContext()
		let gate = CloseGate()
		var sessions: [FakeLoggedInContext] = []
		let app = AppSession(
			makeLoggedInFlow: { credentials in
				let context = FakeLoggedInContext(parent: parent, credentials: credentials)
				context.onClose = { await gate.wait() }
				sessions.append(context)
				return LoggedInFlow(context: context)
			})
		await app.signIn(using: parent.loginViewModel)
		let child = try #require(sessions.first)
		let end = Task { if expiry { await app.sessionExpired() } else { await app.logOut() } }
		await gate.waitForEntry()
		#expect(app.loggedIn == nil)
		#expect(app.isEndingSession)
		await app.logOut()
		await app.signIn(using: parent.loginViewModel)
		#expect(sessions.count == 1)
		#expect(child.closeCount == 1)
		gate.release()
		await end.value
		#expect(!app.isEndingSession)
	}

	@Test func `Given a superseded login When its result arrives after logout Then no old flow is restored`() async
	{
		let parent = FakeAppContext()
		let gate = AuthenticationGate()
		let auth = AuthenticationService(authenticate: { await gate.request($0) })
		var constructed = 0
		let app = AppSession(
			makeLoggedInFlow: { credentials in
				constructed += 1
				return LoggedInFlow(
					context: FakeLoggedInContext(parent: parent, credentials: credentials))
			})
		let firstModel = LoginViewModel(authentication: auth)
		firstModel.name = "old"
		let first = Task { await app.signIn(using: firstModel) }
		await gate.waitForEntry("old")
		let secondModel = LoginViewModel(authentication: auth)
		secondModel.name = "new"
		let second = Task { await app.signIn(using: secondModel) }
		await gate.waitForEntry("new")
		gate.finish("new")
		await second.value
		#expect(app.loggedIn != nil)
		await app.logOut()
		gate.finish("old")
		await first.value
		#expect(app.loggedIn == nil)
		#expect(constructed == 1)
		#expect(firstModel.state == .idle)
	}

	@Test func `Given a pending login When session ending invalidates it Then a late success creates no flow`()
		async
	{
		let gate = AuthenticationGate()
		let model = LoginViewModel(
			authentication: AuthenticationService(authenticate: { await gate.request($0) }))
		model.name = "pending"
		var constructed = 0
		let app = AppSession(
			makeLoggedInFlow: { _ in
				constructed += 1
				return LoggedInFlow(context: FakeLoggedInContext(parent: FakeAppContext()))
			})
		let login = Task { await app.signIn(using: model) }
		await gate.waitForEntry("pending")
		await app.logOut()
		gate.finish("pending")
		await login.value
		#expect(constructed == 0)
		#expect(app.loggedIn == nil)
	}

	@Test
	func
		`Given outgoing user model When flow ends Then cleanup occurs and escaped ownership alone keeps the repository alive`()
		async throws
	{
		let parent = FakeAppContext()
		weak var weakContext: FakeLoggedInContext?
		let app = AppSession(
			makeLoggedInFlow: { credentials in
				let child = FakeLoggedInContext(parent: parent, credentials: credentials)
				weakContext = child
				return LoggedInFlow(context: child)
			})
		await app.signIn(using: parent.loginViewModel)
		var model: UserTabViewModel? = try #require(weakContext).userTabViewModel
		weak let repository = model?.repository
		weak let coordinator = app.loggedIn?.coordinator
		await app.logOut()
		#expect(weakContext == nil)
		#expect(coordinator == nil)
		#expect(repository?.isClosed == true)
		model = nil
		#expect(repository == nil)
	}

}
