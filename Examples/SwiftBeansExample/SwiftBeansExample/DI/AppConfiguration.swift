import Foundation
import HTTIES
import SwiftBeans

/// `@Configuration` + `@Bean` for types we don’t own (HTTIES / Foundation).
///
/// `httpDataRequestHandler` is the offline fake in DEBUG builds and `URLSession.shared`
/// (the real [JSONPlaceholder](https://jsonplaceholder.typicode.com) API) otherwise.
@Configuration
enum AppConfiguration {
	@Bean
	static func httpDataRequestHandler() -> any HTTPDataRequestHandler {
		#if DEBUG
		// Offline-friendly default for demos, Previews, and CI.
		FakeJSONPlaceholderDataHandler()
		#else
		URLSession.shared
		#endif
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
