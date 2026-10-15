import Foundation
import SwiftBeansGeneratorCore

/// `SwiftBeansGenerator --output <file> <source.swift>...`
///
/// Parses exactly the sources it is given; `SwiftBeansPlugin` owns the scan set
/// (target files + `.swiftbeans.yml` local packages).
@main
struct SwiftBeansGeneratorMain {
	static func main() throws {
		let arguments = Array(CommandLine.arguments.dropFirst())
		var outputPath: String?
		var sourcePaths: [String] = []

		var index = 0
		while index < arguments.count {
			let argument = arguments[index]
			switch argument {
			case "--output":
				index += 1
				guard index < arguments.count else {
					fail("--output requires a path")
				}
				outputPath = arguments[index]
			case "--help", "-h":
				print("usage: SwiftBeansGenerator --output <file> <source.swift>...")
				exit(0)
			default:
				if argument.hasPrefix("--") {
					fail("unknown option '\(argument)'")
				}
				sourcePaths.append(argument)
			}
			index += 1
		}

		guard let outputPath else {
			fail("--output is required")
		}

		// De-duplicate by resolved path and sort so output is independent of input order.
		var sourcesByPath: [String: URL] = [:]
		for path in sourcePaths {
			let url = URL(filePath: path).standardizedFileURL.resolvingSymlinksInPath()
			sourcesByPath[url.path] = url
		}
		var sources: [String] = []
		for path in sourcesByPath.keys.sorted() {
			sources.append(try String(contentsOf: sourcesByPath[path]!, encoding: .utf8))
		}

		do {
			let graph = try BeanSourceParser.buildGraph(fromSources: sources)
			let additionalImports = BeanSourceParser.collectAdditionalImports(fromSources: sources)
			let generated = try BeanCodeGenerator.generate(
				graph: graph,
				additionalImports: additionalImports
			)
			try generated.write(to: URL(filePath: outputPath), atomically: true, encoding: .utf8)
		} catch {
			fail("\(error)")
		}
	}

	private static func fail(_ message: String) -> Never {
		fputs("error: \(message)\n", stderr)
		exit(1)
	}
}
