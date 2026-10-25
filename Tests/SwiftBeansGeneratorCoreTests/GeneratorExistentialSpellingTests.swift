import Testing

@testable import SwiftBeansGeneratorCore

@Suite("Generator — nested existential spelling")
struct GeneratorExistentialSpellingTests {
	private func generate(_ declarations: String) -> GenerationResult {
		generateWithContext(appFile("/App/Types.swift", declarations))
	}

	private func expectDeclarations(_ result: GenerationResult, type: String, count: Int = 2) throws {
		#expect(result.errors.isEmpty, "\(result.renderedDiagnostics)")
		let output = try #require(result.output)
		#expect(occurrences(of: ": \(type) {", in: output) == count, "\(output)")
	}

	@Test(arguments: [
		("[any P]", "[any P]"), ("Array<(any P)>", "[any P]"),
		("([any P])", "[any P]"), ("[String: any P]", "[String: any P]"),
		("Dictionary<String, any P>", "[String: any P]"), ("[any P: Value]", "[any P: Value]"),
		("Module.Outer<any P>.Inner<any Q>", "Module.Outer<any P>.Inner<any Q>"),
		("Box<[String: [any P]]>", "Box<[String: [any P]]>"),
		("(any P).Alias", "P.Alias"),
		("(any Box<any P>).Alias", "Box<any P>.Alias"),
		("[String]", "[String]"), ("[String: Int]", "[String: Int]"), ("Box<Value>", "Box<Value>"),
	])
	func `Given supported source types When generated Then both declarations preserve canonical spelling`(
		spelling: String, expected: String
	) throws {
		try expectDeclarations(generate("""
			@Configuration enum Config { @Bean static func value() -> \(spelling) { fatalError() } }
			"""), type: expected)
	}

	@Test(arguments: [false, true])
	func `Given consumer evidence When generated Then positions merge for the same complete type`(defaulted: Bool) throws {
		let result = generate("""
			@Configuration enum Config { @Bean static func value() -> Pair<any P, Q> { fatalError() } }
			@Service final class Consumer { init(value: Pair<P, any Q>\(defaulted ? " = fatalError()" : "")) {} }
			""")
		try expectDeclarations(result, type: "Pair<any P, any Q>")
	}

	@Test func `Given nested evidence When generated Then other complete types receive no markers`() throws {
		let result = generate("""
			@Configuration enum Config {
				@Bean static func first() -> Box<any P> { fatalError() }
				@Bean static func second() -> OtherBox<P> { fatalError() }
				@Bean static func third() -> [P] { [] }
				@Bean static func fourth() -> P { fatalError() }
			}
			""")
		for type in ["Box<any P>", "OtherBox<P>", "[P]", "P"] {
			try expectDeclarations(result, type: type)
		}
	}

	@Test func `Given qualified variants When generated Then markers merge without changing bindings`() throws {
		let result = generate("""
			@Configuration enum Config {
				@Bean static func first() -> [P] { [] }
				@Bean(named: "special") static func second() -> [any P] { [] }
			}
			@Service final class Consumer { init(@Qualifier("special") values: [P]) {} }
			""")
		try expectDeclarations(result, type: "[any P]", count: 4)
		expectOutput(result, contains: ["Consumer(values: self.specialPArray)", "key: \"pArray\"", "key: \"specialPArray\""])
	}

	@Test func `Given assisted arguments When generated Then they retain spelling without supplying evidence`() throws {
		let result = generate("""
			@Configuration enum Config {
				@Bean static func first() -> Box<P> { fatalError() }
				@Bean static func second(@Assisted value: Box<any P>) -> [any P] { [] }
			}
			""")
		try expectDeclarations(result, type: "Box<P>")
		let output = try #require(result.output)
		#expect(occurrences(of: "func pArray(value: Box<any P>) -> [any P]", in: output) == 2)
	}

	@Test func `Given factory return evidence When generated Then deferred and assisted targets retain markers`() throws {
		let result = generate("""
			@Configuration enum Config {
				@Bean static func first() -> [P] { [] }
				@Bean static func second(@Assisted item: Item) -> Box<P> { fatalError() }
			}
			@Service final class Consumer { init(first: () -> [any P], second: (Item) -> Box<any P>) {} }
			""")
		try expectDeclarations(result, type: "[any P]")
		let output = try #require(result.output)
		#expect(occurrences(of: "func pBox(item: Item) -> Box<any P>", in: output) == 2)
		expectOutput(result, contains: ["{ self.pArray }", "self.pBox(item: $0)"])
	}

	@Test func `Given child evidence When generated Then a parent declaration is corrected exactly once`() throws {
		let result = generate("""
			@ChildContext(of: AppContext.self) final class Session {}
			@Configuration enum Config { @Bean static func value() -> [P] { [] } }
			@Service(in: Session.self) final class Consumer { init(values: [any P]) {} }
			""")
		try expectDeclarations(result, type: "[any P]")
		expectOutput(result, contains: ["Consumer(values: self._swiftBeansParent.pArray)"])
	}

