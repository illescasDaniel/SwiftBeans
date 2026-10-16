import Testing
@testable import SwiftBeansGeneratorCore

private let decodersFile = appFile("/App/Coding.swift", """
	@Configuration
	enum Coding {
		@Bean
		static func decoder() -> JSONDecoder { JSONDecoder() }

		@Bean(named: "snakeCase")
		static func snakeCaseDecoder() -> JSONDecoder { JSONDecoder() }
	}
	""")

@Suite("Generator — qualifiers SPEC")
struct GeneratorQualifierTests {
	// MARK: - Accessors and wiring

	@Test
	func `Given a named bean When generated Then it gets a qualified singleton accessor and protocol requirement`() {
		let result = generateWithContext(decodersFile)
		expectOutput(result, contains: [
			"\tvar jsonDecoder: JSONDecoder { get }\n\tvar snakeCaseJSONDecoder: JSONDecoder { get }\n",
			"""
				\tvar snakeCaseJSONDecoder: JSONDecoder {
				\t\t_swiftBeansRegistry.singleton(key: "snakeCaseJSONDecoder") {
				\t\t\tCoding.snakeCaseDecoder()
				\t\t}
				\t}
				""",
			"""
				\tvar jsonDecoder: JSONDecoder {
				\t\t_swiftBeansRegistry.singleton(key: "jsonDecoder") {
				\t\t\tCoding.decoder()
				\t\t}
				\t}
				""",
		])
	}

	@Test
	func `Given a qualified parameter When generated Then it receives the named bean and the unqualified one the default`() {
		let result = generateWithContext(decodersFile, appFile("/App/ItemParser.swift", """
			@Service
			final class ItemParser {
				init(@Qualifier("snakeCase") decoder: JSONDecoder, fallback: JSONDecoder) {}
			}
			"""))
		expectOutput(result, contains: [
			"ItemParser(decoder: self.snakeCaseJSONDecoder, fallback: self.jsonDecoder)",
		])
	}

	@Test
	func `Given the same name on two types When generated Then they are different beans`() {
		let result = generateWithContext(appFile("/App/Coding.swift", """
			@Configuration
			enum Coding {
				@Bean(named: "snakeCase")
				static func decoder() -> JSONDecoder { JSONDecoder() }

				@Bean(named: "snakeCase")
				static func encoder() -> JSONEncoder { JSONEncoder() }
			}
			"""))
		expectOutput(result, contains: [
			"\tvar snakeCaseJSONDecoder: JSONDecoder { get }\n\tvar snakeCaseJSONEncoder: JSONEncoder { get }\n",
		])
	}

	@Test
	func `Given named services bound to a protocol When generated Then qualified parameters receive them`() {
		let result = generateWithContext(appFile("/App/Sync.swift", """
			protocol Store {}

			@Service(boundTo: Store.self, named: "memory")
			final class MemoryStore: Store {
				init() {}
			}

			@Service(named: "shared", scope: .transient)
			final class DiskCache {
				init() {}
			}

			@Service
			final class Sync {
				init(@Qualifier("memory") store: any Store, @SwiftBeans.Qualifier("shared") cache: DiskCache) {}
			}
			"""))
		expectOutput(result, contains: [
			"\tvar memoryStore: any Store { get }\n",
			"\tvar sharedDiskCache: DiskCache { get }\n",
			"\tvar sharedDiskCache: DiskCache {\n\t\tDiskCache()\n\t}",
			"Sync(store: self.memoryStore, cache: self.sharedDiskCache)",
		])
		expectOutput(result, excludes: ["var store", "var diskCache"])
	}

	@Test
	func `Given a qualified bean parameter and a named assisted service When generated Then both use qualified names`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum Config {
				@Bean(named: "public")
				static func publicSession() -> URLSession { .shared }

				@Bean
				static func api(@Qualifier("public") session: URLSession) -> API { API() }
			}

			@Service(named: "draft")
			final class Editor {
				init(@Assisted text: String) {}
			}
			"""))
		expectOutput(result, contains: [
			"Config.api(session: self.publicURLSession)",
			"\tfunc draftEditor(text: String) -> Editor\n",
			"\tfunc draftEditor(text: String) -> Editor {\n\t\tEditor(text: text)\n\t}",
		])
	}

	@Test
	func `Given a qualifier on another initializer When generated Then it has no effect`() {
		let result = generateWithContext(decodersFile, appFile("/App/ItemParser.swift", """
			@Service
			final class ItemParser {
				@Inject
				init(decoder: JSONDecoder) {}

