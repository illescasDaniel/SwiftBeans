import Testing
@testable import SwiftBeansGeneratorCore

@Suite("Generator — SPEC inter-bean-call-diagnostic")
struct GeneratorDirectCallTests {
	private let database = """
		struct Database {}
		struct Repo { init(database: Database) {} }
		"""

	private func warnings(_ result: GenerationResult) -> [GeneratorDiagnostic] {
		result.diagnostics.filter { $0.id == "bean.directCall" }
	}

	private func summary(_ result: GenerationResult) -> [String] {
		warnings(result).map { "\($0.severity.rawValue) \($0.location)" }
	}

	@Test
	func `Given a bean calling another bean qualified When generated Then it warns and still generates`() throws {
		let source = """
			@Configuration
			enum AppConfiguration {
				@Bean
				static func database() -> Database { Database() }

				@Bean
				static func repo() -> Repo { Repo(database: AppConfiguration.database()) }
			}
			"""
		let result = generateWithContext(appFile("/App/Config.swift", database + "\n" + source))
		#expect(summary(result) == ["warning /App/Config.swift:9:46"])
		let warning = try #require(warnings(result).first)
		#expect(warning.message.contains("'AppConfiguration.repo'"))
		#expect(warning.message.contains("'AppConfiguration.database'"))
		#expect(warning.message.contains("parameter"))
		#expect(warning.message.contains("'database: Database'"))
		#expect(warning.notes.map(\.location.description) == ["/App/Config.swift:5:2"])
		#expect(warning.notes.allSatisfy { $0.severity == .note })
		#expect(result.errors.isEmpty)
		#expect(result.output != nil)
	}

	@Test
	func `Given only warnings When generated Then output equals output without the call`() throws {
		let direct = generateWithContext(appFile("/App/Config.swift", """
			struct Database {}
			struct Repo { init(database: Database) {} }
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
				@Bean static func repo() -> Repo { Repo(database: C.database()) }
			}
			"""))
		let injected = generateWithContext(appFile("/App/Config.swift", """
			struct Database {}
			struct Repo { init(database: Database) {} }
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
				@Bean static func repo() -> Repo { Repo(database: Database()) }
			}
			"""))
		#expect(warnings(direct).count == 1)
		#expect(warnings(injected).isEmpty)
		#expect(direct.output == injected.output)
		#expect(direct.output != nil)
	}

