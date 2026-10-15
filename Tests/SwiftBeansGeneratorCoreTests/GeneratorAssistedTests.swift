import Testing
@testable import SwiftBeansGeneratorCore

/// The text of the generated extension member that starts with `declaration`, up to its closing brace.
private func extensionMember(_ declaration: String, in output: String) -> String? {
	guard let start = output.range(of: "\t\(declaration) {\n") else { return nil }
	guard let end = output[start.upperBound...].range(of: "\n\t}") else { return nil }
	return String(output[start.lowerBound..<end.upperBound])
}

private let repositoryFile = appFile("/App/Repository.swift", """
	@Service
	final class ItemRepository {
		init() {}
	}
	""")

@Suite("Generator — SPEC Runtime arguments: @Assisted")
struct GeneratorAssistedTests {
	// MARK: - Scenarios

	@Test
	func `Given an assisted service When generated Then protocol and context get a method and no property`() throws {
		let result = generateWithContext(repositoryFile, appFile("/App/Detail.swift", """
			@Service
			final class ItemDetailViewModel {
				init(repository: ItemRepository, @Assisted item: Item) {}
			}
			"""))
		expectOutput(result, contains: [
			"protocol AppContextProtocol: AnyObject {\n\tfunc itemDetailViewModel(item: Item) -> ItemDetailViewModel\n",
			"\tvar itemRepository: ItemRepository { get }\n",
			"\tfunc itemDetailViewModel(item: Item) -> ItemDetailViewModel {\n\t\tItemDetailViewModel(repository: self.itemRepository, item: item)\n\t}",
		])
		expectOutput(result, excludes: ["var itemDetailViewModel"])
		let output = try #require(result.output)
		#expect(occurrences(of: "func itemDetailViewModel(item: Item) -> ItemDetailViewModel", in: output) == 2)
		let body = try #require(extensionMember("func itemDetailViewModel(item: Item) -> ItemDetailViewModel", in: output))
		#expect(!body.contains("_swiftBeansRegistry"), "assisted providers are plain constructions:\n\(body)")
	}

