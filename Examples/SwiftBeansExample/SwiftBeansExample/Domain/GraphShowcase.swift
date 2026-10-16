import Foundation
import GreetingKit
import SwiftBeans

// MARK: - Qualifiers

/// App-side `Greeter` registered as `@Bean(named: "short")`. Not a `@Service`:
/// that would be a second unqualified `Greeter` and fail the build.
nonisolated struct ShortGreeter: Greeter {
	func greet(_ name: String) -> String {
		"Hi, \(name)"
	}
}

/// `nonisolated` so `Decodable` synthesis is not main-actor isolated.
nonisolated struct SnakeCaseTitle: Decodable, Sendable {
	let postTitle: String
}

/// Reads a snake_case payload with the named decoder, not the unqualified one.
@Service
final class SnakeCaseReader: Sendable {
	static let sampleJSON = Data(#"{"post_title":"Named decoder"}"#.utf8)

	private let decoder: JSONDecoder

	init(@Qualifier("snakeCase") decoder: JSONDecoder) {
		self.decoder = decoder
	}

	func title(from json: Data) throws -> String {
		try decoder.decode(SnakeCaseTitle.self, from: json).postTitle
	}
}

/// Unqualified `Greeter` plus `@Qualifier("short")`.
@Service
final class GreetingStyles: Sendable {
	let standard: String
	let short: String

	init(greeter: any Greeter, @Qualifier("short") shortGreeter: any Greeter) {
		self.standard = greeter.greet("SwiftBeans")
		self.short = shortGreeter.greet("SwiftBeans")
	}
}

// MARK: - @Service(named:)

protocol TagSource: Sendable {
	var label: String { get }
}

/// Concrete type qualified by name. Accessor: `builtinStaticTagSource`.
@Service(named: "builtin")
final class StaticTagSource: TagSource, Sendable {
	let label = "builtin"
	init() {}
}

/// Protocol binding qualified by name. Accessor: `remoteTagSource` as `TagSource`.
@Service(boundTo: TagSource.self, named: "remote")
final class RemoteTagSource: TagSource, Sendable {
	let label = "remote"
	init() {}
}

@Service
final class TagSourcePair: Sendable {
	let builtinLabel: String
	let remoteLabel: String

	init(
		@Qualifier("builtin") builtin: StaticTagSource,
		@Qualifier("remote") remote: any TagSource
	) {
		self.builtinLabel = builtin.label
		self.remoteLabel = remote.label
	}
}

// MARK: - Collection injection

/// Every scanned type that declares this protocol is a member of `[any FeatureNote]`.
protocol FeatureNote: Sendable {
	var title: String { get }
	var detail: String { get }
}

@Service
final class AssistedFeatureNote: FeatureNote, Sendable {
	let title = "@Assisted"
	let detail = "ItemDetailViewModel(item:) takes the selected post at the call site."
	init() {}
}

@Service
final class CollectionFeatureNote: FeatureNote, Sendable {
	let title = "Collections"
	let detail = "This list is every FeatureNote bean, in accessor-name order."
	init() {}
}

@Service
final class FactoryFeatureNote: FeatureNote, Sendable {
	let title = "Factories"
	let detail = "AppCoordinator takes () -> ItemListViewModel and (Item) -> ItemDetailViewModel."
	init() {}
}

@Service
final class QualifierFeatureNote: FeatureNote, Sendable {
	let title = "@Qualifier"
	let detail = "snakeCaseJSONDecoder is a second JSONDecoder, asked for by name."
	init() {}
}
