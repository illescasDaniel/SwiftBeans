import Testing

@testable import SwiftBeansGeneratorCore

@Suite("Child contexts — ownership and generated contracts")
struct GeneratorChildContextTests {
	static let child = appFile(
		"/App/Session.swift",
		"""
		@ChildContext(of: AppContext.self)
		final class SessionContext { @ContextInput let currentUser: User }
		""")

	@Test func `Given child inputs and parent dependencies When generated Then each accessor belongs to its owner`()
	{
		let result = SwiftBeansGeneration.generate(sources: [
			appContextFile, Self.child,
			appFile(
				"/App/Beans.swift",
				"""
				struct User {}
				@Service final class Transport {}
				@Service(in: SessionContext.self) final class UserRepository {
					init(transport: Transport, user: User) {}
				}
				"""),
		])
		expectOutput(
			result,
			contains: [
				"protocol SessionContextProtocol", "var currentUser: User { get }",
				"self._swiftBeansParent.transport", "user: self.currentUser",
			])
		let root =
			result.output?.components(separatedBy: "protocol AppContextProtocol: AnyObject {").last?
			.components(separatedBy: "}").first ?? ""
		#expect(root.contains("transport"))
		#expect(!root.contains("userRepository"))
		#expect(result.output?.contains("func close()") == false)
	}

	@Test
	func `Given managed child factories When generated Then accessors and factories enforce lifecycle isolation`() {
		let result = generateWithContext(
			appFile(
				"/App/Session.swift",
				"""
				@MainActor @ChildContext(of: AppContext.self, teardown: .managed)
				final class SessionContext {}
				@Service final class Transport {}
				@MainActor @Service(in: SessionContext.self, scope: .transient)
				final class Screen { init(transport: Transport) {} }
				@MainActor @Service(in: SessionContext.self, scope: .transient)
				final class Coordinator { init(make: @escaping @MainActor () -> Screen) {} }
				"""))
		expectOutput(
			result,
			contains: [
				"@MainActor\nprotocol SessionContextProtocol", "func close() async", "requireOpen()",
				"{ @MainActor in", "self.screen",
			])
	}

	@Test func `Given configuration defaults When a bean overrides Then ownership uses the explicit bean context`()
	{
		let result = SwiftBeansGeneration.generate(sources: [
			appContextFile, Self.child,
			appFile(
				"/App/Config.swift",
				"""
				@Configuration(in: SessionContext.self) enum Config {
					@Bean static func name(user: User) -> String { "name" }
					@Bean(in: AppContext.self) static func count() -> Int { 1 }
				}
				"""),
		])
		expectOutput(result, contains: ["user: self.currentUser", "var int: Int", "var string: String"])
		#expect(result.errors.isEmpty)
	}

	@Test func `Given sibling equal keys When dumped Then owner-qualified node identities stay distinct`() throws {
		let result = generateWithContext(
			appFile(
				"/App/Children.swift",
				"""
				@Service final class Shared {}
				struct User {}
				@ChildContext(of: AppContext.self) final class First { @ContextInput let user: User }
				@ChildContext(of: AppContext.self) final class Second {}
				@Configuration(in: First.self) enum A { @Bean static func value(shared: Shared, user: User) -> Int { 1 } }
				@Configuration(in: Second.self) enum B { @Bean static func value(shared: Shared) -> Int { 2 } }
				"""))
		try #require(result.errors.isEmpty, "\(result.renderedDiagnostics)")
		let markdown = try #require(result.graphMarkdown)
		let dot = try #require(result.graphDot)
		let firstID = #""[\"First\",\"Int\"]""#
		let secondID = #""[\"Second\",\"Int\"]""#
		let inputID = #""[\"First\",\"User\"]""#
		let parentID = #""[\"AppContext\",\"Shared\"]""#
		let nodeLines = dot.split(separator: "\n").filter { $0.contains(" [label=") }
		#expect(nodeLines.count == 4)
		#expect(nodeLines.filter { $0.contains(firstID + " [label=") }.count == 1)
		#expect(nodeLines.filter { $0.contains(secondID + " [label=") }.count == 1)
		#expect(dot.contains("\(firstID) -> \(parentID);"))
		#expect(dot.contains("\(secondID) -> \(parentID);"))
		#expect(dot.contains("\(firstID) -> \(inputID);"))
		#expect(!dot.contains("\(secondID) -> \(inputID);"))
		#expect(markdown.contains("| `First` | `Int` |"))
		#expect(markdown.contains("| `Second` | `Int` |"))
		#expect(markdown.contains("| `First` | `User` | `user` | input | `First.user` |"))
		#expect(markdown.contains(#"- `["First","Int"]` → `["AppContext","Shared"]`, `["First","User"]`"#))
		#expect(markdown.contains(#"- `["Second","Int"]` → `["AppContext","Shared"]`"#))
	}

