import Testing
@testable import SwiftBeansGeneratorCore

@Suite("Generator — SPEC Generator rules → Diagnostics")
struct GeneratorDiagnosticsTests {
	@Test
	func `Given a missing dependency When generated Then the error points at the parameter`() {
		let result = generateWithContext(appFile("/App/Services.swift", """
			@Service
			final class UserService {
				init(analytics: Analytics) {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errorSummary == ["graph.missingDependency /App/Services.swift:3:7"])
		#expect(result.errors.first?.rendered
			== "/App/Services.swift:3:7: error: missing dependency 'Analytics' required by 'UserService'")
	}

	@Test
	func `Given two providers for one key When generated Then each provider gets an error`() {
		let result = generateWithContext(
			appFile("/App/A.swift", """
				@Service
				final class Foo {
					init() {}
				}
				"""),
			appFile("/App/B.swift", """
				@Configuration
				enum Config {
					@Bean
					static func foo() -> Foo { Foo() }
				}
				""")
		)
		#expect(result.errorSummary == [
			"graph.duplicateProvider /App/A.swift:1:1",
			"graph.duplicateProvider /App/B.swift:3:2",
		])
	}

	@Test
	func `Given a dependency cycle When generated Then one error at the first provider with notes at the others`() throws {
		let result = generateWithContext(appFile("/App/Cycle.swift", """
			@Service
			final class A {
				init(b: B) {}
			}

			@Service
			final class B {
				init(a: A) {}
			}
			"""))
		#expect(result.errorSummary == ["graph.cycle /App/Cycle.swift:1:1"])
		let error = try #require(result.errors.first)
		#expect(error.notes.map(\.location.description) == ["/App/Cycle.swift:6:1"])
		#expect(error.notes.allSatisfy { $0.severity == .note })
		let note = try #require(error.notes.first)
		#expect(error.rendered.split(separator: "\n").map { String($0) } == [
			"/App/Cycle.swift:1:1: error: \(error.message)",
			"/App/Cycle.swift:6:1: note: \(note.message)",
		])
	}

	@Test
	func `Given several errors across files When generated twice Then all are reported in the same sorted order`() {
		let files = [
			appFile("/App/B.swift", """
				@Service
				final class Second {
					init(missing: MissingB) {}
				}
				"""),
			appFile("/App/A.swift", """
				@Service
				final class First {
					init(missing: MissingA) {}
				}

				@Service
				final class Dup {
					init() {}
				}

				@Service(boundTo: Dup.self)
				final class OtherDup {
					init() {}
				}
				"""),
			appContextFile,
		]
		let first = SwiftBeansGeneration.generate(sources: files)
		let second = SwiftBeansGeneration.generate(sources: files.reversed())
		#expect(first.errorSummary == [
			"graph.missingDependency /App/A.swift:3:7",
			"graph.duplicateProvider /App/A.swift:6:1",
			"graph.duplicateProvider /App/A.swift:11:1",
			"graph.missingDependency /App/B.swift:3:7",
		])
		#expect(second.diagnostics == first.diagnostics)
	}

	// MARK: - Macro-owned rules are not reported twice

	@Test(arguments: [
		// Non-static @Bean.
		"""
		@Configuration
		enum Config {
			@Bean
			func clock() -> AppClock { AppClock() }
		}
		""",
		// @Bean without a return type.
		"""
		@Configuration
		enum Config {
			@Bean
			static func setup() {}
		}
		""",
		// Throwing @Bean.
		"""
		@Configuration
		enum Config {
			@Bean
			static func database() throws -> Database { try Database() }
		}
		""",
		// Async @Bean.
		"""
		@Configuration
		enum Config {
			@Bean
			static func database() async -> Database { await Database() }
		}
		""",
		// @Service on a protocol.
		"""
		@Service
		protocol Store {}
		""",
	])
	func `Given misuse the macro reports When generated Then the generator reports nothing`(source: String) {
		let result = generateWithContext(appFile("/App/Misuse.swift", source))
		#expect(result.diagnostics.isEmpty, "\(result.renderedDiagnostics)")
	}

	@Test
	func `Given a non-literal scope When generated Then the generator keeps the bean and reports nothing`() {
		let result = generateWithContext(appFile("/App/Cache.swift", """
			@Service(scope: defaultScope)
			final class Cache {
				init() {}
			}
			"""))
		#expect(result.diagnostics.isEmpty, "\(result.renderedDiagnostics)")
		expectOutput(result, contains: ["var cache: Cache {"])
	}
}
