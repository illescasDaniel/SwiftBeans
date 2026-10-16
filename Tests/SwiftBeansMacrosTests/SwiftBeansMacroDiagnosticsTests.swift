import SwiftBeansMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

private let macroSpecs: [String: MacroSpec] = [
	"ApplicationContext": MacroSpec(type: ApplicationContextMacro.self),
	"Configuration": MacroSpec(type: ConfigurationMacro.self),
	"Bean": MacroSpec(type: BeanMacro.self),
	"Service": MacroSpec(type: ServiceMacro.self),
	"Inject": MacroSpec(type: InjectMacro.self),
]

/// Expands `source` with every SwiftBeans macro and checks the diagnostics (position is 1-based; a tab is one column).
private func expectExpansion(
	_ source: String,
	expandedSource: String,
	diagnostics: [DiagnosticSpec] = [],
	sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
	assertMacroExpansion(
		source,
		expandedSource: expandedSource,
		diagnostics: diagnostics,
		macroSpecs: macroSpecs,
		indentationWidth: .tabs(1),
		failureHandler: { Issue.record("\($0.message)", sourceLocation: sourceLocation) }
	)
}

@Suite("SwiftBeans macros — SPEC Behavioral rule 4: single-declaration misuse")
struct SwiftBeansMacroDiagnosticsTests {
	// MARK: - @Bean

