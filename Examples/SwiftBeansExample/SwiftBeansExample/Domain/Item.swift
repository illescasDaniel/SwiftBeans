import Foundation

/// Domain model — plain data, no SwiftBeans dependency.
struct Item: Identifiable, Equatable, Sendable {
	let id: UUID
	let title: String
	let detail: String
}
