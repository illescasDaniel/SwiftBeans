import Foundation
import Observation
import SwiftBeans

@Service(scope: .transient)
@Observable
@MainActor
final class LoginViewModel {
	var name = "Taylor"
	private(set) var state: LoadState = .idle
	private let authentication: AuthenticationService
	// Protects model presentation; AppSession separately guards admission of an authenticated flow.
	private var attempt: UUID?

	init(authentication: AuthenticationService) { self.authentication = authentication }

	func authenticate() async -> SessionCredentials? {
		let identity = UUID()
		attempt = identity
		state = .loading
		do {
			let credentials = try await authentication.logIn(name: name)
			guard attempt == identity, !Task.isCancelled else { return nil }
			state = .loaded
			return credentials
		} catch {
			guard attempt == identity else { return nil }
			state = error is CancellationError ? .idle : .failed(error.localizedDescription)
			return nil
		}
	}

	func cancelAuthentication() {
		attempt = nil
		state = .idle
	}
}