	@Test
	func `Given a non-static Bean When expanded Then the error is at the func keyword`() {
		expectExpansion(
			"""
			enum AppConfiguration {
				@Bean
				func urlSession() -> Int { 0 }
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				func urlSession() -> Int { 0 }
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Bean methods must be static", line: 3, column: 2)]
		)
	}

	@Test
	func `Given a Bean without a return type When expanded Then the error is at the function name`() {
		expectExpansion(
			"""
			enum AppConfiguration {
				@Bean
				static func make() {}
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				static func make() {}
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Bean methods must declare a return type", line: 3, column: 14)]
		)
	}

	@Test(arguments: [
		("throws", "@Bean methods cannot throw; generated accessors are non-throwing"),
		("async", "@Bean methods cannot be async; generated accessors are synchronous"),
	])
	func `Given a Bean with an effect When expanded Then the error is at the effect keyword`(effect: String, message: String) {
		expectExpansion(
			"""
			enum AppConfiguration {
				@Bean
				static func a() \(effect) -> A { A() }
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				static func a() \(effect) -> A { A() }
			}
			""",
			diagnostics: [DiagnosticSpec(message: message, line: 3, column: 18)]
		)
	}

	@Test
	func `Given a Bean that is async and throws When expanded Then both effects are reported`() {
		expectExpansion(
			"""
			enum AppConfiguration {
				@Bean
				static func a() async throws -> A { A() }
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				static func a() async throws -> A { A() }
			}
			""",
			diagnostics: [
				DiagnosticSpec(message: "@Bean methods cannot be async; generated accessors are synchronous", line: 3, column: 18),
				DiagnosticSpec(message: "@Bean methods cannot throw; generated accessors are non-throwing", line: 3, column: 24),
			]
		)
	}

	@Test
	func `Given a generic Bean When expanded Then the error is at the generic clause`() {
		expectExpansion(
			"""
			enum AppConfiguration {
				@Bean
				static func a<T>() -> T { fatalError() }
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				static func a<T>() -> T { fatalError() }
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Bean methods cannot be generic", line: 3, column: 15)]
		)
	}

	@Test
	func `Given Bean on a property When expanded Then the error is at the attribute`() {
		expectExpansion(
			"""
			enum AppConfiguration {
				@Bean
				static var session = 1
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				static var session = 1
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Bean can only be applied to a static function", line: 2, column: 2)]
		)
	}

	@Test
	func `Given a valid Bean When expanded Then there are no diagnostics`() {
		expectExpansion(
			"""
			enum AppConfiguration {
				@Bean(scope: .transient)
				static func validator(clock: Clock = .system) -> Validator { Validator() }
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				static func validator(clock: Clock = .system) -> Validator { Validator() }
			}
			"""
		)
	}

	// MARK: - scope:

	@Test
	func `Given a Bean with a non-literal scope When expanded Then the error is at the argument`() {
		expectExpansion(
			"""
			enum AppConfiguration {
				@Bean(scope: myScope)
				static func a() -> A { A() }
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				static func a() -> A { A() }
			}
			""",
			diagnostics: [DiagnosticSpec(message: "scope must be '.singleton' or '.transient'", line: 2, column: 15)]
		)
	}

	@Test
	func `Given a Service with a non-literal scope When expanded Then the error is at the argument`() {
		expectExpansion(
			"""
			@Service(scope: s)
			final class Cache {
			}
			""",
			expandedSource: """
			final class Cache {
			}
			""",
			diagnostics: [DiagnosticSpec(message: "scope must be '.singleton' or '.transient'", line: 1, column: 17)]
		)
	}

	@Test(arguments: [
		".singleton",
		".transient",
		"BeanScope.singleton",
		"BeanScope.transient",
		"SwiftBeans.BeanScope.singleton",
		"SwiftBeans.BeanScope.transient",
	])
	func `Given a literal scope spelling When expanded Then there are no diagnostics`(scope: String) {
		expectExpansion(
			"""
			@Service(boundTo: Store.self, scope: \(scope))
			final class DiskStore {
			}
			""",
			expandedSource: """
			final class DiskStore {
			}
			"""
		)
	}

	// MARK: - named:

	@Test(arguments: [
		"@Bean(named: \"snakeCase\")",
		"@Bean(named: \"_test2\", scope: .transient)",
		"@Bean(named: #\"raw\"#)",
	])
	func `Given a Bean with a literal name When expanded Then there are no diagnostics`(attribute: String) {
		expectExpansion(
			"""
			enum Coding {
				\(attribute)
				static func decoder() -> JSONDecoder { JSONDecoder() }
			}
			""",
			expandedSource: """
			enum Coding {
				static func decoder() -> JSONDecoder { JSONDecoder() }
			}
			"""
		)
	}

	@Test(arguments: [
		"@Service(named: \"memory\")",
		"@Service(named: \"memory\", scope: .transient)",
		"@Service(boundTo: Store.self, named: \"memory\")",
		"@Service(boundTo: Store.self, named: \"memory\", scope: .singleton)",
	])
	func `Given a Service with a literal name When expanded Then there are no diagnostics`(attribute: String) {
		expectExpansion(
			"""
			\(attribute)
			final class MemoryStore {
			}
			""",
			expandedSource: """
			final class MemoryStore {
			}
			"""
		)
	}

	@Test(arguments: [
		("named: prefix", "named: must be a string literal"),
		("named: \"snake\\(x)\"", "named: must be a string literal"),
		("named: \"snake-case\"", "qualifier name \"snake-case\" must start with a letter or '_' and contain only letters, digits and '_'"),
		("named: \"\"", "qualifier name \"\" must start with a letter or '_' and contain only letters, digits and '_'"),
		("named: \"1st\"", "qualifier name \"1st\" must start with a letter or '_' and contain only letters, digits and '_'"),
	])
	func `Given a Bean with an invalid name When expanded Then the error is at the argument`(argument: String, message: String) {
		expectExpansion(
			"""
			enum Coding {
				@Bean(\(argument))
				static func decoder() -> JSONDecoder { JSONDecoder() }
			}
			""",
			expandedSource: """
			enum Coding {
				static func decoder() -> JSONDecoder { JSONDecoder() }
			}
			""",
			diagnostics: [DiagnosticSpec(message: message, line: 2, column: 15)]
		)
	}

	@Test
	func `Given a Service with an invalid name When expanded Then the error is at the argument`() {
		expectExpansion(
			"""
			@Service(boundTo: Store.self, named: Names.memory)
			final class MemoryStore {
			}
			""",
			expandedSource: """
			final class MemoryStore {
			}
			""",
			diagnostics: [DiagnosticSpec(message: "named: must be a string literal", line: 1, column: 38)]
		)
	}

	// MARK: - @Service

	@Test(arguments: ["protocol Store", "enum Store"])
	func `Given Service on a protocol or enum When expanded Then the error is at the attribute`(header: String) {
		expectExpansion(
			"""
			@Service
			\(header) {
			}
			""",
			expandedSource: """
			\(header) {
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Service can only be applied to a class, struct or actor", line: 1, column: 1)]
		)
	}

	@Test(arguments: ["final class Box", "struct Box", "actor Box"])
	func `Given Service on a class struct or actor When expanded Then there are no diagnostics`(header: String) {
		expectExpansion(
			"""
			@Service
			\(header) {
			}
			""",
			expandedSource: """
			\(header) {
			}
			"""
		)
	}

	@Test
	func `Given a generic Service When expanded Then the error is at the generic clause`() {
		expectExpansion(
			"""
			@Service
			final class Box<T> {
			}
			""",
			expandedSource: """
			final class Box<T> {
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Service types cannot be generic", line: 2, column: 16)]
		)
	}

	// MARK: - @Configuration

	@Test
	func `Given Configuration on a protocol When expanded Then the error is at the attribute`() {
		expectExpansion(
			"""
			@Configuration
			protocol AppConfiguration {
			}
			""",
			expandedSource: """
			protocol AppConfiguration {
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Configuration can only be applied to an enum, struct, class or actor", line: 1, column: 1)]
		)
	}

	// MARK: - @ApplicationContext

	@Test
	func `Given ApplicationContext on a struct When expanded Then the error is at the attribute and nothing is added`() {
		expectExpansion(
			"""
			@ApplicationContext
			struct AppContext {
			}
			""",
			expandedSource: """
			struct AppContext {
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@ApplicationContext can only be applied to a class", line: 1, column: 1)]
		)
	}

	// MARK: - @Inject

	@Test
	func `Given Inject on an initializer When expanded Then the attribute is removed without diagnostics`() {
		expectExpansion(
			"""
			final class ReportService {
				@Inject
				init(store: any Store) {}
			}
			""",
			expandedSource: """
			final class ReportService {
				init(store: any Store) {}
			}
			"""
		)
	}

	@Test
	func `Given Inject on a method When expanded Then the error is at the attribute`() {
		expectExpansion(
			"""
			final class ReportService {
				@Inject
				func configure() {}
			}
			""",
			expandedSource: """
			final class ReportService {
				func configure() {}
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Inject can only be applied to an initializer", line: 2, column: 2)]
		)
	}
}
