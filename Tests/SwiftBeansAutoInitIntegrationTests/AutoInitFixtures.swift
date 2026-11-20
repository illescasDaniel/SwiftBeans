import Foundation
import Observation
import SwiftBeans

/// The real macros and the real generator meet in this module (SPEC "Service auto-init").

@ApplicationContext
@MainActor
final class AutoInitContext {}

struct Item: Equatable, Sendable {
	var id: Int
}

@Service(autoInit: true)
final class Repository {
	var calls = 0
}

@Service(autoInit: true)
struct Store: Sendable {
	let name = "store"
}

@Configuration
enum AutoInitConfiguration {
	@Bean(named: "snakeCase")
	static func snakeCaseDecoder() -> JSONDecoder {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return decoder
	}

	@Bean
	static func plainDecoder() -> JSONDecoder { JSONDecoder() }

	/// Wrappers on `@Bean` parameters keep working next to property markers in the same module.
	@Bean
	static func tagged(@Assisted title: String, @Qualifier("snakeCase") decoder: JSONDecoder) -> Tagged {
		Tagged(title: title, decoder: decoder)
	}
}

struct Tagged {
	var title: String
	var decoder: JSONDecoder
}

/// Private closure lets, plain state with initial values, and an `@Observable @MainActor` class.
@Service(scope: .transient, autoInit: true)
@Observable
@MainActor
final class Coordinator {
	var path: [Int] = []
	var selectedTab = 0
	private let makeRepository: @MainActor () -> Repository
	private let makeDetail: @MainActor (Item) -> DetailViewModel

	func repository() -> Repository { makeRepository() }
	func detail(for item: Item) -> DetailViewModel { makeDetail(item) }
}

/// Dependency, assisted and qualified properties, one of them `private`.
@Service(autoInit: true)
@Observable
@MainActor
final class DetailViewModel {
	private let repository: Repository
	// `var` under `@Observable`: the tracked backing property re-expands the marker.
	@Assisted private(set) var item: Item
	@Qualifier("snakeCase") private let decoder: JSONDecoder

	func decodeFirstName(_ json: String) throws -> String {
		struct Person: Decodable { var firstName: String }
		repository.calls += 1
		return try decoder.decode(Person.self, from: Data(json.utf8)).firstName
	}
}

/// `@ObservationIgnored` stored properties stay ordinary parameters.
@Service(autoInit: true)
@Observable
@MainActor
final class Tracker {
	@ObservationIgnored private let repository: Repository
	var count = 0

	func touch() {
		repository.calls += 1
		count += 1
	}
}

@Service(autoInit: true)
struct Reporter {
	private let repository: Repository

	@MainActor
	func report() -> Int { repository.calls }
}

@Service(autoInit: true)
actor CounterActor {
	let store: Store
	private var value = 0

	func increment() -> String {
		value += 1
		return "\(store.name)\(value)"
	}
}

/// Hand-written initializer with wrappers on its parameters, next to the property markers above.
@Service
@MainActor
final class HandWritten {
	let item: Item
	let decoder: JSONDecoder

	init(@Assisted item: Item, @Qualifier("snakeCase") decoder: JSONDecoder) {
		self.item = item
		self.decoder = decoder
	}
}
