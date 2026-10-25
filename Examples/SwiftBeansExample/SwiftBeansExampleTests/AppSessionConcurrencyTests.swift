import Foundation
import Observation
import Synchronization
import Testing

@testable import SwiftBeansExample

@Suite("AppSession — concurrency boundaries")
@MainActor
struct AppSessionConcurrencyTests {
	final class AuthenticationGate {
		private var nextID = 0
		private var requests: [Int: CheckedContinuation<SessionCredentials, any Error>] = [:]
		private var entries: [Int: CheckedContinuation<Void, Never>] = [:]
		private(set) var cancelled: [Int: Bool] = [:]

		func request() async throws -> SessionCredentials {
			let id = nextID
			nextID += 1
			do {
				let result = try await withCheckedThrowingContinuation { continuation in
					requests[id] = continuation
					entries.removeValue(forKey: id)?.resume()
				}
				cancelled[id] = Task.isCancelled
				return result
			} catch {
				cancelled[id] = Task.isCancelled
				throw error
			}
		}

		func waitForEntry(_ id: Int) async {
			if requests[id] == nil { await withCheckedContinuation { entries[id] = $0 } }
		}
		func finish(_ id: Int, failure: Bool = false) {
			let request = requests.removeValue(forKey: id)
			if failure { request?.resume(throwing: AuthenticationService.Failure.emptyName) }
			else { request?.resume(returning: .preview) }
		}
	}

	func makeSession() -> AppSession {
		AppSession(makeLoggedInFlow: { credentials in
			LoggedInFlow(context: FakeLoggedInContext(parent: FakeAppContext(), credentials: credentials))
		})
	}

	@Test(arguments: [0, 1, 2])
	func `Given one reused model When an obsolete request finishes Then the replacement state is preserved`(
		_ completion: Int
	) async {
		let gate = AuthenticationGate()
		let model = LoginViewModel(authentication: AuthenticationService(authenticate: { _ in try await gate.request() }))
		let session = makeSession()
		let first = Task { await session.signIn(using: model) }
		await gate.waitForEntry(0)
		let second = Task { await session.signIn(using: model) }
		await gate.waitForEntry(1)
		if completion != 0 {
			gate.finish(1, failure: completion == 1)
			await second.value
		}
		let expected = model.state
		let active = session.loggedIn
		gate.finish(0)
		await first.value
		#expect(gate.cancelled[0] == true)
		#expect(model.state == expected)
		#expect(session.loggedIn === active)
		if completion == 0 {
			#expect(model.state == .loading)
			gate.finish(1)
			await second.value
		}
		await session.logOut()
	}

	@Test(arguments: [false, true])
	func `Given pending authentication When logout or expiry occurs Then the task is cancelled and success is rejected`(
		_ expiry: Bool
	) async {
		let gate = AuthenticationGate()
		let model = LoginViewModel(authentication: AuthenticationService(authenticate: { _ in try await gate.request() }))
		let session = makeSession()
		let login = Task { await session.signIn(using: model) }
		await gate.waitForEntry(0)
		if expiry { await session.sessionExpired() } else { await session.logOut() }
		#expect(model.state == .idle)
		gate.finish(0)
		await login.value
		#expect(gate.cancelled[0] == true)
		#expect(session.loggedIn == nil)
		#expect(model.state == .idle)
	}

	@Test func `Given a cancelled caller When its owned authentication succeeds Then the flow is admitted`() async {
		let gate = AuthenticationGate()
		let model = LoginViewModel(authentication: AuthenticationService(authenticate: { _ in try await gate.request() }))
		let session = makeSession()
		let login = Task { await session.signIn(using: model) }
		await gate.waitForEntry(0)
		login.cancel()
		gate.finish(0)
		await login.value
		#expect(gate.cancelled[0] == false)
		#expect(session.loggedIn != nil)
		await session.logOut()
	}

