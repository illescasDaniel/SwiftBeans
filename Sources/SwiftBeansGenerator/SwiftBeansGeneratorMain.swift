import Foundation
import SwiftBeansGeneratorCore

@main
struct SwiftBeansGeneratorMain {
	static func main() throws {
		let arguments = Array(CommandLine.arguments.dropFirst())
		var outputPath: String?
		var configPath: String?
		var sourcePaths: [String] = []

		var index = 0
		while index < arguments.count {
			let argument = arguments[index]
			switch argument {
			case "--output":
				index += 1
				guard index < arguments.count else {
					fputs("error: --output requires a path\n", stderr)
					exit(1)
				}
				outputPath = arguments[index]
			case "--config":
				index += 1
				guard index < arguments.count else {
					fputs("error: --config requires a path\n", stderr)
					exit(1)
				}
				configPath = arguments[index]
			case "--help", "-h":
				print("usage: SwiftBeansGenerator --output <file> [--config <yml>] <sources>...")
				exit(0)
			default:
				sourcePaths.append(argument)
			}
			index += 1
		}

		guard let outputPath else {
			fputs("error: --output is required\n", stderr)
			exit(1)
		}

		var sourceURLs = sourcePaths.map { URL(fileURLWithPath: $0) }

		if let configPath {
			let configURL = URL(fileURLWithPath: configPath)
			let configuration = try ScanConfigurationLoader.load(fromFile: configURL)
			let extras = ScanConfigurationLoader.extraSourceFiles(
				configuration: configuration,
				configDirectory: configURL.deletingLastPathComponent()
			)
			sourceURLs.append(contentsOf: extras)
		} else if let first = sourceURLs.first {
			let startDir = first.deletingLastPathComponent()
			if let found = ScanConfigurationLoader.findConfiguration(startingFrom: startDir) {
				let configuration = try ScanConfigurationLoader.load(fromFile: found)
				let extras = ScanConfigurationLoader.extraSourceFiles(
					configuration: configuration,
					configDirectory: found.deletingLastPathComponent()
				)
				sourceURLs.append(contentsOf: extras)
			}
		}

		sourceURLs = Array(Set(sourceURLs)).sorted { $0.path < $1.path }

		var sources: [String] = []
		for url in sourceURLs {
			sources.append(try String(contentsOf: url, encoding: .utf8))
		}

		do {
			let graph = try BeanSourceParser.buildGraph(fromSources: sources)
			let additionalImports = BeanSourceParser.collectAdditionalImports(fromSources: sources)
			let generated = try BeanCodeGenerator.generate(
				graph: graph,
				additionalImports: additionalImports
			)
			try generated.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
		} catch {
			fputs("error: \(error)\n", stderr)
			exit(1)
		}
	}
}
