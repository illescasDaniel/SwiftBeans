import Testing
@testable import SwiftBeansGeneratorCore

private let repositoryFile = appFile("/App/Repository.swift", """
	@Service
	final class ItemRepository {
		init() {}
	}
	""")

private let detailFile = appFile("/App/Detail.swift", """
	@Service
	final class ItemDetailViewModel {
		init(repository: ItemRepository, @Assisted item: Item) {}
	}
	""")

@Suite("Generator — SPEC Factory injection")
struct GeneratorFactoryInjectionTests {
	// MARK: - Assisted factories

	@Test
	func `Given an escaping assisted factory parameter When generated Then the closure calls the method accessor`() {
		let result = generateWithContext(repositoryFile, detailFile, appFile("/App/Coordinator.swift", """
			@Service
			final class Coordinator {
				init(makeDetail: @escaping (Item) -> ItemDetailViewModel) {}
			}
			"""))
		expectOutput(result, contains: [
			"\tvar coordinator: Coordinator {\n\t\t_swiftBeansRegistry.singleton(key: \"coordinator\") {\n\t\t\tCoordinator(makeDetail: { self.itemDetailViewModel(item: $0) })\n\t\t}\n\t}",
			"\tfunc itemDetailViewModel(item: Item) -> ItemDetailViewModel {\n",
		])
	}

	@Test
	func `Given a factory with several assisted arguments When generated Then positions map to labels`() {
		let result = generateWithContext(appFile("/App/Api.swift", """
			@Service
			final class API {
				init() {}
			}
			"""), appFile("/App/Search.swift", """
			@Service
			final class Search {
				init(@Assisted _ query: String, api: API, @Assisted page pageIndex: Int) {}
			}

			@Service
			final class Screen {
				init(makeSearch: (String, Int) -> Search) {}
			}
			"""))
		expectOutput(result, contains: ["Screen(makeSearch: { self.search($0, page: $1) })"])
	}

	@Test
	func `Given an assisted bean When a factory is injected Then the closure calls the bean's method accessor`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum Config {
				@Bean
				static func report(@Assisted title: String) -> Report { Report() }
			}

			@Service
			final class Printer {
				init(makeReport: (String) -> Report) {}
			}
			"""))
		expectOutput(result, contains: ["Printer(makeReport: { self.report(title: $0) })"])
	}

	@Test
	func `Given labels attributes and parentheses on the function type When generated Then they do not affect matching`() {
		for spelling in [
			"@escaping (_ item: Item) -> ItemDetailViewModel",
			"((Item) -> ItemDetailViewModel)",
			"@escaping @Sendable (Item) -> ItemDetailViewModel",
			"(Item) throws -> ItemDetailViewModel",
			"(Item) async -> ItemDetailViewModel",
			"(Item) -> ItemDetailViewModel",
		] {
			let result = generateWithContext(repositoryFile, detailFile, appFile("/App/Coordinator.swift", """
				@Service
				final class Coordinator {
					init(makeDetail: \(spelling)) {}
				}
				"""))
			expectOutput(result, contains: ["Coordinator(makeDetail: { self.itemDetailViewModel(item: $0) })"])
		}
	}

	@Test
	func `Given a factory declared in a struct memberwise initializer When generated Then it is wired`() {
		let result = generateWithContext(repositoryFile, detailFile, appFile("/App/Coordinator.swift", """
			@Service
			struct Coordinator {
				let makeDetail: (Item) -> ItemDetailViewModel
			}
			"""))
		expectOutput(result, contains: ["Coordinator(makeDetail: { self.itemDetailViewModel(item: $0) })"])
	}

	@Test
	func `Given assisted types spelled differently When matched Then they are normalized`() {
		let result = generateWithContext(appFile("/App/Types.swift", """
			@Service
			final class Lister {
				init(@Assisted ids: Array<Int>, @Assisted store: any Store, @Assisted name: String?, @Assisted done: @escaping () -> Void) {}
			}

			@Service
			final class Screen {
				init(makeLister: ([Int], Store, Optional<String>, () -> Void) -> Lister) {}
			}
			"""))
		// `String?` and `Optional<String>` are different spellings outside key normalization.
		#expect(result.errorSummary == ["factory.unresolved /App/Types.swift:8:7"], "\(result.renderedDiagnostics)")
		let matching = generateWithContext(appFile("/App/Types.swift", """
			@Service
			final class Lister {
				init(@Assisted ids: Array<Int>, @Assisted store: any Store, @Assisted name: String?, @Assisted done: @escaping () -> Void) {}
			}

