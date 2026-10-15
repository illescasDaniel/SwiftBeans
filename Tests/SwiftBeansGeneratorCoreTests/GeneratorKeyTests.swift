import Testing
@testable import SwiftBeansGeneratorCore

@Suite("Generator — SPEC Generator rules → Injectable keys and accessor names")
struct GeneratorKeyTests {
	@Test
	func `Given a protocol spelled with and without any When generated Then it is one key typed any`() throws {
		let result = generateWithContext(appFile("/App/Store.swift", """
			@Service(boundTo: Store.self)
			final class DiskStore: Store {
				init() {}
			}

			@Service
			final class Repo {
				init(store: any Store) {}
			}
			"""))
		expectOutput(result, contains: [
			"var store: any Store { get }",
			"var store: any Store {\n",
			"Repo(store: self.store)",
		])
		let output = try #require(result.output)
		#expect(occurrences(of: "var store:", in: output) == 2) // protocol requirement + accessor
	}

	@Test
	func `Given equivalent spellings of one type When generated Then provider and consumer match`() {
		let result = generateWithContext(appFile("/App/Scores.swift", """
			@Configuration
			enum AppConfiguration {
				@Bean
				static func scores() -> [String:Int] { [:] }

				@Bean
				static func names() -> Array<String> { [] }
			}

			@Service
			final class Leaderboard {
				init(scores: Dictionary<String, Int>, names: [String], store: (any Store)) {}
			}

			@Service(boundTo: Store.self)
			final class DiskStore: Store {
				init() {}
			}
			"""))
		expectOutput(result, contains: [
			"var stringIntDictionary: [String: Int] {",
			"var stringArray: [String] {",
			"Leaderboard(scores: self.stringIntDictionary, names: self.stringArray, store: self.store)",
		])
	}

	@Test
	func `Given a qualified spelling of a provided type When generated Then the missing dependency suggests the match`() throws {
		let result = generateWithContext(appFile("/App/Logging.swift", """
			@Service
			final class Logger {
				init() {}
			}

			@Service
			final class Feed {
				init(logger: Diagnostics.Logger) {}
			}
			"""))
		#expect(result.errorSummary == ["graph.missingDependency /App/Logging.swift:8:7"])
		let error = try #require(result.errors.first)
		#expect(error.rendered.contains("did you mean 'Logger'"), "\(error.rendered)")
	}

	@Test(arguments: [
		"Logger?",
		"Logger!",
		"(Int, String)",
		"() -> Void",
		"some View",
		"Int.Type",
		"any Reader & Writer",
	])
	func `Given a bean returning an unsupported key When generated Then the build fails at the return type`(returnType: String) {
		let result = generateWithContext(appFile("/App/Configuration.swift", """
			@Configuration
			enum AppConfiguration {
				@Bean
				static func logger() -> \(returnType) { fatalError() }
			}
			"""))
		#expect(result.errorSummary == ["key.unsupported /App/Configuration.swift:4:26"])
	}

	@Test
	func `Given an optional parameter without a default When generated Then the build fails at its type`() {
		let result = generateWithContext(appFile("/App/Feed.swift", """
			@Service
			final class Feed {
				init(logger: Logger?) {}
			}
			"""))
		#expect(result.errorSummary == ["key.unsupported /App/Feed.swift:3:15"])
		#expect(result.errors.first?.message.contains("optional") == true)
	}

	@Test
	func `Given keys of every supported shape When generated Then accessor names are valid identifiers`() {
		let result = generateWithContext(appFile("/App/Shapes.swift", """
			@Configuration
			enum AppConfiguration {
				@Bean
				static func tags() -> [String] { [] }

				@Bean
				static func userCache() -> Cache<User> { Cache() }

				@Bean
				static func klass() -> Class { Class() }
			}

			enum Outer {
				@Service
				final class Inner {
					init() {}
				}
			}
			"""))
		expectOutput(result, contains: [
			"var stringArray: [String] {",
			"var userCache: Cache<User> {",
			"var `class`: Class {",
			"_swiftBeansRegistry.singleton(key: \"class\")",
			"var outerInner: Outer.Inner {",
		])
	}

	@Test
	func `Given two keys with the same accessor name When generated Then each provider gets an error`() {
		let result = generateWithContext(
			appFile("/App/A.swift", """
				@Service
				final class HTTPClient {
					init() {}
				}
				"""),
			appFile("/App/B.swift", """
				@Configuration
				enum Config {
					@Bean
					static func client() -> HttpClient { HttpClient() }
				}
				""")
		)
		#expect(result.errorSummary == [
			"graph.accessorCollision /App/A.swift:1:1",
			"graph.accessorCollision /App/B.swift:3:2",
		])
		#expect(result.errors.allSatisfy { $0.message.contains("httpClient") })
	}
}
