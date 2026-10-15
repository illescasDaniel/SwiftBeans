import Foundation
import SwiftBeansGeneratorCore

/// ```
/// SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] --input <generator-input.json>
/// SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] <source.swift>...   # debugging: all files are target sources
/// ```
///
/// Parses exactly the sources it is given; `SwiftBeansPlugin` owns the scan set
/// (target files + `.swiftbeans.yml` local packages) and writes the input JSON.
@main
struct SwiftBeansGeneratorMain {
	static let usage = """
		usage: SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] --input <generator-input.json>
		       SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] <source.swift>...
		"""

	static func main() {
		let arguments = Array(CommandLine.arguments.dropFirst())
		var outputPath: String?
		var inputPath: String?
		var graphMarkdownPath: String?
		var graphDotPath: String?
		var sourcePaths: [String] = []

		var index = 0
		while index < arguments.count {
			let argument = arguments[index]
			switch argument {
			case "--output", "--input", "--graph-markdown", "--graph-dot":
				index += 1
				guard index < arguments.count else {
					fail("\(argument) requires a path")
				}
				switch argument {
				case "--output": outputPath = arguments[index]
				case "--input": inputPath = arguments[index]
				case "--graph-markdown": graphMarkdownPath = arguments[index]
				default: graphDotPath = arguments[index]
				}
			case "--help", "-h":
				print(usage)
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
			fail("--output is required\n\(usage)")
		}

		let input: GeneratorInput
		if let inputPath {
			guard sourcePaths.isEmpty else {
				fail("pass either --input or source paths, not both")
			}
			do {
				input = try JSONDecoder().decode(GeneratorInput.self, from: Data(contentsOf: URL(filePath: inputPath)))
			} catch {
				fail("cannot read \(inputPath): \(error)")
			}
		} else {
			input = GeneratorInput(targetSources: sourcePaths)
		}

		let result = SwiftBeansGeneration.generate(input: input)
		for diagnostic in result.diagnostics {
			printError(diagnostic.rendered)
		}
		guard let output = result.output else {
			exit(1)
		}
		let files: [(path: String?, contents: String?)] = [
			(outputPath, output),
			(graphMarkdownPath, result.graphMarkdown),
			(graphDotPath, result.graphDot),
		]
		for case (let path?, let contents?) in files {
			do {
				try GeneratedFileWriter.write(contents, to: URL(filePath: path))
			} catch {
				fail("cannot write \(path): \(error)")
			}
		}
	}

	// `stderr` is shared mutable state: Swift 6 rejects `fputs(_, stderr)` on Linux.
	private static func printError(_ message: String) {
		FileHandle.standardError.write(Data((message + "\n").utf8))
	}

	private static func fail(_ message: String) -> Never {
		printError("error: \(message)")
		exit(1)
	}
}