			@Service
			final class Screen {
				init(makeLister: ([Int], Store, String?, () -> Void) -> Lister) {}
			}
			"""))
		expectOutput(matching, contains: ["Screen(makeLister: { self.lister(ids: $0, store: $1, name: $2, done: $3) })"])
	}

	@Test
	func `Given an assisted factory with a default When it does not match Then the default is kept`() {
		let result = generateWithContext(repositoryFile, detailFile, appFile("/App/Coordinator.swift", """
			@Service
			final class Coordinator {
				init(makeDetail: (String) -> ItemDetailViewModel = { _ in fatalError() }) {}
			}
			"""))
		expectOutput(result, contains: ["Coordinator()"])
	}

	@Test
	func `Given an assisted factory with a default When it matches Then it is wired`() {
		let result = generateWithContext(repositoryFile, detailFile, appFile("/App/Coordinator.swift", """
			@Service
			final class Coordinator {
				init(makeDetail: (Item) -> ItemDetailViewModel = { _ in fatalError() }) {}
			}
			"""))
		expectOutput(result, contains: ["Coordinator(makeDetail: { self.itemDetailViewModel(item: $0) })"])
	}

	// MARK: - Deferred factories

	@Test
	func `Given a deferred factory parameter When generated Then the closure reads the accessor`() {
		let result = generateWithContext(appFile("/App/Heavy.swift", """
			@Service(scope: .transient)
			final class Heavy {
				init() {}
			}

			@Service
			final class Screen {
				init(makeHeavy: @escaping () -> Heavy) {}
			}
			"""))
		expectOutput(result, contains: ["Screen(makeHeavy: { self.heavy })"])
	}

	@Test
	func `Given a deferred factory for a protocol key When generated Then any is kept in the accessor type`() {
		let result = generateWithContext(appFile("/App/Store.swift", """
			@Service(boundTo: Store.self)
			final class DiskStore: Store {
				init() {}
			}