	@Test func `Given sibling evidence When generated Then invisible providers stay unmarked`() throws {
		let result = generate("""
			@ChildContext(of: AppContext.self) final class First {}
			@ChildContext(of: AppContext.self) final class Second {}
			@Configuration(in: First.self) enum A { @Bean static func value() -> Box<P> { fatalError() } }
			@Configuration(in: Second.self) enum B { @Bean static func value() -> Box<any P> { fatalError() } }
			""")
		try expectDeclarations(result, type: "Box<P>")
		try expectDeclarations(result, type: "Box<any P>")
		try expectDeclarations(generate("@Configuration enum C { @Bean static func value() -> Box<P> { fatalError() } }"), type: "Box<P>")
	}

	@Test func `Given context inputs When generated Then source spelling survives and supplies evidence`() throws {
		let result = generate("""
			@ChildContext(of: AppContext.self) final class Session { @ContextInput let values: Array<any P> }
			@Configuration enum Config { @Bean(named: "other") static func value() -> [P] { [] } }
			@Service(in: Session.self) final class Consumer { init(values: [P]) {} }
			""")
		try expectDeclarations(result, type: "[any P]")
		expectOutput(result, contains: ["var values: Array<any P> { get }", "Consumer(values: self.values)"])
	}

	@Test func `Given reordered sources When generated Then spelling and dumps are deterministic`() throws {
		let a = appFile("/App/A.swift", "@Configuration enum Config { @Bean static func value() -> Pair<any P, Q> { fatalError() } }")
		let b = appFile("/App/B.swift", "@Service final class Consumer { init(value: Pair<P, any Q>) {} }")
		let first = SwiftBeansGeneration.generate(sources: [appContextFile, a, b])
		let second = SwiftBeansGeneration.generate(sources: [b, a, appContextFile])
		try expectDeclarations(first, type: "Pair<any P, any Q>")
		#expect(first.output == second.output)
		#expect(first.graphMarkdown == second.graphMarkdown)
		#expect(first.graphDot == second.graphDot)
	}

	@Test func `Given only spelling changes When generated Then dumps and wiring remain stable`() throws {
		func fixture(_ type: String) -> GenerationResult {
			generate("@Configuration enum Config { @Bean static func value() -> \(type) { fatalError() } }")
		}
		let plain = fixture("Box<P>")
		let marked = fixture("Box<any P>")
		let plainOutput = try #require(plain.output)
		let markedOutput = try #require(marked.output)
		#expect(plain.graphMarkdown == marked.graphMarkdown)
		#expect(plain.graphDot == marked.graphDot)
		#expect(plainOutput == markedOutput.replacingOccurrences(of: "Box<any P>", with: "Box<P>"))
		try expectDeclarations(marked, type: "Box<any P>")
	}

	@Test(arguments: ["[any P]?", "some P", "any P & Q"])
	func `Given unsupported provider types When normalized Then existing diagnostics remain`(type: String) {
		let result = generate("@Configuration enum Config { @Bean static func value() -> \(type) { fatalError() } }")
		#expect(result.output == nil)
		#expect(result.errorSummary == ["key.unsupported /App/Types.swift:1:59"])
	}

	@Test func `Given equivalent existential keys When validated Then duplicate diagnostics retain locations`() {
		let result = generate("""
			@Configuration enum Config {
				@Bean static func first() -> [P] { [] }
				@Bean static func second() -> Array<any P> { [] }
			}
			""")
		#expect(result.output == nil)
		#expect(result.errorSummary == ["graph.duplicateProvider /App/Types.swift:2:2", "graph.duplicateProvider /App/Types.swift:3:2"])
	}

	@Test func `Given unsupported defaults When generated Then they do not supply spelling evidence`() throws {
		let result = generate("""
			@Configuration enum Config { @Bean static func value() -> Box<P> { fatalError() } }
			@Service final class Consumer { init(value: (Box<any P>, Int) = fatalError()) {} }
			""")
		try expectDeclarations(result, type: "Box<P>")
		expectOutput(result, contains: ["Consumer()"])
	}

	@Test(arguments: [false, true])
	func `Given invalid dependencies When generated Then spelling cannot bypass validation`(assisted: Bool) {
		let source = assisted ? """
			@Configuration enum Config { @Bean static func value(@Assisted item: Item) -> Box<any P> { fatalError() } }
			@Service final class Consumer { init(value: Box<any P>) {} }
			""" : """
			@Service final class Consumer { init(value: Box<any P>) {} }
			"""
		let result = generate(source)
		#expect(result.output == nil)
		#expect(result.errorSummary == [assisted
			? "assisted.notInjectable /App/Types.swift:2:38"
			: "graph.missingDependency /App/Types.swift:1:38"])
	}

	@Test(arguments: ["() -> (any P)?", "() -> some P", "() -> any P & Q"])
	func `Given unsupported factory returns When generated Then existing diagnostics remain`(type: String) {
		let result = generate("@Service final class Consumer { init(value: \(type)) {} }")
		#expect(result.output == nil)
		#expect(result.errorSummary == ["factory.unsupported /App/Types.swift:1:45"])
	}

	@Test func `Given equivalent declaration orders When generated Then merged output stays identical`() throws {
		let first = "@Bean static func first() -> Pair<any P, Q> { fatalError() }"
		let second = "@Bean(named: \"other\") static func second() -> Pair<P, any Q> { fatalError() }"
		let a = generate("@Configuration enum Config { \(first) \(second) }")
		let b = generate("@Configuration enum Config { \(second) \(first) }")
		try expectDeclarations(a, type: "Pair<any P, any Q>", count: 4)
		#expect(a.output == b.output)
	}
}
