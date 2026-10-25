import Foundation
import Testing

@testable import SwiftBeansExample

@Suite("AppSession — admission contract")
@MainActor
struct AppSessionContractTests {
	@Test func `Given current credentials When authentication succeeds Then the exact flow is installed`() async {
		let credentials = SessionCredentials.preview
		let model = LoginViewModel(authentication: AuthenticationService(authenticate: { _ in credentials }))
		let flow = LoggedInFlow(context: FakeLoggedInContext(parent: FakeAppContext()))
		var received: [SessionCredentials] = []
		let session = AppSession(makeLoggedInFlow: {
			received.append($0)
			return flow
		})
		await session.signIn(using: model)
		#expect(received == [credentials])
		#expect(session.loggedIn === flow)
		#expect(model.state == .loaded)
		await session.logOut()
	}

	@Test(arguments: [false, true])
	func `Given authentication failure When retrying Then failure presentation persists and retry is admitted`(
		_ cancellation: Bool
	) async {
		var requests = 0
		let model = LoginViewModel(authentication: AuthenticationService(authenticate: { _ in
			requests += 1
			if requests == 1 {
				if cancellation { throw CancellationError() }
				throw AuthenticationService.Failure.emptyName
			}
			return .preview
		}))
		var constructed = 0
		let session = AppSession(makeLoggedInFlow: { _ in
			constructed += 1
			return LoggedInFlow(context: FakeLoggedInContext(parent: FakeAppContext()))
		})
		await session.signIn(using: model)
		#expect(session.loggedIn == nil)
		#expect(constructed == 0)
		if cancellation {
			#expect(model.state == .idle)
		} else {
			if case .failed = model.state {} else { Issue.record("Expected authentication failure") }
		}
		await session.signIn(using: model)
		#expect(requests == 2)
		#expect(constructed == 1)
		#expect(session.loggedIn != nil)
		await session.logOut()
	}
}
