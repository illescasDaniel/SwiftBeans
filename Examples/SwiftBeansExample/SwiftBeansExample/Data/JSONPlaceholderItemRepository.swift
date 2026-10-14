import Foundation
import HTTIES
import SwiftBeans

/// Fetches posts via HTTIES. Bound to `ItemRepository` for the use-case layer.
@Service(boundTo: ItemRepository.self)
final class JSONPlaceholderItemRepository: ItemRepository, Sendable {
	private let httpClient: any HTTPClient
	private let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!
	private let decoder = JSONDecoder()

	init(httpClient: any HTTPClient) {
		self.httpClient = httpClient
	}

	func fetchItems() async -> [Item] {
		do {
			let request = try HTTPURLRequest(url: baseURL / "posts")
			let posts: [JSONPlaceholderPostDTO] = try await httpClient.sendRequest(
				request,
				decoding: [JSONPlaceholderPostDTO].self,
				decoder: decoder
			)
			return posts.prefix(10).map(\.asItem)
		} catch {
			return []
		}
	}

	func fetchItem(id: Int) async -> Item? {
		do {
			let request = try HTTPURLRequest(url: baseURL / "posts" / id)
			let post: JSONPlaceholderPostDTO = try await httpClient.sendRequest(
				request,
				decoding: JSONPlaceholderPostDTO.self,
				decoder: decoder
			)
			return post.asItem
		} catch {
			return nil
		}
	}
}
