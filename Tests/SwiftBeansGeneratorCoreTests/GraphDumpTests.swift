import Foundation
import Testing
@testable import SwiftBeansGeneratorCore

private let databaseFile = appFile("/App/Database.swift", """
	@Service
	final class Database {
		init() {}
	}
	""")

private let reportFile = appFile("/App/Report.swift", """
	@Service
	final class ReportService {
		init(database: Database) {}
	}
	""")

private let viewModelFile = appFile("/App/ItemViewModel.swift", """
	@Service(scope: .transient)
	final class ItemViewModel {
		init(report: ReportService, @Assisted item: Item) {}
	}
	""")

private let fixtureGraph = [databaseFile, reportFile, viewModelFile]

private func markdown(_ files: [SourceFile]) throws -> String {
	let result = SwiftBeansGeneration.generate(sources: [appContextFile] + files)
	#expect(result.errors.isEmpty, "unexpected errors:\n\(result.renderedDiagnostics)")
	return try #require(result.graphMarkdown)
}

private func dot(_ files: [SourceFile]) throws -> String {
	let result = SwiftBeansGeneration.generate(sources: [appContextFile] + files)
	#expect(result.errors.isEmpty, "unexpected errors:\n\(result.renderedDiagnostics)")
	return try #require(result.graphDot)
}

