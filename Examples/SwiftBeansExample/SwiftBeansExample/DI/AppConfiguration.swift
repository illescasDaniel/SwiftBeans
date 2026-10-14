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
}
