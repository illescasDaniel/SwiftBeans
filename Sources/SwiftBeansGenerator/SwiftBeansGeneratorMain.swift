import Foundation
import SwiftBeansGeneratorCore

/// ```
/// SwiftBeansGenerator --output <file> --input <generator-input.json>
/// SwiftBeansGenerator --output <file> <source.swift>...   # debugging: all files are target sources
/// ```
///
/// Parses exactly the sources it is given; `SwiftBeansPlugin` owns the scan set
/// (target files + `.swiftbeans.yml` local packages) and writes the input JSON.
@main
struct SwiftBeansGeneratorMain {
	static let usage = """
		usage: SwiftBeansGenerator --output <file> --input <generator-input.json>
		       SwiftBeansGenerator --output <file> <source.swift>...
		"""

	static func main() {
		let arguments = Array(CommandLine.arguments.dropFirst())
		var outputPath: String?
		var inputPath: String?
		var sourcePaths: [String] = []

		var index = 0
		while index < arguments.count {
			let argument = arguments[index]
			switch argument {
			case "--output", "--input":
				index += 1
				guard index < arguments.count else {
					fail("\(argument) requires a path")
				}
				if argument == "--output" {
					outputPath = arguments[index]
				} else {
					inputPath = arguments[index]
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
			fputs("\(diagnostic.rendered)\n", stderr)
		}
		guard let output = result.output else {
			exit(1)
		}
		do {
			try GeneratedFileWriter.write(output, to: URL(filePath: outputPath))
		} catch {
			fail("cannot write \(outputPath): \(error)")
		}
	}

	private static func fail(_ message: String) -> Never {
		fputs("error: \(message)\n", stderr)
		exit(1)
	}
}
