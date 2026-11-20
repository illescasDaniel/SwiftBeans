import SwiftBeansMacros
import SwiftBeansSyntaxRules
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

private let autoInitSpecs: [String: MacroSpec] = [
	"Service": MacroSpec(type: ServiceMacro.self),
	"Assisted": MacroSpec(type: AssistedMarkerMacro.self),
	"Qualifier": MacroSpec(type: QualifierMarkerMacro.self),
]

/// Expands `source` with the service and marker macros (positions are 1-based; a tab is one column).
private func expectAutoInit(
	_ source: String,
	expandedSource: String,
	diagnostics: [DiagnosticSpec] = [],
	sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
	assertMacroExpansion(
		source,
		expandedSource: expandedSource,
		diagnostics: diagnostics,
		macroSpecs: autoInitSpecs,
		indentationWidth: .tabs(1),
		failureHandler: { Issue.record("\($0.message)", sourceLocation: sourceLocation) }
	)
}

private let markerMessage =
	"@Assisted on a stored property requires '@Service(autoInit: true)' on the enclosing type; add 'autoInit: true' to the @Service, or mark the initializer parameter instead"
private let qualifierMarkerMessage =
	"@Qualifier on a stored property requires '@Service(autoInit: true)' on the enclosing type; add 'autoInit: true' to the @Service, or mark the initializer parameter instead"

@Suite("Service auto-init macro — SPEC Generated initializer")
struct AutoInitMacroTests {
	// MARK: - Expansion shapes

	// Scenario: coordinator class with private closure dependencies
	@Test
	func `Given a coordinator with private closure properties When expanded Then escaping parameters are emitted`() {
		expectAutoInit(
			"""
			@Service(scope: .transient, autoInit: true)
			@Observable
			@MainActor
			final class Coordinator {
				var path = NavigationPath()
				private let makeA: @MainActor () -> A
				private let makeB: @MainActor (Item) -> B
			}
			""",
			expandedSource: """
			@Observable
			@MainActor
			final class Coordinator {
				var path = NavigationPath()
				private let makeA: @MainActor () -> A
				private let makeB: @MainActor (Item) -> B

				init(makeA: @escaping @MainActor () -> A, makeB: @escaping @MainActor (Item) -> B) {
					self.makeA = makeA
					self.makeB = makeB
				}
			}
			"""
		)
	}

	// Scenario: dependency assisted and qualified properties become marked parameters
	@Test
	func `Given dependency, assisted and qualified properties When expanded Then they become marked parameters`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class ItemDetail {
				private let repository: Repository
				@Assisted let item: Item
				@Qualifier("snakeCase") private let decoder: JSONDecoder
			}
			""",
			expandedSource: """
			final class ItemDetail {
				private let repository: Repository
				let item: Item
				private let decoder: JSONDecoder

