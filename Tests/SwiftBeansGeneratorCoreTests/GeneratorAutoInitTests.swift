import SwiftBeansSyntaxRules
import SwiftParser
import SwiftSyntax
import Testing
@testable import SwiftBeansGeneratorCore

private let repositoryFile = appFile("/App/Repository.swift", """
	@Service
	final class ItemRepository {
		init() {}
	}
	""")

private let decodersFile = appFile("/App/Coding.swift", """
	@Configuration
	enum Coding {
		@Bean(named: "snakeCase")
		static func snakeCaseDecoder() -> JSONDecoder { JSONDecoder() }
	}
	""")

private let detailFile = appFile("/App/Detail.swift", """
	@Service(autoInit: true)
	final class ItemDetailViewModel {
		private let repository: ItemRepository
		@Assisted let item: Item
		@Qualifier("snakeCase") private let decoder: JSONDecoder
	}
	""")

@Suite("Generator — service auto-init SPEC")
struct GeneratorAutoInitTests {
	// MARK: - Resolution

	// Scenario: coordinator class with private closure dependencies resolves factories
	@Test
	func `Given a coordinator with private closure properties When generated Then factories are resolved`() {
		let result = generateWithContext(repositoryFile, detailFile, decodersFile, appFile("/App/Coordinator.swift", """
			@Service(scope: .transient, autoInit: true)
			@MainActor
			final class Coordinator {
				var path = NavigationPath()
				private let makeRepository: () -> ItemRepository
				private let makeDetail: @MainActor (Item) -> ItemDetailViewModel
			}
			"""))
		expectOutput(result, contains: [
			"Coordinator(makeRepository: { self.itemRepository }, makeDetail: { self.itemDetailViewModel(item: $0) })",
		])
	}

	// Scenario: dependency assisted and qualified properties produce an assisted accessor
	@Test
	func `Given dependency, assisted and qualified properties When generated Then an assisted accessor is produced`() throws {
		let result = generateWithContext(repositoryFile, detailFile, decodersFile, appFile("/App/Screen.swift", """
			@Service
			final class Screen {
				init(makeDetail: (Item) -> ItemDetailViewModel) {}
			}
			"""))
		expectOutput(result, contains: [
			"\tfunc itemDetailViewModel(item: Item) -> ItemDetailViewModel\n",
			"\tfunc itemDetailViewModel(item: Item) -> ItemDetailViewModel {\n\t\tItemDetailViewModel(repository: self.itemRepository, item: item, decoder: self.snakeCaseJSONDecoder)\n\t}",
			"Screen(makeDetail: { self.itemDetailViewModel(item: $0) })",
		])
		expectOutput(result, excludes: ["var itemDetailViewModel"])
	}

	// Scenario: optional var becomes an optional dependency
	@Test
	func `Given an optional var without a value When generated Then it is an optional dependency`() {
		let source = """
			@Service(autoInit: true)
			final class Consumer {
				var logger: Logger?
			}
			"""
		expectOutput(generateWithContext(appFile("/App/Consumer.swift", source)), contains: ["Consumer()"])
		let withProvider = generateWithContext(appFile("/App/Consumer.swift", source), appFile("/App/Logger.swift", """
			@Service
			final class Logger {
				init() {}
			}
			"""))
		expectOutput(withProvider, contains: ["Consumer(logger: self.logger)"])
	}

	// Scenario: optional let stays required and is rejected like a hand-written optional parameter
	@Test
	func `Given an optional let without a value When generated Then it is rejected like a hand-written optional parameter`() {
		let result = generateWithContext(appFile("/App/Auth.swift", """
			@Service(autoInit: true)
			final class Auth {
				let token: Token?
			}
			"""))
		// SPEC says "the existing missing-dependency error"; for an optional without a default the existing
		// generator rule is `key.unsupported` at the type (same as `init(token: Token?)`).
		#expect(result.errorSummary == ["key.unsupported /App/Auth.swift:3:13"], "\(result.renderedDiagnostics)")
	}

	// Scenario: struct with private properties is injected through the generated init
	@Test
	func `Given a struct with private properties When generated Then it is injected through the generated init`() {
		let result = generateWithContext(repositoryFile, appFile("/App/Wrapper.swift", """
			@Service(autoInit: true)
			struct Wrapper {
				private let repository: ItemRepository
			}
			"""))
		expectOutput(result, contains: ["Wrapper(repository: self.itemRepository)"])
	}

	// Scenario: actor is constructed through its init
	@Test
	func `Given an actor service When generated Then it is constructed through its init`() {
		let result = generateWithContext(repositoryFile, appFile("/App/Cache.swift", """
			@Service(autoInit: true)
			actor Cache {
				let repository: ItemRepository
			}
			"""))
		expectOutput(result, contains: ["Cache(repository: self.itemRepository)"])
	}

