import Foundation
import SwiftBeans

/// Loads `.swiftbeans.yml` and resolves extra Swift sources from `local_packages`.
public enum ScanConfigurationLoader {
	public static func load(fromFile url: URL) throws -> SwiftBeansScanConfiguration {
		let data = try Data(contentsOf: url)
		return try decodeYAML(data)
	}

	public static func findConfiguration(startingFrom directory: URL) -> URL? {
		var current = directory.standardizedFileURL
		let fileManager = FileManager.default
		while true {
			let candidate = current.appendingPathComponent(".swiftbeans.yml")
			if fileManager.isReadableFile(atPath: candidate.path) {
				return candidate
			}
			let parent = current.deletingLastPathComponent()
			if parent.path == current.path {
				return nil
			}
			current = parent
		}
	}

	/// Resolves `Sources/<target>/**/*.swift` under each local package path (relative to config file directory).
	public static func extraSourceFiles(
		configuration: SwiftBeansScanConfiguration,
		configDirectory: URL
	) -> [URL] {
		var files: [URL] = []
		let fileManager = FileManager.default
		for localPackage in configuration.localPackages {
			let packageRoot = configDirectory.appendingPathComponent(localPackage.path)
			for targetName in localPackage.targets {
				let sourcesRoot = packageRoot.appendingPathComponent("Sources").appendingPathComponent(targetName)
				guard let enumerator = fileManager.enumerator(
					at: sourcesRoot,
					includingPropertiesForKeys: [.isRegularFileKey],
					options: [.skipsHiddenFiles]
				) else {
					continue
				}
				for case let fileURL as URL in enumerator {
					if fileURL.pathExtension == "swift" {
						files.append(fileURL)
					}
				}
			}
		}
		return files
	}

	/// Minimal YAML decoder for the documented `.swiftbeans.yml` schema (no full YAML dependency).
	public static func decodeYAML(_ data: Data) throws -> SwiftBeansScanConfiguration {
		guard let text = String(data: data, encoding: .utf8) else {
			return SwiftBeansScanConfiguration()
		}
		var packages: [SwiftBeansScanConfiguration.LocalPackage] = []
		var currentPath: String?
		var currentTargets: [String] = []
		var inLocalPackages = false
		var inTargets = false

		func flush() {
			if let path = currentPath {
				packages.append(.init(path: path, targets: currentTargets))
			}
			currentPath = nil
			currentTargets = []
			inTargets = false
		}

		for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
			let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			if trimmed.isEmpty { continue }

			if trimmed.hasPrefix("local_packages:") {
				inLocalPackages = true
				continue
			}
			guard inLocalPackages else { continue }

			if trimmed.hasPrefix("- path:") {
				flush()
				currentPath = value(after: "path:", in: trimmed)
				inTargets = false
				continue
			}
			if trimmed.hasPrefix("path:") {
				flush()
				currentPath = value(after: "path:", in: trimmed)
				inTargets = false
				continue
			}
			if trimmed.hasPrefix("targets:") {
				inTargets = true
				continue
			}
			if inTargets, trimmed.hasPrefix("-") {
				let target = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
				if !target.isEmpty {
					currentTargets.append(target)
				}
			}
		}
		flush()
		return SwiftBeansScanConfiguration(localPackages: packages)
	}

	private static func value(after marker: String, in line: String) -> String {
		guard let range = line.range(of: marker) else {
			return ""
		}
		return line[range.upperBound...].trimmingCharacters(in: .whitespaces)
	}
}