				init(repository: Repository, @Assisted item: Item, @Qualifier("snakeCase") decoder: JSONDecoder) {
					self.repository = repository
					self.item = item
					self.decoder = decoder
				}
			}
			"""
		)
	}

	// Scenario: optional var becomes a nil default and optional let stays required
	@Test
	func `Given optional properties When expanded Then var gets a nil default and let stays required`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Feed {
				var logger: Logger?
				var other: Optional<Other>
				let token: Token?
				var onTap: (@MainActor () -> Void)?
			}
			""",
			expandedSource: """
			final class Feed {
				var logger: Logger?
				var other: Optional<Other>
				let token: Token?
				var onTap: (@MainActor () -> Void)?

				init(logger: Logger? = nil, other: Optional<Other> = nil, token: Token?, onTap: (@MainActor () -> Void)? = nil) {
					self.logger = logger
					self.other = other
					self.token = token
					self.onTap = onTap
				}
			}
			"""
		)
	}

	// Scenario: excluded members are not parameters
	@Test
	func `Given static, lazy, computed and valued members When expanded Then they are not parameters`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Mixed {
				static let shared = Mixed()
				lazy var cache: Cache = Cache()
				var name: String { "x" }
				let id = UUID()
				var count = 0
				static var other: Int
				let dependency: Dependency
			}
			""",
			expandedSource: """
			final class Mixed {
				static let shared = Mixed()
				lazy var cache: Cache = Cache()
				var name: String { "x" }
				let id = UUID()
				var count = 0
				static var other: Int
				let dependency: Dependency

				init(dependency: Dependency) {
					self.dependency = dependency
				}
			}
			"""
		)
	}

	// Scenario: struct with private properties
	@Test
	func `Given a struct with private properties When expanded Then they become parameters`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			struct Wrapper {
				private let client: Client
			}
			""",
			expandedSource: """
			struct Wrapper {
				private let client: Client

				init(client: Client) {
					self.client = client
				}
			}
			"""
		)
	}

	// Scenario: actor
	@Test
	func `Given an actor When expanded Then the init is emitted`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			actor Cache {
				let store: Store
			}
			""",
			expandedSource: """
			actor Cache {
				let store: Store

				init(store: Store) {
					self.store = store
				}
			}
			"""
		)
	}

	// Scenario: access level follows the type
	@Test(arguments: [
		("public final class", "public init"),
		("open class", "public init"),
		("package final class", "package init"),
		("final class", "init"),
	])
	func `Given a type with an access level When expanded Then the init follows it`(declaration: String, initHead: String) {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			\(declaration) Box {
				let store: Store
			}
			""",
			expandedSource: """
			\(declaration) Box {
				let store: Store

				\(initHead)(store: Store) {
					self.store = store
				}
			}
			"""
		)
	}

	// Scenario: no included properties emits an empty initializer
	@Test
	func `Given no included properties When expanded Then an empty initializer is emitted`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Counter {
				var count = 0
				let id = UUID()
			}
			""",
			expandedSource: """
			final class Counter {
				var count = 0
				let id = UUID()

				init() {
				}
			}
			"""
		)
	}

	// Scenario: ObservationIgnored is allowed and the property is an ordinary parameter
	@Test
	func `Given an ObservationIgnored property When expanded Then it is an ordinary parameter`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			@Observable
			final class Clocked {
				@ObservationIgnored private let clock: Clock
			}
			""",
			expandedSource: """
			@Observable
			final class Clocked {
				@ObservationIgnored private let clock: Clock

				init(clock: Clock) {
					self.clock = clock
				}
			}
			"""
		)
	}

	@Test
	func `Given function types in several spellings When expanded Then escaping is added only to non-optional ones`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Closures {
				let a: @Sendable (A) -> B
				let b: () -> Void
				let c: (() -> Void)
				let d: (() -> Void)?
				let e: @MainActor @Sendable () -> Void
				let f: (A, B) -> C
				let g: [() -> Void]
				let h: (A, B)
			}
			""",
			expandedSource: """
			final class Closures {
				let a: @Sendable (A) -> B
				let b: () -> Void
				let c: (() -> Void)
				let d: (() -> Void)?
				let e: @MainActor @Sendable () -> Void
				let f: (A, B) -> C
				let g: [() -> Void]
				let h: (A, B)

				init(a: @escaping @Sendable (A) -> B, b: @escaping () -> Void, c: @escaping (() -> Void), d: (() -> Void)?, e: @escaping @MainActor @Sendable () -> Void, f: @escaping (A, B) -> C, g: [() -> Void], h: (A, B)) {
					self.a = a
					self.b = b
					self.c = c
					self.d = d
					self.e = e
					self.f = f
					self.g = g
					self.h = h
				}
			}
			"""
		)
	}

	@Test
	func `Given several bindings in one declaration When expanded Then each is a parameter in order`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Pair {
				let a: A, b: B
				let c: C
			}
			""",
			expandedSource: """
			final class Pair {
				let a: A, b: B
				let c: C

				init(a: A, b: B, c: C) {
					self.a = a
					self.b = b
					self.c = c
				}
			}
			"""
		)
	}

	@Test
	func `Given autoInit false When expanded Then nothing is emitted`() {
		expectAutoInit(
			"""
			@Service(autoInit: false)
			final class Plain {
				let a: A
			}
			""",
			expandedSource: """
			final class Plain {
				let a: A
			}
			"""
		)
	}

	// MARK: - Rejected forms

	// Scenario: F1 existing initializer conflicts
	@Test
	func `Given a hand-written init next to autoInit When expanded Then it conflicts`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Existing {
				let b: B
				init(b: B) { self.b = b }
			}
			""",
			expandedSource: """
			final class Existing {
				let b: B
				init(b: B) { self.b = b }
			}
			""",
			diagnostics: [
				DiagnosticSpec(
					message: "'autoInit: true' generates the initializer; remove this initializer or remove 'autoInit: true'",
					line: 4, column: 2)
			]
		)
	}

	// Scenario: F2 non-literal autoInit is reported once at the argument
	@Test
	func `Given a non-literal autoInit When expanded Then one error is reported at the argument`() {
		expectAutoInit(
			"""
			@Service(autoInit: flag)
			final class Dynamic {
				let b: B
			}
			""",
			expandedSource: """
			final class Dynamic {
				let b: B
			}
			""",
			diagnostics: [DiagnosticSpec(message: "autoInit must be the literal true or false", line: 1, column: 20)]
		)
	}

	// Scenario: F3 unknown property attribute
	@Test
	func `Given an unknown property attribute When expanded Then it is reported`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Wrapped {
				@Published var value: Int
			}
			""",
			expandedSource: """
			final class Wrapped {
				@Published var value: Int
			}
			""",
			diagnostics: [
				DiagnosticSpec(
					message: "'autoInit: true' cannot copy this attribute onto an initializer parameter; declare an initializer instead",
					line: 3, column: 2)
			]
		)
	}

	// Scenario: F4 unsupported pattern
	@Test
	func `Given an unsupported binding pattern When expanded Then it is reported`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Tupled {
				let (a, b): (A, B)
			}
			""",
			expandedSource: """
			final class Tupled {
				let (a, b): (A, B)
			}
			""",
			diagnostics: [
				DiagnosticSpec(
					message: "'autoInit: true' needs each stored property to be a single named binding such as 'let name: Type'",
					line: 3, column: 6)
			]
		)
	}

	// Scenario: F5 missing type annotation
	@Test
	func `Given a property without a type annotation When expanded Then it is reported`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Untyped {
				var value
			}
			""",
			expandedSource: """
			final class Untyped {
				var value
			}
			""",
			diagnostics: [
				DiagnosticSpec(
					message: "'autoInit: true' needs a type annotation on stored property 'value'",
					line: 3, column: 6)
			]
		)
	}

	// MARK: - Marker macros

	// Scenario: F6 markers outside an auto-init service
	@Test
	func `Given markers outside an auto-init service When expanded Then they are reported`() {
		expectAutoInit(
			"""
			@Service
			final class Plain {
				@Assisted let item: Item
			}

			final class Other {
				@Qualifier("x") let d: D
			}
			""",
			expandedSource: """
			final class Plain {
				let item: Item
			}

			final class Other {
				let d: D
			}
			""",
			diagnostics: [
				DiagnosticSpec(message: markerMessage, line: 3, column: 2),
				DiagnosticSpec(message: qualifierMarkerMessage, line: 7, column: 2),
			]
		)
	}

	// Scenario: F7 markers on static or computed properties
	@Test
	func `Given markers on static or computed properties When expanded Then they are reported`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Odd {
				@Assisted static let x: X
				@Assisted var y: Y { fatalError() }
			}
			""",
			expandedSource: """
			final class Odd {
				static let x: X
				var y: Y { fatalError() }

				init() {
				}
			}
			""",
			diagnostics: [
				DiagnosticSpec(message: markerMessage, line: 3, column: 2),
				DiagnosticSpec(message: markerMessage, line: 4, column: 2),
			]
		)
	}

	// Scenario: F9 invalid qualifier name on a property
	@Test
	func `Given an invalid qualifier name on a property When expanded Then it is reported`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Named {
				@Qualifier(name) private let d: D
			}
			""",
			expandedSource: """
			final class Named {
				private let d: D

				init(@Qualifier(name) d: D) {
					self.d = d
				}
			}
			""",
			diagnostics: [DiagnosticSpec(message: "@Qualifier name must be a string literal", line: 3, column: 13)]
		)
	}

	// Scenario: F10 closure typealias gets no escaping and no SwiftBeans diagnostic
	@Test
	func `Given a closure typealias property When expanded Then no escaping is added and no SwiftBeans diagnostic is raised`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Aliased {
				private let make: MakeFn
			}
			""",
			expandedSource: """
			final class Aliased {
				private let make: MakeFn

				init(make: MakeFn) {
					self.make = make
				}
			}
			"""
		)
	}

	// Scenario: F8 assisted and qualified together are both copied for the generator to reject
	@Test
	func `Given Assisted and Qualifier together on a property When expanded Then both are copied for the generator to reject`() {
		expectAutoInit(
			"""
			@Service(autoInit: true)
			final class Both {
				@Assisted @Qualifier("x") let d: D
			}
			""",
			expandedSource: """
			final class Both {
				let d: D

				init(@Assisted @Qualifier("x") d: D) {
					self.d = d
				}
			}
			"""
		)
	}
}

@Suite("Service auto-init rules — SwiftBeansSyntaxRules")
struct AutoInitRuleTests {
	private func attribute(_ source: String) throws -> AttributeSyntax {
		let tree = Parser.parse(source: source + "\nclass C {}")
		let decl = try #require(tree.statements.first?.item.as(ClassDeclSyntax.self))
		return try #require(SwiftBeansSyntaxRules.find(.service, in: decl.attributes))
	}

	private func markerViolations(_ source: String) throws -> [Violation] {
		let tree = Parser.parse(source: source)
		let variable = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
		let marker = try #require(variable.attributes.compactMap { $0.as(AttributeSyntax.self) }.first {
			["Assisted", "Qualifier"].contains($0.attributeName.trimmedDescription)
		})
		return SwiftBeansSyntaxRules.propertyMarkerViolations(variable, attribute: marker, enclosing: nil)
	}

	// Scenario: Observable backing storage re-expands the marker without a lexical context
	@Test
	func `Given Observable backing storage with a marker and no enclosing type When validated Then nothing is reported`() throws {
		#expect(try markerViolations("@ObservationIgnored @Assisted private var _item: Item").isEmpty)
	}

	// Scenario: the Observable exemption is only for underscore-named backing storage
	@Test
	func `Given a top-level ObservationIgnored marker without an underscore name When validated Then assisted property is reported`() throws {
		let violations = try markerViolations("@ObservationIgnored @Assisted var x: X")
		#expect(violations.map(\.id) == ["assisted.property"])
	}

	@Test(arguments: [
		("@Service", false),
		("@Service(autoInit: false)", false),
		("@Service(autoInit: true)", true),
		("@Service(scope: .transient, autoInit: true)", true),
	])
	func `Given a literal autoInit argument When read Then its value is returned`(source: String, expected: Bool) throws {
		#expect(try SwiftBeansSyntaxRules.autoInit(of: attribute(source)).get() == expected)
	}

	@Test
	func `Given a non-literal autoInit argument When read Then service autoInit is reported at the expression`() throws {
		let attribute = try attribute("@Service(autoInit: flag)")
		guard case .failure(let violation) = SwiftBeansSyntaxRules.autoInit(of: attribute) else {
			Issue.record("expected a violation")
			return
		}
		#expect(violation.id == "service.autoInit")
		#expect(violation.node.trimmedDescription == "flag")
	}

	@Test
	func `Given a non-literal autoInit on a service When service rules run Then service autoInit is included`() throws {
		let tree = Parser.parse(source: "@Service(autoInit: flag)\nfinal class C {}")
		let decl = try #require(tree.statements.first?.item.as(ClassDeclSyntax.self))
		let attribute = try #require(SwiftBeansSyntaxRules.find(.service, in: decl.attributes))
		#expect(SwiftBeansSyntaxRules.serviceViolations(decl, attribute: attribute).map(\.id) == ["service.autoInit"])
	}
}
