import Foundation
import HTTIES

/// In-memory stand-in for `URLSession` that serves JSONPlaceholder-shaped posts.
///
/// Wired via `@Bean` so the rest of the graph (HTTIES `HTTPClient` → repository)
/// stays identical when you switch the bean to `URLSession.shared`.
final class FakeJSONPlaceholderDataHandler: HTTPDataRequestHandler, Sendable {
	private let posts: [JSONPlaceholderPostDTO] = [
		JSONPlaceholderPostDTO(
			id: 1,
			title: "sunt aut facere repellat provident",
			body: "quia et suscipit\nsuscipit recusandae consequuntur"
		),
		JSONPlaceholderPostDTO(
			id: 2,
			title: "qui est esse",
			body: "est rerum tempore vitae\nsequi sint nihil"
		),
		JSONPlaceholderPostDTO(
			id: 3,
			title: "ea molestias quasi exercitationem",
			body: "et iusto sed quo iure\nvoluptatem occaecati"
		),
		JSONPlaceholderPostDTO(
			id: 4,
			title: "eum et est occaecati",
			body: "ullam et saepe reiciendis voluptatem"
		),
		JSONPlaceholderPostDTO(
			id: 5,
			title: "nesciunt quas odio",
			body: "repudiandae veniam quaerat sunt sed"
		),
	]

	func sendRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
		try? await Task.sleep(for: .milliseconds(250))

		guard let url = request.url,
		      let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: ["Content-Type": "application/json"]
		      )
		else {
			throw URLError(.badURL)
		}

		let path = url.path
		if path.hasSuffix("/posts") || path.hasSuffix("/posts/") {
			let data = try JSONEncoder().encode(posts)
			return (data, response)
		}

		if let id = postID(from: path),
		   let post = posts.first(where: { $0.id == id }) {
			let data = try JSONEncoder().encode(post)
			return (data, response)
		}

		guard let notFound = HTTPURLResponse(
			url: url,
			statusCode: 404,
			httpVersion: nil,
			headerFields: nil
		) else {
			throw URLError(.cannotParseResponse)
		}
		return (Data("{}".utf8), notFound)
	}

	private func postID(from path: String) -> Int? {
		let parts = path.split(separator: "/")
		guard parts.count >= 2, parts[parts.count - 2] == "posts" else {
			return nil
		}
		return Int(parts[parts.count - 1])
	}
}