			@Service
			final class Screen {
				init(makeStore: () -> any Store) {}
			}
			"""))
		expectOutput(result, contains: [
			"Screen(makeStore: { self.store })",
			"\tvar store: any Store { get }\n",
		])
	}

	@Test
	func `Given a deferred factory for a bean When generated Then the closure reads the accessor`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum Config {
				@Bean
				static func session() -> URLSession { URLSession() }
			}

			@Service
			final class Client {
				init(session: () -> URLSession) {}
			}
			"""))
		expectOutput(result, contains: ["Client(session: { self.urlSession })"])
	}

	// MARK: - Cycles

	@Test
	func `Given a cycle broken by a deferred factory When generated Then there is no cycle error`() {
		let result = generateWithContext(appFile("/App/Cycle.swift", """
			@Service
			final class A {
				init(makeB: () -> B) {}
			}

			@Service
			final class B {
				init(a: A) {}
			}
			"""))
		expectOutput(result, contains: ["A(makeB: { self.b })", "B(a: self.a)"])
	}

	@Test
	func `Given a self referencing deferred factory When generated Then there is no cycle error`() {
		let result = generateWithContext(appFile("/App/Self.swift", """
			@Service
			final class Node {
				init(makeNode: () -> Node) {}
			}
			"""))
		expectOutput(result, contains: ["Node(makeNode: { self.node })"])
	}

	@Test
	func `Given a cycle broken by an assisted factory When generated Then there is no cycle error`() {
		let result = generateWithContext(appFile("/App/Cycle.swift", """
			@Service
			final class Coordinator {
				init(makeDetail: (Item) -> Detail) {}
			}

			@Service
			final class Detail {
				init(parent: Coordinator, @Assisted item: Item) {}
			}
			"""))
		expectOutput(result, contains: [
			"Coordinator(makeDetail: { self.detail(item: $0) })",
			"Detail(parent: self.coordinator, item: item)",
		])
	}

	@Test
	func `Given a cycle with a plain edge as well When generated Then the plain cycle is still reported`() {
		let result = generateWithContext(appFile("/App/Cycle.swift", """
			@Service
			final class A {
				init(b: B, makeC: () -> C) {}
			}

			@Service
			final class B {
				init(a: A) {}
			}

			@Service
			final class C {
				init() {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errors.map(\.id) == ["graph.cycle"])
	}

	// MARK: - Errors

	@Test
	func `Given assisted arguments that do not match When injected Then factory unresolved names the expected signature`() throws {
		for spelling in ["(String) -> ItemDetailViewModel", "(Item, Int) -> ItemDetailViewModel", "() -> ItemDetailViewModel"] {
			let result = generateWithContext(repositoryFile, detailFile, appFile("/App/Coordinator.swift", """
				@Service
				final class Coordinator {
					init(makeDetail: \(spelling)) {}
				}
				"""))
			#expect(result.output == nil)
			#expect(result.errorSummary == ["factory.unresolved /App/Coordinator.swift:3:7"], "\(spelling): \(result.renderedDiagnostics)")
			let message = try #require(result.errors.first?.message)
			#expect(message.contains("(Item) -> ItemDetailViewModel"), "\(message)")
		}
	}

	@Test
	func `Given arguments for a non assisted target When injected Then factory unresolved suggests the deferred form`() throws {
		let result = generateWithContext(appFile("/App/Heavy.swift", """
			@Service
			final class Heavy {
				init() {}
			}

			@Service
			final class Screen {
				init(makeHeavy: (Int) -> Heavy) {}
			}
			"""))
		#expect(result.errorSummary == ["factory.unresolved /App/Heavy.swift:8:7"])
		let message = try #require(result.errors.first?.message)
		#expect(message.contains("() -> Heavy"), "\(message)")
	}

	@Test
	func `Given a factory for an unprovided key When generated Then it is a missing dependency with a hint`() throws {
		let result = generateWithContext(appFile("/App/Screen.swift", """
			@Service
			final class Screen {
				init(makeThing: () -> Thing) {}
			}

			@Service
			final class Outer {
				init() {}
			}

			enum Other {
				@Service
				final class Thing {
					init() {}
				}
			}
			"""))
		#expect(result.errorSummary == ["graph.missingDependency /App/Screen.swift:3:7"])
		let error = try #require(result.errors.first)
		#expect(error.message.contains("'Thing'"), "\(error.message)")
		#expect(error.notes.map(\.id) == ["graph.didYouMean"])
	}

	@Test
	func `Given a plain assisted provider injection When a factory exists elsewhere Then notInjectable still applies`() {
		let result = generateWithContext(repositoryFile, detailFile, appFile("/App/Coordinator.swift", """
			@Service
			final class Coordinator {
				init(detail: ItemDetailViewModel, makeDetail: (Item) -> ItemDetailViewModel) {}
			}
			"""))
		#expect(result.errorSummary == ["assisted.notInjectable /App/Coordinator.swift:3:7"])
	}

	@Test
	func `Given unsupported function shapes When injected Then factory unsupported fails at the type`() {
		for spelling in ["(inout Item) -> Detail", "(Item...) -> Detail", "() -> Void", "() -> Int?", "() -> (Int, Int)", "() -> () -> Detail"] {
			let result = generateWithContext(appFile("/App/Screen.swift", """
				@Service
				final class Screen {
					init(make: \(spelling)) {}
				}
				"""))
			#expect(result.output == nil)
			#expect(result.errorSummary == ["factory.unsupported /App/Screen.swift:3:13"], "\(spelling): \(result.renderedDiagnostics)")
		}
	}

	@Test
	func `Given an unsupported function shape with a default When generated Then the default is kept`() {
		let result = generateWithContext(appFile("/App/Screen.swift", """
			@Service
			final class Screen {
				init(make: () -> Void = {}) {}
			}
			"""))
		expectOutput(result, contains: ["Screen()"])
	}

	@Test
	func `Given a function type as a bean return type When generated Then it is still an unsupported key`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum Config {
				@Bean
				static func make() -> () -> Int { { 1 } }
			}
			"""))
		#expect(result.errors.map(\.id) == ["key.unsupported"])
	}

	@Test
	func `Given an optional function type without a default When injected Then it is an unsupported key`() {
		let result = generateWithContext(appFile("/App/Screen.swift", """
			@Service
			final class Screen {
				init(make: (() -> Int)?) {}
			}
			"""))
		#expect(result.errors.map(\.id) == ["key.unsupported"])
	}

	// MARK: - Unchanged output

	@Test
	func `Given a graph without factories When generated Then the output is byte identical to the baseline`() {
		let result = generateWithContext(repositoryFile, detailFile, appFile("/App/Graph.swift", """
			protocol Store {}

			@Service(boundTo: Store.self)
			final class DiskStore: Store {
				init() {}
			}

			@Service(scope: .transient)
			final class Screen {
				init(store: any Store, repository: ItemRepository, retries: Int = 3) {}
			}

			@Configuration
			enum Config {
				@Bean
				static func report(store: any Store, @Assisted title: String) -> Report { Report() }
			}
			"""))
		#expect(result.output == baselineOutput, "\(result.output ?? result.renderedDiagnostics)")
	}
}

private let baselineOutput = """
	// Generated by SwiftBeans — do not edit.
	import Foundation
	import SwiftBeans

	protocol AppContextProtocol: AnyObject {
		func itemDetailViewModel(item: Item) -> ItemDetailViewModel
		var itemRepository: ItemRepository { get }
		func report(title: String) -> Report
		var screen: Screen { get }
		var store: any Store { get }
	}

	extension AppContext {
		func itemDetailViewModel(item: Item) -> ItemDetailViewModel {
			ItemDetailViewModel(repository: self.itemRepository, item: item)
		}

		var itemRepository: ItemRepository {
			_swiftBeansRegistry.singleton(key: "itemRepository") {
				ItemRepository()
			}
		}

		func report(title: String) -> Report {
			Config.report(store: self.store, title: title)
		}

		var screen: Screen {
			Screen(store: self.store, repository: self.itemRepository)
		}

		var store: any Store {
			_swiftBeansRegistry.singleton(key: "store") {
				DiskStore()
			}
		}
	}

	extension AppContext: AppContextProtocol {}

	"""