	@Test func `Given reordered sources When generated Then all outputs stay deterministic`() {
		let files = [
			appContextFile, Self.child,
			appFile(
				"/App/Provider.swift",
				"@Service(in: SessionContext.self) final class S { init(user: User) {} }"),
		]
		let a = SwiftBeansGeneration.generate(sources: files)
		let b = SwiftBeansGeneration.generate(sources: files.reversed())
		#expect(a.errors.isEmpty)
		#expect(a == b)
	}
}

struct ChildInvalidCase: Sendable {
	let source: String
	let diagnostic: String
}

@Suite("Child contexts — invalid declarations and graphs")
struct GeneratorChildContextDiagnosticsTests {
	static let cases: [ChildInvalidCase] = [
		.init(source: "@ChildContext(of: AppContext.self) class Bad {}", diagnostic: "context.notFinal"),
		.init(source: "@ChildContext(of: AppContext.self) struct Bad {}", diagnostic: "context.notClass"),
		.init(
			source: "@ChildContext(of: Unknown.self) final class Bad {}",
			diagnostic: "context.invalidParent"),
		.init(
			source: "@ChildContext(of: AppContext.self, teardown: .managed) final class Bad {}",
			diagnostic: "context.managedIsolation"),
		.init(
			source: "@ChildContext(of: AppContext.self) final class Bad { @ContextInput var user: User }",
			diagnostic: "context.invalidInput"),
		.init(
			source: "@ChildContext(of: AppContext.self) final class Bad { @ContextInput let user: User? }",
			diagnostic: "context.invalidInput"),
		.init(
			source: "@ChildContext(of: AppContext.self) final class Bad { @ContextInput let parent: User }",
			diagnostic: "context.reservedName"),
		.init(
			source: "@ChildContext(of: AppContext.self) final class Bad { init() {} }",
			diagnostic: "context.customInitializer"),
		.init(source: "@ContextInput let user: User", diagnostic: "context.inputOutsideChild"),
		.init(source: "@Service(in: Unknown.self) final class S {}", diagnostic: "context.invalidOwner"),
		.init(source: "@Service(in: context) final class S {}", diagnostic: "context.ownerNotLiteral"),
		.init(
			source: "@ChildContext(of: AppContext.self, teardown: policy) final class Bad {}",
			diagnostic: "context.teardownNotLiteral"),
		.init(
			source:
				"@ChildContext(of: AppContext.self) final class Bad { @ContextInput let a: User; @ContextInput let b: User }",
			diagnostic: "graph.duplicateProvider"),
		.init(
			source:
				"@ChildContext(of: AppContext.self) final class Bad {} @Service(in: Bad.self) final class User {} @Service final class Root { init(user: User) {} }",
			diagnostic: "graph.contextVisibility"),
		.init(
			source:
				"@ChildContext(of: AppContext.self) final class Bad {} @Service final class Shared {} @Service(in: Bad.self, boundTo: Shared.self) final class Other {}",
			diagnostic: "graph.duplicateProvider"),
	]

	@Test(arguments: cases)
	func `Given an invalid child feature When generated Then positioned errors prevent all output`(
		_ item: ChildInvalidCase
	) {
		let result = generateWithContext(appFile("/App/Invalid.swift", item.source))
		#expect(result.errors.contains { $0.id == item.diagnostic }, "\(result.renderedDiagnostics)")
		#expect(result.output == nil)
		#expect(result.graphDot == nil)
		#expect(result.errors.allSatisfy { $0.location.line > 0 && $0.location.column > 0 })
	}
}
