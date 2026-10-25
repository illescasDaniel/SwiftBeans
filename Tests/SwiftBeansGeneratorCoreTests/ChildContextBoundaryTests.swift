import Testing

@testable import SwiftBeansGeneratorCore

@Suite("Child contexts — graph boundary scenarios")
struct ChildContextBoundaryTests {
	@Test(arguments: [
		ChildInvalidCase(
			source: "@ChildContext(of: AppContext.self) final class Bad<T> {}",
			diagnostic: "context.generic"),
		ChildInvalidCase(
			source: "@ChildContext(of: AppContext.self) actor Bad {}", diagnostic: "context.notClass"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class Bad { @ContextInput static let value: Int }",
			diagnostic: "context.invalidInput"),
		ChildInvalidCase(
			source: "@ChildContext(of: AppContext.self) final class Bad { @ContextInput let value = 1 }",
			diagnostic: "context.invalidInput"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class Bad { @ContextInput let value: Int = 1 }",
			diagnostic: "context.invalidInput"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class Bad { @ContextInput let a: Int, b: String }",
			diagnostic: "context.invalidInput"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class Bad { @ContextInput let (a, b): (Int, Int) }",
			diagnostic: "context.invalidInput"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class Bad { @ContextInput let value: () -> Int }",
			diagnostic: "context.invalidInput"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class Bad { @ContextInput let value: Int { 1 } }",
			diagnostic: "context.invalidInput"),
		ChildInvalidCase(
			source: "@ChildContext(of: AppContext.self) final class Bad { let _swiftBeansRegistry = 0 }",
			diagnostic: "context.reservedName"),
		ChildInvalidCase(
			source:
				"@MainActor @ChildContext(of: AppContext.self, teardown: .managed) final class Bad { func close() {} }",
			diagnostic: "context.reservedName"),
		ChildInvalidCase(
			source: "@Configuration(in: Missing.self) enum Empty {}", diagnostic: "context.invalidOwner"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A {} @ChildContext(of: A.self) final class B {}",
			diagnostic: "context.invalidParent"),
		ChildInvalidCase(
			source: "@ChildContext(of: B.self) final class A {} @ChildContext(of: A.self) final class B {}",
			diagnostic: "context.invalidParent"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A {} @ChildContext(of: AppContext.self) final class B {} @Service(in: A.self) final class Value {} @Service(in: B.self) final class Consumer { init(value: Value) {} }",
			diagnostic: "graph.contextVisibility"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A {} @Service(in: A.self) final class One { init(two: Two) {} } @Service(in: A.self) final class Two { init(one: One) {} }",
			diagnostic: "graph.cycle"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A {} @Service(in: A.self) final class One { init(missing: Missing) {} }",
			diagnostic: "graph.missingDependency"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A {} @Service(in: A.self) final class Detail { init(@Assisted id: Int) {} } @Service(in: A.self) final class Consumer { init(detail: Detail) {} }",
			diagnostic: "assisted.notInjectable"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A {} @Service(in: A.self) final class Detail { init(@Assisted id: Int) {} } @Service(in: A.self) final class Consumer { init(make: () -> Detail) {} }",
			diagnostic: "factory.unresolved"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A {} @Service(in: A.self) final class Consumer { init(make: () -> Missing) {} }",
			diagnostic: "graph.missingDependency"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A {} @Service(in: A.self) final class Consumer { init(make: () -> Int?) {} }",
			diagnostic: "factory.unsupported"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A { @ContextInput let name: User } @Service(in: A.self) final class Name {}",
			diagnostic: "graph.accessorCollision"),
		ChildInvalidCase(
			source: "@ChildContext(of: AppContext.self) final class A {} struct AProtocol {}",
			diagnostic: "context.protocolCollision"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A { @ContextInput let user: User } @Service(in: A.self) final class User {}",
			diagnostic: "graph.duplicateProvider"),
		ChildInvalidCase(
			source:
				"@ChildContext(of: AppContext.self) final class A { @ContextInput let user: User } @Service final class User {}",
			diagnostic: "graph.duplicateProvider"),
		ChildInvalidCase(
			source: "@ChildContext(of: AppContext.self, teardown: .unknown) final class A {}",
			diagnostic: "context.teardownNotLiteral"),
	])
	func `Given invalid context declarations or edges When analyzed Then the documented failure is located`(
		_ item: ChildInvalidCase
	) {
		let result = generateWithContext(appFile("/App/Invalid.swift", item.source))
		#expect(result.errors.contains { $0.id == item.diagnostic }, "\(result.renderedDiagnostics)")
		#expect(result.output == nil)
	}

	@Test func `Given a child without root When generated Then root absence fails without publishing artifacts`() {
		let result = SwiftBeansGeneration.generate(sources: [
			appFile("/App/Child.swift", "@ChildContext(of: AppContext.self) final class Child {}")
		])
		#expect(result.errors.contains { $0.id == "context.missingRoot" })
		#expect(result.output == nil && result.graphMarkdown == nil && result.graphDot == nil)
	}

