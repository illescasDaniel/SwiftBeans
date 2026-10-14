import Foundation

/// Wire model for https://jsonplaceholder.typicode.com/posts
/// `nonisolated` so Decodable can run off the main actor (app default isolation is MainActor).
nonisolated struct JSONPlaceholderPostDTO: Codable, Sendable, Equatable {
	let id: Int
	let title: String
	let body: String
}

extension JSONPlaceholderPostDTO {
	var asItem: Item {
		Item(id: id, title: title, detail: body)
	}
}
