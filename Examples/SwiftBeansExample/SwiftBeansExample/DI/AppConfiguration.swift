import Foundation
import HTTIES
import SwiftBeans

/// `@Configuration` + `@Bean` for types we don’t own (HTTIES / Foundation).
///
/// Swap `httpDataRequestHandler` to `URLSession.shared` to hit the real
/// [JSONPlaceholder](https://jsonplaceholder.typicode.com) API.
@Configuration
enum AppConfiguration {
	@Bean
	static func httpDataRequestHandler() -> any HTTPDataRequestHandler {
		// Offline-friendly default for demos, Previews, and CI.
		// Live network: return URLSession.shared
		FakeJSONPlaceholderDataHandler()
	}

	@Bean
	static func httpClient(
		httpDataRequestHandler: any HTTPDataRequestHandler
	) -> any HTTPClient {
		HTTPClientImpl(httpDataRequestHandler: httpDataRequestHandler)
	}

	/// Generic-collection bean. Consumers may spell the key differently
	/// (`Dictionary<String, Int>`); the generator normalizes both to one key.
	@Bean
	static func tagCounts() -> [String: Int] {
		["swift": 3, "di": 2, "macros": 1]
	}
}