	@Test
	func `Given bare and Self calls When generated Then each warns`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
				@Bean static func a() -> A { A(database()) }
				@Bean static func b() -> B { B(Self.database()) }
			}
			"""))
		#expect(summary(result) == ["warning /App/Config.swift:4:33", "warning /App/Config.swift:5:33"])
	}

	@Test
	func `Given a call into another configuration When generated Then it warns`() {
		let result = generateWithContext(
			appFile("/App/A.swift", """
				@Configuration
				enum A {
					@Bean static func repo() -> Repo { Repo(B.database()) }
				}
				"""),
			appFile("/App/B.swift", """
				@Configuration
				enum B {
					@Bean static func database() -> Database { Database() }
				}
				""")
		)
		#expect(summary(result) == ["warning /App/A.swift:3:42"])
		#expect(warnings(result).first?.notes.map(\.location.description) == ["/App/B.swift:3:2"])
	}

	@Test
	func `Given the callee in an extension When generated Then the call is detected`() {
		let result = generateWithContext(
			appFile("/App/A.swift", """
				@Configuration
				enum A {
					@Bean static func repo() -> Repo { Repo(A.database()) }
				}
				"""),
			appFile("/App/Ext.swift", """
				extension A {
					@Bean static func database() -> Database { Database() }
				}
				""")
		)
		#expect(summary(result) == ["warning /App/A.swift:3:42"])
	}

	@Test
	func `Given a nested configuration When called by short or full name Then both warn`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			enum Outer {
				@Configuration
				enum Config {
					@Bean static func database() -> Database { Database() }
					@Bean static func a() -> A { A(Config.database()) }
					@Bean static func b() -> B { B(Outer.Config.database()) }
				}
			}
			"""))
		#expect(summary(result) == ["warning /App/Config.swift:5:34", "warning /App/Config.swift:6:34"])
	}

	@Test
	func `Given a service initializer calling a bean When generated Then it warns`() throws {
		let result = generateWithContext(appFile("/App/Service.swift", """
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
			}

			@Service
			final class UserService {
				let database: Database
				init() {
					database = C.database()
				}
			}
			"""))
		#expect(summary(result) == ["warning /App/Service.swift:10:14"])
		let warning = try #require(warnings(result).first)
		#expect(warning.message.contains("'UserService.init'"))
		#expect(result.output != nil)
	}

	@Test
	func `Given a service initializer in an extension calling a bean When generated Then it warns`() {
		let result = generateWithContext(appFile("/App/Service.swift", """
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
			}

			@Service
			final class UserService {}

			extension UserService {
				convenience init(unused: Int) {
					self.init()
					_ = C.database()
				}
			}
			"""))
		#expect(summary(result) == ["warning /App/Service.swift:12:7"])
	}

	@Test
	func `Given a call inside a closure When generated Then it warns`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
				@Bean static func lazyRepo() -> () -> Repo {
					{ Repo(C.database()) }
				}
			}
			"""))
		#expect(summary(result) == ["warning /App/Config.swift:5:10"])
	}

	@Test
	func `Given a bean taking the dependency as a parameter When generated Then nothing is reported`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
				@Bean static func repo(database: Database) -> Repo { Repo(database) }
			}
			"""))
		#expect(result.diagnostics.isEmpty, "\(result.renderedDiagnostics)")
	}

	@Test
	func `Given unrelated calls When generated Then nothing is reported`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
				static func helper() -> Int { 1 }
				@Bean static func repo() -> Repo {
					let other = Other.database()
					_ = Database()
					_ = helper()
					_ = C.helper()
					_ = self.database
					return Repo(other)
				}
			}
			enum Other {
				static func database() -> Database { Database() }
			}
			"""))
		#expect(warnings(result).isEmpty, "\(result.renderedDiagnostics)")
	}

	@Test
	func `Given a recursive bean When generated Then it is not reported`() {
		let result = generateWithContext(appFile("/App/Config.swift", """
			@Configuration
			enum C {
				@Bean static func counter() -> Counter { counter() }
				@Bean static func other() -> Other { Other(C.other()) }
			}
			"""))
		#expect(warnings(result).isEmpty)
	}

	@Test
	func `Given a non-service type initializer calling a bean When generated Then it is not reported`() {
		let result = generateWithContext(appFile("/App/Service.swift", """
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
			}

			final class Plain {
				init() { _ = C.database() }
			}
			"""))
		#expect(warnings(result).isEmpty)
	}

	@Test
	func `Given a target without a context When generated Then the warning is still reported`() {
		let result = SwiftBeansGeneration.generate(sources: [appFile("/App/Config.swift", """
			@Configuration
			enum C {
				@Bean static func database() -> Database { Database() }
				@Bean static func repo() -> Repo { Repo(C.database()) }
			}
			""")])
		#expect(summary(result) == ["warning /App/Config.swift:4:42"])
		#expect(result.errors.isEmpty)
	}

	@Test
	func `Given several direct calls across files When generated Then warnings are sorted and rendered`() throws {
		let result = generateWithContext(
			appFile("/App/Z.swift", """
				@Configuration
				enum Z {
					@Bean static func z() -> ZBean { ZBean(A.database()) }
				}
				"""),
			appFile("/App/A.swift", """
				@Configuration
				enum A {
					@Bean static func database() -> Database { Database() }
					@Bean static func repo() -> Repo { Repo(A.database()) }
				}
				""")
		)
		#expect(summary(result) == ["warning /App/A.swift:4:42", "warning /App/Z.swift:3:41"])
		let rendered = try #require(warnings(result).first?.rendered)
		#expect(rendered == """
			/App/A.swift:4:42: warning: @Bean 'A.repo' calls @Bean 'A.database' directly instead of receiving it from the context; \
			add a parameter 'database: Database' (a direct call bypasses the scope, so a singleton is created again)
			/App/A.swift:3:2: note: @Bean declared here
			""")
	}
}