	@Test
	func `Given assisted parameters with labels When generated Then labels and order are kept`() {
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
			"""))
		expectOutput(result, contains: [
			"\tfunc search(_ query: String, page pageIndex: Int) -> Search\n",
			"\tfunc search(_ query: String, page pageIndex: Int) -> Search {\n\t\tSearch(query, api: self.api, page: pageIndex)\n\t}",
		])
	}

	@Test
	func `Given an assisted bean When generated Then the method calls the bean with graph values and arguments`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum Config {
				@Bean
				static func store() -> any Store { MemoryStore() }

				@Bean
				static func report(store: any Store, @Assisted title: String) -> Report { Report() }
			}
			"""))
		expectOutput(result, contains: [
			"\tfunc report(title: String) -> Report\n",
			"\tfunc report(title: String) -> Report {\n\t\tConfig.report(store: self.store, title: title)\n\t}",
			"\tvar store: any Store { get }\n",
		])
		expectOutput(result, excludes: ["var report"])
	}

	@Test
	func `Given an assisted provider injected elsewhere When generated Then the error names the method`() throws {
		let result = generateWithContext(repositoryFile, appFile("/App/Detail.swift", """
			@Service
			final class ItemDetailViewModel {
				init(repository: ItemRepository, @Assisted item: Item) {}
			}

			@Service
			final class Coordinator {
				init(detail: ItemDetailViewModel) {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errorSummary == ["assisted.notInjectable /App/Detail.swift:8:7"])
		let message = try #require(result.errors.first?.message)
		#expect(message.contains("itemDetailViewModel(item:)"), "\(message)")
		#expect(message.contains("runtime arguments"), "\(message)")
	}

	@Test
	func `Given an assisted provider with no labels When injected elsewhere Then the selector uses underscores`() throws {
		let result = generateWithContext(appFile("/App/Search.swift", """
			@Service
			final class Search {
				init(@Assisted _ query: String, @Assisted page: Int) {}
			}

			@Service
			final class Screen {
				init(search: Search) {}
			}
			"""))
		let message = try #require(result.errors.first?.message)
		#expect(result.errorSummary == ["assisted.notInjectable /App/Search.swift:8:7"])
		#expect(message.contains("search(_:page:)"), "\(message)")
	}

	@Test
	func `Given an explicit singleton scope on an assisted provider When generated Then the error is at the scope argument`() {
		let result = generateWithContext(appFile("/App/Detail.swift", """
			@Service(scope: .singleton)
			final class Detail {
				init(@Assisted item: Item) {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errorSummary == ["assisted.singleton /App/Detail.swift:1:10"])
	}

	@Test
	func `Given an assisted bean with an explicit singleton scope When generated Then the error is at the scope argument`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum Config {
				@Bean(scope: .singleton)
				static func report(@Assisted title: String) -> Report { Report() }
			}
			"""))
		#expect(result.errorSummary == ["assisted.singleton /App/Config.swift:3:8"])
	}

	@Test(arguments: [
		"@Service",
		"@Service(scope: .transient)",
	])
	func `Given an assisted provider without a singleton scope When generated Then it succeeds as a transient method`(attribute: String) throws {
		let result = generateWithContext(appFile("/App/Detail.swift", """
			\(attribute)
			final class Detail {
				init(@Assisted item: Item) {}
			}
			"""))
		expectOutput(result, contains: ["\tfunc detail(item: Item) -> Detail {\n\t\tDetail(item: item)\n\t}"])
		expectOutput(result, excludes: ["_swiftBeansRegistry.singleton"])
	}

	@Test
	func `Given a non-literal scope on an assisted provider When generated Then the generator adds no scope error`() {
		let result = generateWithContext(appFile("/App/Detail.swift", """
			@Service(scope: defaultScope)
			final class Detail {
				init(@Assisted item: Item) {}
			}
			"""))
		// The macro reports `scope.notLiteral`; the generator treats the provider as transient.
		expectOutput(result, contains: ["\tfunc detail(item: Item) -> Detail {"])
	}

	@Test
	func `Given unsupported assisted usage When generated Then each fails at its location`() {
		let result = generateWithContext(
			appFile("/App/Default.swift", """
				@Service
				final class WithDefault {
					init(@Assisted item: Item = Item()) {}
				}
				"""),
			appFile("/App/Variadic.swift", """
				@Service
				final class WithVariadic {
					init(@Assisted ids: Int...) {}
				}
				"""),
			appFile("/App/Inout.swift", """
				@Service
				final class WithInout {
					init(@Assisted item: inout Item) {}
				}
				"""),
			appFile("/App/Property.swift", """
				@Service
				final class WithProperty {
					@Assisted var item: Item
					init() {}
				}
				""")
		)
		#expect(result.output == nil)
		#expect(result.errorSummary == [
			"assisted.default /App/Default.swift:3:30",
			"assisted.inout /App/Inout.swift:3:7",
			"assisted.property /App/Property.swift:3:2",
			"assisted.variadic /App/Variadic.swift:3:7",
		])
	}

	@Test
	func `Given a memberwise struct with an assisted property When generated Then only the property error is reported`() {
		let result = generateWithContext(appFile("/App/Row.swift", """
			@Service
			struct Row {
				@Assisted let item: Item
			}
			"""))
		#expect(result.errorSummary == ["assisted.property /App/Row.swift:3:2"])
	}

	// MARK: - Recognition and edge cases

	@Test
	func `Given a qualified SwiftBeans attribute When generated Then it is recognized as assisted`() {
		let result = generateWithContext(appFile("/App/Detail.swift", """
			@Service
			final class Detail {
				init(@SwiftBeans.Assisted item: Item) {}
			}
			"""))
		expectOutput(result, contains: ["\tfunc detail(item: Item) -> Detail\n"])
	}

	@Test
	func `Given a foreign Assisted attribute When generated Then the parameter is an ordinary dependency`() {
		let result = generateWithContext(appFile("/App/Detail.swift", """
			@Service
			final class Detail {
				init(@Other.Assisted item: Item) {}
			}
			"""))
		#expect(result.errorSummary == ["graph.missingDependency /App/Detail.swift:3:7"])
	}

	@Test
	func `Given assisted parameters of unsupported key types When generated Then there is no key error`() {
		let result = generateWithContext(appFile("/App/Handler.swift", """
			@Service
			final class Handler {
				init(@Assisted onDone: (Int) -> Void, @Assisted count: Int?, @Assisted pair: (Int, Int)) {}
			}
			"""))
		expectOutput(result, contains: [
			"\tfunc handler(onDone: (Int) -> Void, count: Int?, pair: (Int, Int)) -> Handler {\n\t\tHandler(onDone: onDone, count: count, pair: pair)\n\t}",
		])
	}

	@Test
	func `Given a defaulted parameter with an assisted key When generated Then the default is kept`() {
		let result = generateWithContext(appFile("/App/Detail.swift", """
			@Service
			final class Detail {
				init(@Assisted item: Item) {}
			}

			@Service
			final class Consumer {
				init(detail: Detail? = nil) {}
			}
			"""))
		expectOutput(result, contains: ["\t\t\tConsumer()\n"])
		expectOutput(result, excludes: ["Consumer(detail:"])
	}

	@Test
	func `Given an assisted provider and a plain provider for one key When generated Then both are duplicates`() {
		let result = generateWithContext(
			appFile("/App/A.swift", """
				@Service
				final class Foo {
					init(@Assisted x: Int) {}
				}
				"""),
			appFile("/App/B.swift", """
				@Configuration
				enum Config {
					@Bean
					static func foo() -> Foo { Foo(x: 1) }
				}
				""")
		)
		#expect(result.errorSummary == [
			"graph.duplicateProvider /App/A.swift:1:1",
			"graph.duplicateProvider /App/B.swift:3:2",
		])
	}

	@Test
	func `Given an assisted provider with a cyclic injected parameter When generated Then the cycle is reported`() {
		let result = generateWithContext(appFile("/App/Cycle.swift", """
			@Service
			final class A {
				init(b: B, @Assisted x: Int) {}
			}

			@Service
			final class B {
				init(a: A) {}
			}
			"""))
		#expect(result.errorSummary.contains { $0.hasPrefix("assisted.notInjectable") })
		#expect(!result.errorSummary.contains { $0.hasPrefix("graph.cycle") }, "assisted providers are never dependencies")
	}

	@Test
	func `Given an assisted on a non-selected initializer When generated Then it has no effect`() {
		let result = generateWithContext(appFile("/App/Thing.swift", """
			@Service
			final class Thing {
				@Inject
				init(repository: ItemRepository) {}

				init(@Assisted x: Int, @Assisted y: Int = 0) {}
			}
			"""), repositoryFile)
		expectOutput(result, contains: [
			"\tvar thing: Thing { get }\n",
			"_swiftBeansRegistry.singleton(key: \"thing\")",
		])
		expectOutput(result, excludes: ["func thing"])
	}

	@Test
	func `Given an assisted provider whose key is spelled with any When generated Then the method returns any`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum Config {
				@Bean
				static func store(@Assisted name: String) -> any Store { MemoryStore() }
			}
			"""))
		expectOutput(result, contains: ["\tfunc store(name: String) -> any Store {\n\t\tConfig.store(name: name)\n\t}"])
	}
}