	// Scenario: ObservationIgnored property is an ordinary parameter
	@Test
	func `Given an ObservationIgnored property When generated Then it is an ordinary parameter`() {
		let result = generateWithContext(repositoryFile, appFile("/App/Clocked.swift", """
			@Service(autoInit: true)
			@Observable
			final class Clocked {
				@ObservationIgnored private let repository: ItemRepository
			}
			"""))
		expectOutput(result, contains: ["Clocked(repository: self.itemRepository)"])
	}

	// Scenario: access level lets a public auto-init service in a local package pass
	@Test
	func `Given a public auto-init service in a local package When generated Then the access level lets it pass`() {
		let path = "/Packages/Net/Sources/Networking/Client.swift"
		let publicType = generateWithContext(packageFile("Networking", path, """
			@Service(autoInit: true)
			public final class APIClient {}
			"""))
		#expect(publicType.errors.isEmpty, "\(publicType.renderedDiagnostics)")

		let internalType = generateWithContext(packageFile("Networking", path, """
			@Service(autoInit: true)
			final class APIClient {}
			"""))
		#expect(internalType.errorSummary == ["package.notPublic \(path):1:1"], "\(internalType.renderedDiagnostics)")
	}

	// Scenario: Inject across extension and generated inits selects the extension initializer
	@Test
	func `Given Inject on an extension init next to the generated init When generated Then the extension initializer is selected`() {
		let result = generateWithContext(repositoryFile, appFile("/App/Screen.swift", """
			@Service(autoInit: true)
			final class Screen {
				let repository: ItemRepository
			}

			extension Screen {
				@Inject
				convenience init() { self.init(repository: ItemRepository()) }
			}
			"""))
		expectOutput(result, contains: ["Screen()"])
		expectOutput(result, excludes: ["Screen(repository"])
	}

	// Scenario: Inject missing across extension and generated inits reports both candidates
	@Test
	func `Given no Inject across an extension init and the generated init When generated Then both candidates are reported`() {
		let result = generateWithContext(repositoryFile, appFile("/App/Screen.swift", """
			@Service(autoInit: true)
			final class Screen {
				let repository: ItemRepository
			}

			extension Screen {
				convenience init(other: Int) { self.init(repository: ItemRepository()) }
			}
			"""))
		#expect(result.errorSummary == ["init.ambiguous /App/Screen.swift:1:1"], "\(result.renderedDiagnostics)")
		let notes = result.diagnostics.first(where: { $0.id == "init.ambiguous" })?.notes.map { "\($0.location)" }
		#expect(notes == ["/App/Screen.swift:1:10", "/App/Screen.swift:7:2"])
	}

	// Scenario: F8 assisted and qualified together are rejected at the property
	@Test
	func `Given Assisted and Qualifier together on a property When generated Then it is rejected at the property`() {
		let result = generateWithContext(decodersFile, appFile("/App/Both.swift", """
			@Service(autoInit: true)
			final class Both {
				@Assisted @Qualifier("snakeCase") let decoder: JSONDecoder
			}
			"""))
		#expect(result.errorSummary == ["qualifier.assisted /App/Both.swift:3:12"], "\(result.renderedDiagnostics)")
	}

	// MARK: - Dropped services and byte-identical output

	// Scenario: invalid auto-init services are dropped silently because the macro reports them
	@Test(arguments: [
		"""
		@Service(autoInit: true)
		final class Dropped {
			let b: B
			init(b: B) {}
		}
		""",
		"""
		@Service(autoInit: true)
		final class Dropped {
			@Published var value: Int
		}
		""",
		"""
		@Service(autoInit: true)
		final class Dropped {
			let (a, b): (A, B)
		}
		""",
		"""
		@Service(autoInit: true)
		final class Dropped {
			var value
		}
		""",
		"""
		@Service(autoInit: flag)
		final class Dropped {
			let b: B
		}
		""",
		"""
		@Service(autoInit: true)
		final class Dropped {
			@Qualifier(name) let b: B
		}
		""",
	])
	func `Given an invalid auto-init service When generated Then it is dropped silently because the macro reports it`(source: String) {
		let result = generateWithContext(appFile("/App/Dropped.swift", source))
		#expect(result.errors.isEmpty, "\(result.renderedDiagnostics)")
		expectOutput(result, excludes: ["dropped", "Dropped"])
	}

