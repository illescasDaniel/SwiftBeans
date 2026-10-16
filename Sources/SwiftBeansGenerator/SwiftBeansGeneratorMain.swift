import Foundation
import SwiftBeansGeneratorCore

/// ```
/// SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] --request <generator-request.json>
/// SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] --input <generator-input.json>
/// SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] <source.swift>...   # debugging: all files are target sources
/// ```
///
/// `--request` is what `SwiftBeansPlugin` uses: the generator re-reads `.swiftbeans.yml` and re-walks the
/// local packages on every run. `--input` and plain source paths parse exactly the files given.
/// `--graph-markdown` / `--graph-dot` write the resolved-graph dumps on success only.
@main
struct SwiftBeansGeneratorMain {
	static let usage = """
		usage: SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] --request <generator-request.json>
		       SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] --input <generator-input.json>
		       SwiftBeansGenerator --output <file> [--graph-markdown <file>] [--graph-dot <file>] <source.swift>...
		"""

	static func main() {
		let arguments = Array(CommandLine.arguments.dropFirst())
		var outputPath: String?
		var inputPath: String?
		var requestPath: String?
		var graphMarkdownPath: String?
		var graphDotPath: String?
		var sourcePaths: [String] = []

		var index = 0
		while index < arguments.count {
			let argument = arguments[index]
			switch argument {
			case "--output", "--input", "--request", "--graph-markdown", "--graph-dot":
				index += 1
				guard index < arguments.count else {
					fail("\(argument) requires a path")
				}
				switch argument {
				case "--output": outputPath = arguments[index]
				case "--input": inputPath = arguments[index]
				case "--request": requestPath = arguments[index]
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

		let result: GenerationResult
		if let requestPath {
			guard inputPath == nil, sourcePaths.isEmpty else {
				fail("--request cannot be combined with --input or source paths")
			}
			do {
				let request = try JSONDecoder().decode(GeneratorRequest.self, from: Data(contentsOf: URL(filePath: requestPath)))
				result = SwiftBeansGeneration.generate(request: request)
			} catch {
				fail("cannot read \(requestPath): \(error)")
			}
		} else if let inputPath {
			guard sourcePaths.isEmpty else {
				fail("pass either --input or source paths, not both")
			}
			do {
				let input = try JSONDecoder().decode(GeneratorInput.self, from: Data(contentsOf: URL(filePath: inputPath)))
				result = SwiftBeansGeneration.generate(input: input)
			} catch {
				fail("cannot read \(inputPath): \(error)")
			}
		} else {
			result = SwiftBeansGeneration.generate(input: GeneratorInput(targetSources: sourcePaths))
		}

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
				let url = URL(filePath: path)
				try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
				try GeneratedFileWriter.write(contents, to: url)
			} catch {
				fail("cannot write \(path): \(error)")
			}
		}
	}

	/// `stderr` is not concurrency-safe to reference on Linux (Swift 6 mode).
	private static func printError(_ message: String) {
		FileHandle.standardError.write(Data((message + "\n").utf8))
	}

	private static func fail(_ message: String) -> Never {
		printError("error: \(message)")
		exit(1)
	}

	/// `FileHandle` instead of `fputs(_:stderr)`: Glibc's `stderr` is a mutable global that Swift 6 rejects.
	private static func printError(_ line: String) {
		FileHandle.standardError.write(Data("\(line)\n".utf8))
	}
}
