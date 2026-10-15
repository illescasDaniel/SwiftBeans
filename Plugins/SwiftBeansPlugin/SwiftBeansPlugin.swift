import Foundation
import PackagePlugin

/// Runs `SwiftBeansGenerator` over the target's sources plus any `.swiftbeans.yml` local packages.
///
/// The scan set comes only from the build system's file list and the config file at the scan root
/// (package folder for SPM, `.xcodeproj` folder for Xcode). See SPEC → Source discovery.
@main
struct SwiftBeansPlugin: BuildToolPlugin {
	func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
		guard let sourceTarget = target as? SourceModuleTarget else {
			return []
		}
		return try Self.makeCommands(
			targetName: sourceTarget.name,
			targetSources: sourceTarget.sourceFiles(withSuffix: "swift").map(\.url),
			scanRoot: context.package.directoryURL,
			workDirectory: context.pluginWorkDirectoryURL,
			generator: context.tool(named: "SwiftBeansGenerator").url
		)
	}

	static let configFileName = ".swiftbeans.yml"
	static let outputFileName = "SwiftBeansGenerated.swift"
	static let graphMarkdownFileName = "SwiftBeansGraph.md"
	static let graphDotFileName = "SwiftBeansGraph.dot"
	static let inputFileName = "SwiftBeansInput.json"

	static func makeCommands(
		targetName: String,
		targetSources: [URL],
		scanRoot: URL,
		workDirectory: URL,
		generator: URL
	) throws -> [Command] {
		let configURL = scanRoot.appending(path: configFileName)
		var packages: [LocalPackageTargetSources] = []
		var inputFiles = targetSources
		if FileManager.default.fileExists(atPath: configURL.path) {
			do {
				let configuration = try ScanConfigurationParser.load(contentsOf: configURL)
				packages = try ScanSetResolver.localPackageSources(for: configuration, configDirectory: scanRoot)
			} catch {
				Diagnostics.error(error.message, file: configURL.path, line: error.line)
				return []
			}
			inputFiles.append(configURL)
			inputFiles += packages.flatMap(\.files)
		}

		// The file list goes through a JSON file: one argument per source can exceed the OS limit.
		let input = GeneratorInput(
			targetSources: targetSources.map(\.path),
			localPackages: packages.map { .init(module: $0.module, sources: $0.files.map(\.path)) }
		)
		let inputURL = workDirectory.appending(path: inputFileName)
		try writeIfChanged(input, to: inputURL)
		inputFiles.append(inputURL)

		let output = workDirectory.appending(path: outputFileName)
		let graphMarkdown = workDirectory.appending(path: graphMarkdownFileName)
		let graphDot = workDirectory.appending(path: graphDotFileName)
		return [
			.buildCommand(
				displayName: "SwiftBeans: generate \(targetName)",
				executable: generator,
				arguments: [
					"--output", output.path,
					"--graph-markdown", graphMarkdown.path,
					"--graph-dot", graphDot.path,
					"--input", inputURL.path,
				],
				inputFiles: inputFiles,
				// The graph files are deliberately not declared: SwiftPM treats every declared output it
				// cannot compile as a resource and would add a resource bundle to the target.
				outputFiles: [output]
			),
		]
	}

	/// Leaves an identical file untouched so its modification date does not rerun the generator.
	private static func writeIfChanged(_ input: GeneratorInput, to url: URL) throws {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		let data = try encoder.encode(input)
		if let existing = try? Data(contentsOf: url), existing == data {
			return
		}
		try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try data.write(to: url, options: .atomic)
	}
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftBeansPlugin: XcodeBuildToolPlugin {
	func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
		let targetSources = target.inputFiles
			.filter { $0.type == .source && $0.url.pathExtension == "swift" }
			.map(\.url)
		return try Self.makeCommands(
			targetName: target.displayName,
			targetSources: targetSources,
			scanRoot: context.xcodeProject.directoryURL,
			workDirectory: context.pluginWorkDirectoryURL,
			generator: context.tool(named: "SwiftBeansGenerator").url
		)
	}
}
#endif