	@Test func `Given a local package child owner When generated Then package registration fails`() {
		let result = SwiftBeansGeneration.generate(sources: [
			appContextFile, GeneratorChildContextTests.child,
			packageFile(
				"Feature", "/Package/Service.swift",
				"@Service(in: SessionContext.self) public final class S { public init() {} }"),
		])
		#expect(result.errors.contains { $0.id == "context.packageOwner" })
		#expect(result.output == nil)
	}

	@Test
	func
		`Given parent and child members When collections and factories resolve Then only visible owners supply parameters`()
	{
		let result = generateWithContext(
			appFile(
				"/App/Graph.swift",
				"""
				@ChildContext(of: AppContext.self) final class Session {}
				protocol Note {}
				@Service(named: "app") final class AppNote: Note {}
				@Service(in: Session.self, named: "session") final class SessionNote: Note {}
				@Service final class AppConsumer { init(notes: [any Note]) {} }
				@Service(in: Session.self) final class ChildConsumer { init(notes: [any Note], @Qualifier("app") note: AppNote, parent: () -> AppConsumer) {} }
				"""))
		expectOutput(
			result,
			contains: [
				"notes: [self.appAppNote]",
				"notes: [self._swiftBeansParent.appAppNote, self.sessionSessionNote]",
				"note: self._swiftBeansParent.appAppNote", "return self._swiftBeansParent.appConsumer",
			])
		#expect(result.graphMarkdown?.contains("AppNote") == true)
	}

	@Test func `Given a visible array provider When collection injection runs Then it overrides element assembly`()
	{
		let result = generateWithContext(
			appFile(
				"/App/Graph.swift",
				"""
				@ChildContext(of: AppContext.self) final class Session {}
				protocol Note {}
				@Configuration enum Config { @Bean static func notes() -> [Note] { [] } }
				@Service(in: Session.self) final class Child { init(notes: [Note]) {} }
				"""))
		expectOutput(result, contains: ["Child(notes: self._swiftBeansParent.noteArray)"])
	}

	@Test
	func `Given inputs and providers in separate files When generated Then declared input labels stay ordered`() {
		let result = generateWithContext(
			appFile(
				"/App/Input.swift",
				"""
				@ChildContext(of: AppContext.self) final class Session {
					@ContextInput let currentUser: User
					@ContextInput let token: Token
				}
				"""),
			appFile(
				"/App/Service.swift",
				"@Service(in: Session.self) final class Model { init(user: User, token: Token) {} }"))
		expectOutput(
			result,
			contains: ["var currentUser: User { get }", "Model(user: self.currentUser, token: self.token)"])
	}
	@Test
	func
		`Given an initializer in a child extension When analyzed Then macro-owned construction cannot be bypassed`()
	{
		let result = generateWithContext(
			appFile("/App/Child.swift", "@ChildContext(of: AppContext.self) final class Child {}"),
			appFile(
				"/App/Extension.swift",
				"extension Child { convenience init(value: Int) { self.init(parent: AppContext()) } }"))
		#expect(result.errors.contains { $0.id == "context.customInitializer" })
		#expect(result.output == nil)
	}

	@Test func `Given a nearer ordinary type shadows a context name When assigning ownership Then it is rejected`()
	{
		let result = generateWithContext(
			appFile(
				"/App/Shadow.swift",
				"""
				enum Feature {
					final class AppContext {}
					@Service(in: AppContext.self) final class Model {}
				}
				"""))
		#expect(result.errors.contains { $0.id == "context.invalidOwner" })
		#expect(result.output == nil)
	}

	@Test func `Given graph failures When diagnosed Then owning contexts are part of the diagnostic contract`() {
		let fixtures: [(String, String)] = [
			(
				"@Service(in: ScopedContext.self) final class A { init(b: B) {} } @Service(in: ScopedContext.self) final class B { init(a: A) {} }",
				"graph.cycle"
			),
			(
				"@Service final class Shared {} @Service(in: ScopedContext.self, boundTo: Shared.self) final class Other {}",
				"graph.duplicateProvider"
			),
			(
				"@Service(in: ScopedContext.self) final class A { init(make: () -> Int?) {} }",
				"factory.unsupported"
			),
			(
				"@Service(in: ScopedContext.self) final class A { init(value: (Int, Int)) {} }",
				"key.unsupported"
			),
			(
				"@Service(in: ScopedContext.self) final class A { init(value: Missing) {} }",
				"graph.missingDependency"
			),
		]
		for (source, id) in fixtures {
			let result = generateWithContext(
				appFile(
					"/App/Graph.swift",
					"@ChildContext(of: AppContext.self) final class ScopedContext {}\n" + source))
			let matching = result.errors.filter { $0.id == id }
			#expect(!matching.isEmpty, "\(result.renderedDiagnostics)")
			#expect(
				matching.allSatisfy { $0.message.contains("ScopedContext") },
				"\(result.renderedDiagnostics)")
			if id == "graph.duplicateProvider" || id == "graph.missingDependency" {
				#expect(matching.allSatisfy { $0.message.contains("AppContext") })
			}
		}
	}

}
