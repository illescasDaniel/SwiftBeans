import Foundation
import SwiftBeans

/// Local authentication stand-in: inject the operation to exercise failures and stale results.
@Service
@MainActor
final class AuthenticationService {
	enum Failure: LocalizedError {
		case emptyName
		var errorDescription: String? { "Enter a name to log in." }
	}
	private let authenticate: @MainActor (String) async throws -> SessionCredentials

	init(
		authenticate: @escaping @MainActor (String) async throws -> SessionCredentials = { name in
			let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !name.isEmpty else { throw Failure.emptyName }
			try Task.checkCancellation()
			return SessionCredentials(userID: UUID(), displayName: name)
		}
	) { self.authenticate = authenticate }

	func logIn(name: String) async throws -> SessionCredentials { try await authenticate(name) }
}
