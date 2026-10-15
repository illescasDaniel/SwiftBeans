import Testing
@testable import SwiftBeansGeneratorCore

@Suite("Generator — SPEC Generator rules → Providers and dependencies")
struct GeneratorProviderTests {
	private let storeFile = appFile("/App/Store.swift", """
		@Service(boundTo: Store.self)
		final class DiskStore: Store {
			init() {}
		}
		""")

	// MARK: - Initializer selection

	@Test
	func `Given several initializers and one marked Inject When generated Then the marked one is called`() {
		let result = generateWithContext(storeFile, appFile("/App/ReportService.swift", """
			@Service
			final class ReportService {
				@Inject
				init(store: any Store) {}

				convenience init() {
					fatalError()
				}
			}
			"""))
		expectOutput(result, contains: ["ReportService(store: self.store)"])
	}

	@Test(arguments: [
		// No @Inject.
		"""
		@Service
		final class ReportService {
			init(store: any Store) {}

			convenience init() {
				fatalError()
			}
		}
		""",
		// Two @Inject.
		"""
		@Service
		final class ReportService {
			@Inject
			init(store: any Store) {}

			@Inject
			convenience init() {
				fatalError()
			}
		}
		""",
	])
	func `Given several initializers without exactly one Inject When generated Then the build fails listing them`(source: String) throws {
		let result = generateWithContext(storeFile, appFile("/App/ReportService.swift", source))
		#expect(result.errorSummary == ["init.ambiguous /App/ReportService.swift:1:1"])
		let error = try #require(result.errors.first)
		#expect(error.message.contains("@Inject"))
		#expect(error.notes.count == 2)
	}

	@Test
	func `Given private and failable initializers When generated Then they are not candidates`() {
		let result = generateWithContext(appFile("/App/Session.swift", """
			@Service
			final class Token {
				init() {}
			}

			@Service
			final class Session {
				init(token: Token) {}
				private init() {}
				fileprivate init(other: Int) {}
				init?(raw: String) { nil }
			}
			"""))
		expectOutput(result, contains: ["Session(token: self.token)"])
	}

	@Test
	func `Given the only initializer is declared in an extension in another file When generated Then it is used`() {
		let result = generateWithContext(
			appFile("/App/Clock.swift", """
				@Service
				final class AppClock {
					init() {}
				}
				"""),
			appFile("/App/A.swift", """
				@Service
				final class A {}
				"""),
			appFile("/App/A+Init.swift", """
				extension A {
					convenience init(clock: AppClock) {
						self.init()
					}
				}
				""")
		)
		expectOutput(result, contains: ["A(clock: self.appClock)"])
	}

	@Test
	func `Given a struct without an initializer When generated Then its memberwise initializer is used`() {
		let result = generateWithContext(appFile("/App/B.swift", """
			@Service
			final class A {
				init() {}
			}

			@Service
			struct B {
				let a: A
				var retries: Int = 3
				let name = "b"
				static var shared = 0
				lazy var cache: [String] = []
				var computed: Int { 1 }
			}
			"""))
		expectOutput(result, contains: ["B(a: self.a)"])
		expectOutput(result, excludes: ["retries:", "name:", "shared:", "cache:", "computed:"])
	}

	@Test
	func `Given a memberwise var with a default and a provider for its type When generated Then it is injected`() {
		let result = generateWithContext(appFile("/App/B.swift", """
			@Configuration
			enum AppConfiguration {
				@Bean
				static func retries() -> Int { 5 }
			}

			@Service
			struct B {
				var retries: Int = 3
			}
			"""))
		expectOutput(result, contains: ["B(retries: self.int)"])
	}

	@Test
	func `Given a class without an initializer When generated Then init() is used`() {
		let result = generateWithContext(appFile("/App/Plain.swift", """
			@Service
			final class Plain {
				let x = 1
			}
			"""))
		expectOutput(result, contains: ["Plain()"])
	}

	@Test
	func `Given a struct with a property wrapper and no initializer When generated Then the build fails`() {
		let result = generateWithContext(appFile("/App/Settings.swift", """
			@Service
			struct Settings {
				@Clamped var volume: Int
			}
			"""))
		#expect(result.errorSummary == ["init.propertyWrapper /App/Settings.swift:1:1"])
	}

	@Test(arguments: ["throws", "async", "async throws"])
	func `Given a selected initializer with effects When generated Then the build fails at the initializer`(effects: String) {
		let result = generateWithContext(appFile("/App/Database.swift", """
			@Service
			final class Database {
				init() \(effects) {}
			}
			"""))
		#expect(result.errorSummary == ["init.effects /App/Database.swift:3:2"])
	}

	// MARK: - Defaulted parameters

	@Test
	func `Given a defaulted parameter whose key is not provided When generated Then its default is used`() {
		let result = generateWithContext(appFile("/App/Feed.swift", """
			@Service
			final class API {
				init() {}
			}

			@Service
			final class Feed {
				init(api: API, clock: Clock = .system) {}
			}
			"""))
		expectOutput(result, contains: ["Feed(api: self.api)"])
	}

	@Test
	func `Given a defaulted parameter whose key is provided When generated Then it is injected`() {
		let result = generateWithContext(appFile("/App/Feed.swift", """
			@Service
			final class API {
				init() {}
			}

			@Configuration
			enum AppConfiguration {
				@Bean
				static func clock() -> Clock { .system }
			}

			@Service
			final class Feed {
				init(api: API, clock: Clock = .system) {}
			}
			"""))
		expectOutput(result, contains: ["Feed(api: self.api, clock: self.clock)"])
	}

	@Test
	func `Given an optional defaulted parameter When generated Then it is looked up by its wrapped type`() {
		let withProvider = generateWithContext(appFile("/App/Consumer.swift", """
			@Service
			final class Logger {
				init() {}
			}

			@Service
			final class Consumer {
				init(logger: Logger? = nil) {}
			}
			"""))
		expectOutput(withProvider, contains: ["Consumer(logger: self.logger)"])

		let withoutProvider = generateWithContext(appFile("/App/Consumer.swift", """
			@Service
			final class Consumer {
				init(logger: Logger? = nil) {}
			}
			"""))
		expectOutput(withoutProvider, contains: ["Consumer()"])
	}

	@Test
	func `Given a defaulted parameter that is not provided When validated Then it is not a cycle edge`() {
		let result = generateWithContext(appFile("/App/Pair.swift", """
			@Service
			final class A {
				init(b: B) {}
			}

			@Service
			final class B {
				init(a: OtherA = OtherA()) {}
			}
			"""))
		expectOutput(result, contains: ["A(b: self.b)", "B()"])
	}

	@Test
	func `Given a bean with a defaulted parameter When generated Then the rules match initializers`() {
		let result = generateWithContext(appFile("/App/Configuration.swift", """
			@Configuration
			enum AppConfiguration {
				@Bean
				static func feed(limit: Int = 20) -> Feed { Feed(limit: limit) }
			}
			"""))
		expectOutput(result, contains: ["AppConfiguration.feed()"])
	}
}
