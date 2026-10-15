import Testing
@testable import SwiftBeansGeneratorCore

@Suite("Generator — SPEC Generator rules → Recognized declarations")
struct GeneratorRecognitionTests {
	@Test
	func `Given nested and qualified declarations When generated Then both are wired`() {
		let result = generateWithContext(appFile("/App/Search.swift", """
			enum Features {
				@Service
				final class Search {
					init() {}
				}
			}

			@SwiftBeans.Service
			final class Ranker {
				init(search: Features.Search) {}
			}
			"""))
		expectOutput(result, contains: [
			"var featuresSearch: Features.Search {",
			"Features.Search()",
			"var ranker: Ranker {",
			"Ranker(search: self.featuresSearch)",
		])
	}

	@Test
	func `Given a service declared inside an extension When generated Then its qualified name is used`() {
		let result = generateWithContext(appFile("/App/Outer.swift", """
			enum Outer {}

			extension Outer {
				@Service
				final class Inner {
					init() {}
				}
			}
			"""))
		expectOutput(result, contains: ["var outerInner: Outer.Inner {", "Outer.Inner()"])
	}

	@Test
	func `Given an attribute qualified with another module When generated Then it is ignored`() {
		let result = generateWithContext(appFile("/App/Other.swift", """
			@Other.Service
			final class NotABean {
				init() {}
			}
			"""))
		#expect(result.diagnostics.isEmpty, "\(result.renderedDiagnostics)")
		expectOutput(result, excludes: ["notABean", "NotABean"])
	}

	@Test
	func `Given an actor service When generated Then it is wired`() {
		let result = generateWithContext(appFile("/App/Counter.swift", """
			@Service
			actor Counter {
				init() {}
			}
			"""))
		expectOutput(result, contains: ["var counter: Counter {", "Counter()"])
	}

	@Test
	func `Given a bean in an extension of a configuration type in another file When generated Then it is wired`() {
		let result = generateWithContext(
			appFile("/App/AppConfiguration.swift", """
				@Configuration
				enum AppConfiguration {}
				"""),
			appFile("/App/AppConfiguration+Clock.swift", """
				extension AppConfiguration {
					@Bean
					static func clock() -> AppClock { AppClock() }
				}
				""")
		)
		expectOutput(result, contains: ["var appClock: AppClock {", "AppConfiguration.clock()"])
	}

	@Test
	func `Given a bean in a type that is not a configuration When generated Then the build fails at the bean`() {
		let result = generateWithContext(appFile("/App/Factories.swift", """
			enum Factories {
				@Bean
				static func clock() -> AppClock { AppClock() }
			}
			"""))
		#expect(result.errorSummary == ["bean.outsideConfiguration /App/Factories.swift:2:2"])
	}

	@Test
	func `Given a service inside an if-config block When generated Then the build fails at the attribute`() {
		let result = generateWithContext(appFile("/App/Debug.swift", """
			#if DEBUG
			@Service
			final class DebugMenu {
				init() {}
			}
			#endif
			"""))
		#expect(result.errorSummary == ["decl.conditional /App/Debug.swift:2:1"])
		#expect(result.errors.first?.message.contains("#if") == true)
	}

	@Test
	func `Given a bean inside an if-config block in a configuration When generated Then the build fails at the attribute`() {
		let result = generateWithContext(appFile("/App/Configuration.swift", """
			@Configuration
			enum AppConfiguration {
				#if DEBUG
				@Bean
				static func clock() -> AppClock { AppClock() }
				#endif
			}
			"""))
		#expect(result.errorSummary == ["decl.conditional /App/Configuration.swift:4:2"])
	}

	@Test
	func `Given a type declared inside a function body When generated Then it is not scanned`() {
		let result = generateWithContext(appFile("/App/Local.swift", """
			func makeSomething() {
				@Service
				final class Local {
					init() {}
				}
			}
			"""))
		#expect(result.diagnostics.isEmpty, "\(result.renderedDiagnostics)")
		expectOutput(result, excludes: ["Local"])
	}
}