	// Scenario: autoInit false keeps today's output
	@Test
	func `Given autoInit false When generated Then the output is unchanged`() {
		let handWritten = """
			@Service
			final class Feed {
				private let repository: ItemRepository
				init(repository: ItemRepository) { self.repository = repository }
			}
			"""
		let baseline = generateWithContext(repositoryFile, appFile("/App/Feed.swift", handWritten))
		let explicit = generateWithContext(repositoryFile, appFile("/App/Feed.swift", handWritten.replacingOccurrences(of: "@Service", with: "@Service(autoInit: false)")))
		#expect(baseline.output != nil)
		#expect(explicit.output == baseline.output)
		#expect(explicit.graphMarkdown == baseline.graphMarkdown)
	}

	@Test
	func `Given autoInit false on a struct When generated Then Swift's memberwise rule still applies`() {
		let result = generateWithContext(repositoryFile, appFile("/App/Wrapper.swift", """
			@Service(autoInit: false)
			struct Wrapper {
				let repository: ItemRepository
			}
			"""))
		expectOutput(result, contains: ["Wrapper(repository: self.itemRepository)"])
	}

	// MARK: - Macro and generator agreement

	private static let agreementFixtures: [String] = [
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
		"""
		@Service(autoInit: true)
		final class ItemDetail {
			private let repository: Repository
			@Assisted let item: Item
			@Qualifier("snakeCase") private let decoder: JSONDecoder
		}
		""",
		"""
		@Service(autoInit: true)
		final class Feed {
			var logger: Logger?
			var other: Optional<Other>
			let token: Token?
			var onTap: (@MainActor () -> Void)?
		}
		""",
		"""
		@Service(autoInit: true)
		final class Mixed {
			static let shared = Mixed()
			lazy var cache: Cache = Cache()
			var name: String { "x" }
			let id = UUID()
			var count = 0
			let dependency: Dependency
		}
		""",
		"""
		@Service(autoInit: true)
		struct Wrapper {
			private let client: Client
		}
		""",
		"""
		@Service(autoInit: true)
		actor Cache {
			let store: Store
		}
		""",
		"""
		@Service(autoInit: true)
		public final class Box {
			let store: Store
		}
		""",
		"""
		@Service(autoInit: true)
		final class Counter {
			var count = 0
		}
		""",
		"""
		@Service(autoInit: true)
		final class Closures {
			let a: @Sendable (A) -> B
			let b: () -> Void
			let c: (() -> Void)
			let d: (() -> Void)?
			let e: @MainActor @Sendable () -> Void
			let f: [() -> Void]
		}
		""",
		"""
		@Service(autoInit: true)
		final class Pair {
			let a: A, b: B
			@Assisted var c: C
		}
		""",
	]

	private struct Row: Equatable {
		var label: String?
		var type: String
		var hasDefault: Bool
		var assisted: Bool
		var qualifier: String?
	}

	// Scenario: macro and generator agree on labels types defaults and markers
	@Test(arguments: agreementFixtures)
	func `Given an auto-init service When the macro and the generator derive its init Then labels, types, defaults and markers agree`(source: String) throws {
		let tree = Parser.parse(source: source)
		let group = try #require(tree.statements.first?.item.as(DeclSyntax.self)?.asProtocol(DeclGroupSyntax.self))
		let model = try SwiftBeansSyntaxRules.autoInitModel(group).get()

		// The macro path: the emitted initializer, re-parsed from its text.
		let emitted = Parser.parse(source: model.initializer.description)
		let initializer = try #require(emitted.statements.first?.item.as(InitializerDeclSyntax.self))
		let expected = initializer.signature.parameterClause.parameters.map { parameter in
			Row(
				label: parameter.firstName.text,
				type: parameter.type.trimmedDescription,
				hasDefault: parameter.defaultValue != nil,
				assisted: SwiftBeansSyntaxRules.isAssisted(parameter),
				qualifier: SwiftBeansSyntaxRules.qualifierAttribute(in: parameter.attributes)
					.flatMap { try? SwiftBeansSyntaxRules.qualifierName(of: $0).get() }
			)
		}

		// The generator path: the scanner's synthesized candidate.
		let scanned = DeclarationScanner.scan(appFile("/App/Fixture.swift", source))
		let candidate = try #require(scanned.types.first?.initializers.first)
		let actual = candidate.parameters.map { parameter in
			Row(
				label: parameter.label,
				type: parameter.typeSpelling,
				hasDefault: parameter.hasDefault,
				assisted: parameter.isAssisted,
				qualifier: parameter.qualifier.flatMap { try? $0.name.get() }
			)
		}
		#expect(!expected.isEmpty || source.contains("Counter"))
		#expect(actual == expected)
		#expect(candidate.isCandidate)
		#expect(!candidate.isInject)
		#expect(!candidate.hasEffects)
		#expect(candidate.isPublic == (model.accessModifier == .public))
	}
}
