import Foundation

/// Domain model — plain data, no SwiftBeans / HTTIES dependency.
struct Item: Identifiable, Equatable, Hashable, Sendable {
	let id: Int
	let title: String
	let detail: String
}
