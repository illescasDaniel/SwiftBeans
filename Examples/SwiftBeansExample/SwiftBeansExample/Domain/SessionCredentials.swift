import Foundation

struct SessionCredentials: Sendable, Equatable {
	let userID: UUID
	let displayName: String

	static let preview = SessionCredentials(userID: UUID(), displayName: "Taylor")
}
