import Foundation
import GreetingKit
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

	/// Parameter, not `AppConfiguration.httpDataRequestHandler()`: a direct `@Bean` call
	/// would build a second handler and warn `bean.directCall`.
	@Bean
	static func httpClient(
		httpDataRequestHandler: any HTTPDataRequestHandler
	) -> any HTTPClient {
		HTTPClientImpl(httpDataRequestHandler: httpDataRequestHandler)
	}

	/// Unqualified `JSONDecoder`. `JSONPlaceholderItemRepository` takes this one.
	@Bean
	static func decoder() -> JSONDecoder {
		JSONDecoder()
	}

	/// Same type, different configuration. Ask for it with `@Qualifier("snakeCase")`.
	/// Accessor: `snakeCaseJSONDecoder`.
	@Bean(named: "snakeCase")
	static func snakeCaseDecoder() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return decoder
	}

	/// Second `Greeter`. The unqualified one stays `EnglishGreeter` from GreetingKitLive.
	/// Accessor: `shortGreeter`.
	@Bean(named: "short")
	static func shortGreeter() -> any Greeter {
		ShortGreeter()
	}

	/// Generic-collection bean. Consumers may spell the key differently
	/// (`Dictionary<String, Int>`); the generator normalizes both to one key.
	@Bean
	static func tagCounts() -> [String: Int] {
		["swift": 3, "di": 2, "macros": 1]
	}

	/// An explicit array bean, rather than an automatically assembled collection.
	/// Its generated accessor and protocol requirement both retain `[any FeatureNote]`.
	/// Naming it keeps the unqualified collection-injection demo unchanged.
	@Bean(named: "highlights")
	static func highlightedNotes(
		factory: FactoryFeatureNote,
		assisted: AssistedFeatureNote
	) -> [any FeatureNote] {
		[factory, assisted]
	}
}