@Suite("Graph dump — SPEC graph-dump")
struct GraphDumpTests {
	@Test
	func `Given a valid graph When generated Then the Markdown lists every provider and each injected edge`() throws {
		let text = try markdown(fixtureGraph)
		#expect(text == """
			# SwiftBeans graph

			- Context: `AppContext`
			- Providers: 3
			- Dependencies: 2

			## Providers

			| Key | Accessor | Scope | Provided by | Assisted |
			|-----|----------|-------|-------------|----------|
			| `Database` | `database` | singleton | `Database` | — |
			| `ItemViewModel` | `itemViewModel` | transient | `ItemViewModel` | `item:` |
			| `ReportService` | `reportService` | singleton | `ReportService` | — |

			## Dependencies

			- `ItemViewModel` → `ReportService`
			- `ReportService` → `Database`

			""")
	}

	@Test
	func `Given a valid graph When generated Then the DOT has one node per provider and one edge per dependency`() throws {
		let text = try dot(fixtureGraph)
		#expect(text == """
			digraph SwiftBeans {
				rankdir=LR;
				node [shape=box, fontname="Helvetica"];
				"Database" [label="Database\\nsingleton · Database"];
				"ItemViewModel" [label="ItemViewModel\\ntransient · ItemViewModel\\nassisted (item:)", style=dashed];
				"ReportService" [label="ReportService\\nsingleton · ReportService"];
				"ItemViewModel" -> "ReportService";
				"ReportService" -> "Database";
			}

			""")
		#expect(occurrences(of: "->", in: text) == 2)
	}

	@Test
	func `Given an assisted provider When generated Then runtime arguments are flagged but are not edges`() throws {
		let text = try markdown([
			databaseFile,
			appFile("/App/Detail.swift", """
				@Service
				final class DetailViewModel {
					init(database: Database, @Assisted _ id: Int, @Assisted title: String) {}
				}
				"""),
		])
		#expect(text.contains("| `DetailViewModel` | `detailViewModel` | transient"))
		#expect(text.contains("`_:name:`") || text.contains("`_:title:`"), Comment(rawValue: text))
		#expect(text.contains("- `DetailViewModel` → `Database`\n"))
		#expect(!text.contains("Int"), "assisted argument types are not nodes:\n\(text)")
		#expect(!text.contains("String"), Comment(rawValue: text))
	}

	@Test
	func `Given input order changes When generated Then both dumps are byte-identical`() throws {
		let forward = SwiftBeansGeneration.generate(sources: [appContextFile] + fixtureGraph)
		let reversed = SwiftBeansGeneration.generate(sources: (fixtureGraph + [appContextFile]).reversed())
		#expect(forward.graphMarkdown != nil)
		#expect(forward.graphMarkdown == reversed.graphMarkdown)
		#expect(forward.graphDot == reversed.graphDot)
	}

	@Test
	func `Given nodes declared out of order When generated Then nodes are sorted by key and edges by from then to`() throws {
		let text = try dot([
			appFile("/App/Z.swift", """
				@Service
				final class Zebra {
					init(mango: Mango, apple: Apple) {}
				}
				"""),
			appFile("/App/M.swift", "@Service\nfinal class Mango { init() {} }"),
			appFile("/App/A.swift", "@Service\nfinal class Apple { init() {} }"),
		])
		let order = ["\"Apple\" [", "\"Mango\" [", "\"Zebra\" [", "\"Zebra\" -> \"Apple\"", "\"Zebra\" -> \"Mango\""]
		let positions = order.map { text.range(of: $0)?.lowerBound }
		#expect(positions.allSatisfy { $0 != nil }, Comment(rawValue: text))
		#expect(positions.compactMap { $0 } == positions.compactMap { $0 }.sorted(), Comment(rawValue: text))
	}

	@Test
	func `Given a bound service and a bean When generated Then keys are the bound key and provided-by names the source`() throws {
		let text = try markdown([
			appFile("/App/Config.swift", """
				@Configuration
				enum AppConfiguration {
					@Bean
					static func session() -> URLSession { URLSession() }
				}
				"""),
			appFile("/App/Clock.swift", """
				protocol Clock {}
				@Service(boundTo: (any Clock).self)
				final class SystemClock: Clock {
					init(session: URLSession) {}
				}
				"""),
		])
		#expect(text.contains("| `URLSession` | `urlSession` | singleton | `AppConfiguration.session` | — |"), Comment(rawValue: text))
		#expect(text.contains("| `Clock` | `clock` | singleton | `SystemClock` | — |"), Comment(rawValue: text))
		#expect(text.contains("- `Clock` → `URLSession`\n"), Comment(rawValue: text))
	}

	@Test
	func `Given a defaulted parameter without a provider When generated Then it is not an edge`() throws {
		let text = try dot([
			appFile("/App/Cache.swift", """
				@Service
				final class Cache {
					init(limit: Limit = Limit()) {}
				}
				"""),
		])
		#expect(!text.contains("->"), Comment(rawValue: text))
		let markdown = try markdown([
			appFile("/App/Cache.swift", """
				@Service
				final class Cache {
					init(limit: Limit = Limit()) {}
				}
				"""),
		])
		#expect(markdown.contains("- Dependencies: 0"))
		#expect(markdown.hasSuffix("## Dependencies\n\nNone.\n"), Comment(rawValue: markdown))
	}

	@Test
	func `Given two parameters of one key When generated Then there is a single edge`() throws {
		let text = try dot([
			databaseFile,
			appFile("/App/Pair.swift", """
				@Service
				final class Pair {
					init(first: Database, second: Database) {}
				}
				"""),
		])
		#expect(occurrences(of: "\"Pair\" -> \"Database\";", in: text) == 1)
	}

	@Test
	func `Given a missing dependency When generated Then no dump is produced`() {
		let result = generateWithContext(reportFile)
		#expect(result.output == nil)
		#expect(result.graphMarkdown == nil)
		#expect(result.graphDot == nil)
	}

	@Test
	func `Given providers without an application context When generated Then the Markdown says none and lists them`() throws {
		let result = SwiftBeansGeneration.generate(sources: [databaseFile])
		let text = try #require(result.graphMarkdown)
		#expect(text.contains("- Context: none\n"))
		#expect(text.contains("| `Database` | `database` | singleton | `Database` | — |"))
		#expect(result.graphDot != nil)
	}

	@Test
	func `Given a graph with no providers When generated Then both dumps are still valid`() throws {
		let result = SwiftBeansGeneration.generate(sources: [appContextFile])
		#expect(try #require(result.graphMarkdown).contains("- Providers: 0"))
		#expect(try #require(result.graphDot) == "digraph SwiftBeans {\n\trankdir=LR;\n\tnode [shape=box, fontname=\"Helvetica\"];\n}\n")
	}

	@Test
	func `Given a local package provider When generated Then it is listed like any other`() throws {
		let result = SwiftBeansGeneration.generate(sources: [
			appContextFile,
			packageFile("GreetingKit", "/Pkg/Greeter.swift", """
				@Service
				public final class Greeter {
					public init() {}
				}
				"""),
		])
		#expect(try #require(result.graphMarkdown).contains("| `Greeter` | `greeter` | singleton | `Greeter` | — |"))
	}
}
