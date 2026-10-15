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

	static func makeCommands(
		targetName: String,
		targetSources: [URL],
		scanRoot: URL,
		workDirectory: URL,
		generator: URL
	) throws -> [Command] {
		let configURL = scanRoot.appending(path: configFileName)
		var sources = targetSources
		var inputFiles: [URL] = []
		if FileManager.default.fileExists(atPath: configURL.path) {
			do {
				let configuration = try ScanConfigurationParser.load(contentsOf: configURL)
				sources += try ScanSetResolver.localPackageSources(
					for: configuration,
					configDirectory: scanRoot
				)
			} catch {
				Diagnostics.error(error.message, file: configURL.path, line: error.line)
				return []
			}
			inputFiles.append(configURL)
		}
		inputFiles += sources

		let output = workDirectory.appending(path: outputFileName)
		return [
			.buildCommand(
				displayName: "SwiftBeans: generate \(targetName)",
				executable: generator,
				arguments: ["--output", output.path] + sources.map(\.path),
				inputFiles: inputFiles,
				outputFiles: [output]
			),
		]
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
