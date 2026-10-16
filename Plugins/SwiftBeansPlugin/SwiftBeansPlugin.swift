import Foundation
import PackagePlugin

/// Runs `SwiftBeansGenerator` over the target's sources plus any `.swiftbeans.yml` local packages.
///
/// The plugin only describes where to scan (a request JSON). The generator re-reads the config and
/// re-walks the local packages every time it runs, so the plan-time file list is never the source of truth
/// for what gets generated. The plan-time resolution below only decides when the build system reruns the
/// generator. See SPEC → Source discovery.
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

	static let outputFileName = "SwiftBeansGenerated.swift"
	static let requestFileName = "SwiftBeansRequest.json"

	static func makeCommands(
		targetName: String,
		targetSources: [URL],
		scanRoot: URL,
		workDirectory: URL,
		generator: URL
	) throws -> [Command] {
		// The file list goes through a JSON file: one argument per source can exceed the OS limit.
		let request = GeneratorRequest(scanRoot: scanRoot.path, targetSources: targetSources.map(\.path))
		let requestURL = workDirectory.appending(path: requestFileName)
		try writeIfChanged(request, to: requestURL)

		let output = workDirectory.appending(path: outputFileName)
		return [
			.buildCommand(
				displayName: "SwiftBeans: generate \(targetName)",
				executable: generator,
				arguments: ["--output", output.path, "--request", requestURL.path],
				inputFiles: targetSources + [requestURL] + watchedPaths(request: request),
				outputFiles: [output]
			),
		]
	}

	/// Build inputs that make the build system rerun the generator when the scan set changes.
	///
	/// Folders are inputs too: adding or removing a file changes its folder's modification date, which
	/// plugins cannot otherwise watch. The scan root covers a `.swiftbeans.yml` created later.
	/// Config errors are ignored here; the generator reports them when it runs.
	private static func watchedPaths(request: GeneratorRequest) -> [URL] {
		let scanRoot = URL(filePath: request.scanRoot, directoryHint: .isDirectory)
		let configURL = scanRoot.appending(path: request.configFileName)
		var paths = [scanRoot]
		guard FileManager.default.fileExists(atPath: configURL.path) else {
			return paths
		}
		paths.append(configURL)
		guard
			let configuration = try? ScanConfigurationParser.load(contentsOf: configURL),
			let packages = try? ScanSetResolver.localPackageSources(for: configuration, configDirectory: scanRoot)
		else {
			return paths
		}
		var folders = Set<String>()
		for file in packages.flatMap(\.files) {
			paths.append(file)
			var folder = file.deletingLastPathComponent()
			while folders.insert(folder.path).inserted, folder.lastPathComponent != "Sources" {
				paths.append(folder)
				folder = folder.deletingLastPathComponent()
			}
		}
		return paths
	}

	/// Leaves an identical file untouched so its modification date does not rerun the generator.
	private static func writeIfChanged(_ request: GeneratorRequest, to url: URL) throws {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		let data = try encoder.encode(request)
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
