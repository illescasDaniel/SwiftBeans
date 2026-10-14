import Foundation
import PackagePlugin

@main
struct SwiftBeansPlugin: BuildToolPlugin {
	func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
		guard let sourceTarget = target as? SourceModuleTarget else {
			return []
		}
		let generator = try context.tool(named: "SwiftBeansGenerator")
		let output = context.pluginWorkDirectoryURL.appending(path: "SwiftBeansGenerated.swift")
		var inputFiles = sourceTarget.sourceFiles
			.filter { $0.type == .source }
			.map(\.url)
		inputFiles = Self.expandedSwiftSources(from: inputFiles)

		var arguments = [
			"--output", output.path,
		]
		arguments.append(contentsOf: inputFiles.map(\.path))

		if let config = Self.findConfig(near: inputFiles) {
			arguments.insert(contentsOf: ["--config", config.path], at: 2)
		}

		return [
			.buildCommand(
				displayName: "SwiftBeans: generate \(sourceTarget.name)",
				executable: generator.url,
				arguments: arguments,
				inputFiles: inputFiles,
				outputFiles: [output]
			),
		]
	}

	/// Prefer a full recursive scan of the module source root so nested folders
	/// (e.g. Xcode synchronized groups with Domain/Data/Presentation) are included.
	static func expandedSwiftSources(from listed: [URL]) -> [URL] {
		guard let root = inferSourceRoot(from: listed) else {
			return listed.sorted { $0.path < $1.path }
		}
		let scanned = enumerateSwiftFiles(in: root)
		if scanned.isEmpty {
			return listed.sorted { $0.path < $1.path }
		}
		return Array(Set(scanned)).sorted { $0.path < $1.path }
	}

	static func inferSourceRoot(from files: [URL]) -> URL? {
		guard var directory = files.first?.deletingLastPathComponent() else {
			return nil
		}
		let fileManager = FileManager.default
		for _ in 0..<6 {
			let hasAppEntry = fileManager.fileExists(atPath: directory.appendingPathComponent("MyApp.swift").path)
				|| fileManager.fileExists(atPath: directory.appendingPathComponent("Assets.xcassets").path)
			if hasAppEntry {
				return directory
			}
			let parent = directory.deletingLastPathComponent()
			if parent.path == directory.path {
				break
			}
			directory = parent
		}
		return files.first?.deletingLastPathComponent()
	}

	static func enumerateSwiftFiles(in directory: URL) -> [URL] {
		let fileManager = FileManager.default
		guard let enumerator = fileManager.enumerator(
			at: directory,
			includingPropertiesForKeys: [.isRegularFileKey],
			options: [.skipsHiddenFiles]
		) else {
			return []
		}
		var files: [URL] = []
		for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
			files.append(fileURL)
		}
		return files
	}

	static func findConfig(near files: [URL]) -> URL? {
		guard let first = files.first else { return nil }
		var current = first.deletingLastPathComponent()
		let fileManager = FileManager.default
		for _ in 0..<8 {
			let candidate = current.appendingPathComponent(".swiftbeans.yml")
			if fileManager.isReadableFile(atPath: candidate.path) {
				return candidate
			}
			let parent = current.deletingLastPathComponent()
			if parent.path == current.path { break }
			current = parent
		}
		return nil
	}
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftBeansPlugin: XcodeBuildToolPlugin {
	func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
		let generator = try context.tool(named: "SwiftBeansGenerator")
		let output = context.pluginWorkDirectoryURL.appending(path: "SwiftBeansGenerated.swift")
		var inputFiles = target.inputFiles
			.filter { $0.type == .source }
			.map(\.url)
		inputFiles = SwiftBeansPlugin.expandedSwiftSources(from: inputFiles)

		var arguments = [
			"--output", output.path,
		]
		arguments.append(contentsOf: inputFiles.map(\.path))

		if let config = SwiftBeansPlugin.findConfig(near: inputFiles) {
			arguments.insert(contentsOf: ["--config", config.path], at: 2)
		}

		return [
			.buildCommand(
				displayName: "SwiftBeans: generate \(target.displayName)",
				executable: generator.url,
				arguments: arguments,
				inputFiles: inputFiles,
				outputFiles: [output]
			),
		]
	}
}
#endif