	@Test(arguments: [false, true], [false, true])
	func `Given an ending flow When requests repeat Then cleanup completes once despite caller cancellation`(
		_ expiry: Bool, _ repeatedExpiry: Bool
	) async throws {
		let gate = AppSessionTests.CloseGate()
		let child = FakeLoggedInContext(parent: FakeAppContext())
		child.onClose = { await gate.wait() }
		let session = AppSession(makeLoggedInFlow: { _ in LoggedInFlow(context: child) })
		await session.signIn(using: FakeAppContext().loginViewModel)
		weak var outgoing = session.loggedIn
		var ended = false
		let end = Task {
			if expiry { await session.sessionExpired() } else { await session.logOut() }
			ended = true
		}
		await gate.waitForEntry()
		#expect(outgoing != nil)
		#expect(session.loggedIn == nil)
		#expect(session.isEndingSession)
		#expect(!ended)
		if repeatedExpiry { await session.sessionExpired() } else { await session.logOut() }
		#expect(child.closeCount == 1)
		#expect(session.isEndingSession)
		#expect(!ended)
		end.cancel()
		gate.release()
		await end.value
		#expect(ended)
		#expect(outgoing == nil)
		#expect(!session.isEndingSession)
	}

	@Test(arguments: [false, true])
	func `Given active or ending session When signing in Then the supplied model is untouched`(_ ending: Bool) async {
		let gate = AppSessionTests.CloseGate()
		let child = FakeLoggedInContext(parent: FakeAppContext())
		child.onClose = { await gate.wait() }
		let session = AppSession(makeLoggedInFlow: { _ in LoggedInFlow(context: child) })
		await session.signIn(using: FakeAppContext().loginViewModel)
		let active = session.loggedIn
		var end: Task<Void, Never>?
		if ending {
			end = Task { await session.logOut() }
			await gate.waitForEntry()
		}
		var requests = 0
		let model = LoginViewModel(authentication: AuthenticationService(authenticate: { _ in
			requests += 1
			return .preview
		}))
		await session.signIn(using: model)
		#expect(requests == 0)
		#expect(model.state == .idle)
		#expect(ending ? session.loggedIn == nil : session.loggedIn === active)
		if let end {
			gate.release()
			await end.value
		} else {
			child.onClose = nil
			await session.logOut()
		}
	}

	@Test func `Given signed out session When logout repeats Then no flow is created`() async {
		var constructed = 0
		let session = AppSession(makeLoggedInFlow: { _ in
			constructed += 1
			return LoggedInFlow(context: FakeLoggedInContext(parent: FakeAppContext()))
		})
		await session.logOut()
		await session.sessionExpired()
		await session.logOut()
		#expect(constructed == 0)
		#expect(session.loggedIn == nil)
		#expect(!session.isEndingSession)
	}

	@Test func `Given observable session When actions change its lifecycle Then presentation invalidates each time`() async {
		let changes = Mutex(0)
		let child = FakeLoggedInContext(parent: FakeAppContext())
		let gate = AppSessionTests.CloseGate()
		child.onClose = { await gate.wait() }
		let session = AppSession(makeLoggedInFlow: { _ in LoggedInFlow(context: child) })
		func track() {
			withObservationTracking {
				_ = session.loggedIn
				_ = session.isEndingSession
			} onChange: { changes.withLock { $0 += 1 } }
		}
		track()
		await session.signIn(using: FakeAppContext().loginViewModel)
		#expect(changes.withLock { $0 } == 1)
		#expect(session.loggedIn != nil)
		track()
		let end = Task { await session.logOut() }
		await gate.waitForEntry()
		#expect(changes.withLock { $0 } == 2)
		#expect(session.isEndingSession)
		track()
		gate.release()
		await end.value
		#expect(changes.withLock { $0 } == 3)
		#expect(!session.isEndingSession)
	}

	@Test func `Given a completed attempt When its caller returns Then the session releases the login model`() async {
		let session = makeSession()
		weak var released: LoginViewModel?
		func login() async {
			let model = FakeAppContext().loginViewModel
			released = model
			await session.signIn(using: model)
		}
		await login()
		#expect(session.loggedIn != nil)
		#expect(released == nil)
		await session.logOut()
	}
}