				init(@Qualifier("nope") other: JSONDecoder, @Qualifier(bad) x: Int) {}
			}
			"""))
		expectOutput(result, contains: ["ItemParser(decoder: self.jsonDecoder)"])
	}

	// MARK: - Missing and ambiguous

	@Test
	func `Given an unknown qualifier When generated Then the error is at the parameter with notes at same-type providers`() throws {
		let result = generateWithContext(decodersFile, appFile("/App/ItemParser.swift", """
			@Service
			final class ItemParser {
				init(@Qualifier("camelCase") decoder: JSONDecoder) {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errorSummary == ["graph.missingDependency /App/ItemParser.swift:3:7"])
		let error = try #require(result.errors.first)
		#expect(error.message == #"missing dependency 'JSONDecoder' named "camelCase" required by 'ItemParser'"#)
		#expect(error.notes.map(\.id) == ["graph.didYouMean", "graph.didYouMean"])
		#expect(error.notes.map(\.location.description) == ["/App/Coding.swift:3:2", "/App/Coding.swift:6:2"])
		#expect(error.notes.map(\.message) == [
			"did you mean 'JSONDecoder' (provided by 'Coding.decoder')?",
			#"did you mean 'JSONDecoder' named "snakeCase" (provided by 'Coding.snakeCaseDecoder')?"#,
		])
	}

	@Test(arguments: [1, 2])
	func `Given only named providers When an unqualified parameter needs the type Then the build fails at the parameter`(namedCount: Int) throws {
		let beans = ["snakeCase", "camelCase"].prefix(namedCount).map { name in
			"\t@Bean(named: \"\(name)\")\n\tstatic func \(name)() -> JSONDecoder { JSONDecoder() }\n"
		}.joined()
		let result = generateWithContext(
			appFile("/App/Coding.swift", "@Configuration\nenum Coding {\n\(beans)}\n"),
			appFile("/App/ItemParser.swift", """
				@Service
				final class ItemParser {
					init(decoder: JSONDecoder) {}
				}
				""")
		)
		#expect(result.output == nil)
		#expect(result.errorSummary == ["graph.missingDependency /App/ItemParser.swift:3:7"])
		let error = try #require(result.errors.first)
		#expect(error.message.contains("only named providers exist"), "\(error.message)")
		#expect(error.message.contains("'JSONDecoder'"), "\(error.message)")
		let expectedNotes = [#"use @Qualifier("snakeCase") for 'Coding.snakeCase'"#, #"use @Qualifier("camelCase") for 'Coding.camelCase'"#]
		#expect(Set(error.notes.map(\.message)) == Set(expectedNotes.prefix(namedCount)))
		#expect(error.notes.allSatisfy { $0.id == "graph.namedCandidate" })
	}

	@Test
	func `Given defaulted parameters without matching providers When generated Then both keep their defaults`() {
		let result = generateWithContext(appFile("/App/Coding.swift", """
			@Configuration
			enum Coding {
				@Bean(named: "snakeCase")
				static func snakeCaseDecoder() -> JSONDecoder { JSONDecoder() }
			}
			"""), appFile("/App/ItemParser.swift", """
			@Service
			final class ItemParser {
				init(@Qualifier("missing") decoder: JSONDecoder = JSONDecoder(), plain: JSONDecoder = JSONDecoder()) {}
			}
			"""))
		expectOutput(result, contains: ["\t\t\tItemParser()\n"])
	}

	@Test
	func `Given a defaulted qualified parameter with a matching provider When generated Then it is injected`() {
		let result = generateWithContext(decodersFile, appFile("/App/ItemParser.swift", """
			@Service
			final class ItemParser {
				init(@Qualifier("snakeCase") decoder: JSONDecoder = JSONDecoder()) {}
			}
			"""))
		expectOutput(result, contains: ["ItemParser(decoder: self.snakeCaseJSONDecoder)"])
	}

	// MARK: - Duplicates and collisions

	@Test
	func `Given two providers with the same type and name When generated Then both are duplicates`() throws {
		let result = generateWithContext(appFile("/App/Coding.swift", """
			@Configuration
			enum Coding {
				@Bean(named: "snakeCase")
				static func a() -> JSONDecoder { JSONDecoder() }

				@Bean(named: "snakeCase")
				static func b() -> JSONDecoder { JSONDecoder() }
			}
			"""))
		#expect(result.errorSummary == [
			"graph.duplicateProvider /App/Coding.swift:3:2",
			"graph.duplicateProvider /App/Coding.swift:6:2",
		])
		let message = try #require(result.errors.first?.message)
		#expect(message == #"duplicate provider for 'JSONDecoder' named "snakeCase"; also provided by 'Coding.b'"#)
	}

	@Test
	func `Given a qualified accessor equal to a type's accessor When generated Then both declarations fail`() throws {
		let result = generateWithContext(appFile("/App/Coding.swift", """
			@Configuration
			enum Coding {
				@Bean(named: "snakeCase")
				static func a() -> JSONDecoder { JSONDecoder() }
			}

			@Service
			final class SnakeCaseJSONDecoder {
				init() {}
			}
			"""))
		#expect(result.errorSummary == [
			"graph.accessorCollision /App/Coding.swift:3:2",
			"graph.accessorCollision /App/Coding.swift:7:1",
		])
		let message = try #require(result.errors.first?.message)
		#expect(message == #"accessor name 'snakeCaseJSONDecoder' is produced by both 'JSONDecoder' named "snakeCase" and 'SnakeCaseJSONDecoder'; rename a qualifier or bind one of them to a different type"#)
	}

	@Test
	func `Given names differing only in leading case When generated Then their accessors collide`() {
		let result = generateWithContext(appFile("/App/Coding.swift", """
			@Configuration
			enum Coding {
				@Bean(named: "snakeCase")
				static func a() -> JSONDecoder { JSONDecoder() }

				@Bean(named: "SnakeCase")
				static func b() -> JSONDecoder { JSONDecoder() }
			}
			"""))
		#expect(result.errorSummary == [
			"graph.accessorCollision /App/Coding.swift:3:2",
			"graph.accessorCollision /App/Coding.swift:6:2",
		])
	}

	// MARK: - Invalid usage

	@Test(arguments: [
		("@Qualifier(name)", "qualifier.notLiteral", 18),
		("@Qualifier(\"2x\")", "qualifier.invalidName", 18),
		("@Qualifier(\"a\\(b)\")", "qualifier.notLiteral", 18),
		("@Qualifier", "qualifier.missingName", 7),
		("@Qualifier(name: \"x\")", "qualifier.missingName", 7),
	])
	func `Given an invalid Qualifier on a selected initializer When generated Then the error is at the attribute or name`(
		attribute: String,
		id: String,
		column: Int
	) {
		let result = generateWithContext(decodersFile, appFile("/App/ItemParser.swift", """
			@Service
			final class ItemParser {
				init(\(attribute) decoder: JSONDecoder) {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errorSummary == ["\(id) /App/ItemParser.swift:3:\(column)"], "\(result.renderedDiagnostics)")
	}

	@Test
	func `Given a Qualifier on a stored property or with Assisted When generated Then each attribute fails`() {
		let result = generateWithContext(decodersFile, appFile("/App/Misuse.swift", """
			@Service
			struct Settings {
				@Qualifier("snakeCase") var decoder: JSONDecoder
			}

			@Service
			final class Editor {
				init(@Assisted @Qualifier("snakeCase") decoder: JSONDecoder) {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errorSummary == [
			"qualifier.property /App/Misuse.swift:3:2",
			"qualifier.assisted /App/Misuse.swift:8:17",
		], "\(result.renderedDiagnostics)")
	}

	@Test
	func `Given a Qualifier from another module When generated Then it is ignored`() {
		let result = generateWithContext(decodersFile, appFile("/App/ItemParser.swift", """
			@Service
			final class ItemParser {
				init(@Other.Qualifier("snakeCase") decoder: JSONDecoder) {}
			}
			"""))
		expectOutput(result, contains: ["ItemParser(decoder: self.jsonDecoder)"])
	}

	@Test(arguments: ["named: prefix", "named: \"snake-case\"", "named: \"\""])
	func `Given an invalid named argument When generated Then the generator leaves it to the macro`(argument: String) {
		let result = generateWithContext(appFile("/App/Coding.swift", """
			@Configuration
			enum Coding {
				@Bean(\(argument))
				static func decoder() -> JSONDecoder { JSONDecoder() }
			}
			"""))
		#expect(result.errors.isEmpty, "\(result.renderedDiagnostics)")
		expectOutput(result, excludes: ["Coding.decoder()"])
	}

	// MARK: - Compatibility

	@Test
	func `Given a graph without qualifiers When generated Then the output is byte-identical to the pre-qualifier generator`() {
		let result = SwiftBeansGeneration.generate(sources: unqualifiedGraph)
		#expect(result.errors.isEmpty, "\(result.renderedDiagnostics)")
		#expect(result.output == unqualifiedGraphOutput)
	}
}

/// Covers singletons, transients, `any` bindings, collections, nested types, keyword accessors,
/// defaulted parameters, assisted providers and conditional imports.
private let unqualifiedGraph: [SourceFile] = [
	appFile("/App/AppContext.swift", """
		import Foundation
		@preconcurrency import Legacy

		@ApplicationContext
		final class AppContext {}
		"""),
	appFile("/App/Config.swift", """
		#if canImport(UIKit)
		import UIKit
		#endif

		@Configuration
		enum AppConfiguration {
			@Bean
			static func urlSession() -> URLSession { .shared }

			@Bean(scope: .transient)
			static func decoder() -> JSONDecoder { JSONDecoder() }

			@Bean
			static func limits() -> [String: Int] { [:] }

			@Bean
			static func report(store: any Store, @Assisted title: String) -> Report { Report() }
		}
		"""),
	appFile("/App/Services.swift", """
		protocol Store {}

		@Service(boundTo: Store.self)
		final class MemoryStore: Store {
			init(session: URLSession, decoder: JSONDecoder) {}
		}

		enum Features {
			@Service(scope: .transient)
			struct Search {
				var limits: Dictionary<String, Int>
				var retries: Int = 3
			}
		}

		@Service
		final class Class {
			init(store: Store, search: Features.Search, clock: Clock = .system) {}
		}

		@Service
		final class ItemDetailViewModel {
			init(store: any Store, @Assisted _ item: Item, @Assisted page pageIndex: Int) {}
		}
		"""),
]

/// Captured from the generator at `main` 6b04703, before qualifiers existed.
private let unqualifiedGraphOutput = """
	// Generated by SwiftBeans — do not edit.
	import Foundation
	import SwiftBeans
	@preconcurrency import Legacy
	#if canImport(UIKit)
	import UIKit
	#endif

	protocol AppContextProtocol: AnyObject {
		var `class`: Class { get }
		var featuresSearch: Features.Search { get }
		func itemDetailViewModel(_ item: Item, page pageIndex: Int) -> ItemDetailViewModel
		var jsonDecoder: JSONDecoder { get }
		func report(title: String) -> Report
		var store: any Store { get }
		var stringIntDictionary: [String: Int] { get }
		var urlSession: URLSession { get }
	}

	extension AppContext {
		var `class`: Class {
			_swiftBeansRegistry.singleton(key: "class") {
				Class(store: self.store, search: self.featuresSearch)
			}
		}

		var featuresSearch: Features.Search {
			Features.Search(limits: self.stringIntDictionary)
		}

		func itemDetailViewModel(_ item: Item, page pageIndex: Int) -> ItemDetailViewModel {
			ItemDetailViewModel(store: self.store, item, page: pageIndex)
		}

		var jsonDecoder: JSONDecoder {
			AppConfiguration.decoder()
		}

		func report(title: String) -> Report {
			AppConfiguration.report(store: self.store, title: title)
		}

		var store: any Store {
			_swiftBeansRegistry.singleton(key: "store") {
				MemoryStore(session: self.urlSession, decoder: self.jsonDecoder)
			}
		}

		var stringIntDictionary: [String: Int] {
			_swiftBeansRegistry.singleton(key: "stringIntDictionary") {
				AppConfiguration.limits()
			}
		}

		var urlSession: URLSession {
			_swiftBeansRegistry.singleton(key: "urlSession") {
				AppConfiguration.urlSession()
			}
		}
	}

	extension AppContext: AppContextProtocol {}

	"""
