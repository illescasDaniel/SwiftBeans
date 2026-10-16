// Scan-set resolution for `.swiftbeans.yml`.
//
// Foundation-only and byte-identical in two places:
// - Sources/SwiftBeansGeneratorCore/ScanSetResolution.swift (canonical, unit-tested)
// - Plugins/SwiftBeansPlugin/ScanSetResolution.swift (build tool plugins cannot link library targets)
// `ScanSetResolutionDriftTests` fails if the copies differ. Edit one, copy it over the other.

import Foundation

/// Contents of a `.swiftbeans.yml` scan configuration file.
struct SwiftBeansScanConfiguration: Equatable, Sendable {
	var localPackages: [LocalPackage]

	init(localPackages: [LocalPackage] = []) {
		self.localPackages = localPackages
	}

	struct LocalPackage: Equatable, Sendable {
		/// Package folder, relative to the folder containing the config file.
		var path: String
		/// Target names whose `Sources/<target>/` folders are scanned.
		var targets: [String]
		/// 1-based line of the `- path:` entry, for diagnostics.
		var line: Int
	}
}

struct ScanConfigurationError: Error, CustomStringConvertible {
	enum Kind: Equatable, Sendable {
		case unreadable
		case syntax
		case missingPackage
		case notAPackage
		case missingTarget
	}

	var kind: Kind
	/// 1-based line in the config file, when known.
	var line: Int?
	/// Names the offending entry, e.g. `local_packages path 'Packages/Net': no Package.swift`.
	var message: String

	var description: String { message }
}

enum ScanConfigurationParser {
	/// Reads and parses a `.swiftbeans.yml` file.
	static func load(contentsOf url: URL) throws(ScanConfigurationError) -> SwiftBeansScanConfiguration {
		let data: Data
		do {
			data = try Data(contentsOf: url)
		} catch {
			throw ScanConfigurationError(kind: .unreadable, line: nil, message: "cannot read \(url.path): \(error.localizedDescription)")
		}
		guard let text = String(data: data, encoding: .utf8) else {
			throw ScanConfigurationError(kind: .unreadable, line: nil, message: "\(url.path) is not valid UTF-8")
		}
		return try parse(text)
	}

	/// Parses the documented `.swiftbeans.yml` schema (block lists, optional quotes, `#` comments).
	///
	/// ```yaml
	/// local_packages:
	///   - path: Packages/Networking
	///     targets:
	///       - Networking
	/// ```
	static func parse(_ text: String) throws(ScanConfigurationError) -> SwiftBeansScanConfiguration {
		var packages: [SwiftBeansScanConfiguration.LocalPackage] = []
		var inLocalPackages = false
		var current: SwiftBeansScanConfiguration.LocalPackage?
		var entryIndent = 0
		var inTargets = false

		func finishEntry() throws(ScanConfigurationError) {
			guard let entry = current else { return }
			guard !entry.targets.isEmpty else {
				throw syntaxError(entry.line, "local_packages path '\(entry.path)' has no targets")
			}
			packages.append(entry)
			current = nil
			inTargets = false
		}

		// `isNewline` also splits on "\r\n", which Swift treats as a single `Character`.
		let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
		for (index, rawLine) in lines.enumerated() {
			let lineNumber = index + 1
			let line = stripComment(String(rawLine))
			let content = line.trimmingCharacters(in: .whitespaces)
			if content.isEmpty { continue }

			let leading = line.prefix { $0 == " " || $0 == "\t" }
			if leading.contains("\t") {
				throw syntaxError(lineNumber, "tabs are not allowed for indentation")
			}
			let indent = leading.count

			if content.hasPrefix("-") {
				guard inLocalPackages else {
					throw syntaxError(lineNumber, "unexpected list item outside local_packages")
				}
				let item = content.dropFirst().trimmingCharacters(in: .whitespaces)
				if inTargets, let entry = current, indent > entryIndent {
					guard let target = try scalar(item, line: lineNumber) else {
						throw syntaxError(lineNumber, "empty target name")
					}
					current = SwiftBeansScanConfiguration.LocalPackage(
						path: entry.path,
						targets: entry.targets + [target],
						line: entry.line
					)
					continue
				}
				if current != nil, indent != entryIndent {
					throw syntaxError(lineNumber, "unexpected indentation")
				}
				try finishEntry()
				let (key, value) = try keyValue(item, line: lineNumber)
				guard key == "path" else {
					throw syntaxError(lineNumber, "each local_packages entry must start with 'path:'")
				}
				guard let path = try scalar(value, line: lineNumber) else {
					throw syntaxError(lineNumber, "empty path")
				}
				current = SwiftBeansScanConfiguration.LocalPackage(path: path, targets: [], line: lineNumber)
				entryIndent = indent
				continue
			}

			if indent == 0 {
				try finishEntry()
				let (key, value) = try keyValue(content, line: lineNumber)
				guard key == "local_packages" else {
					throw syntaxError(lineNumber, "unknown key '\(key)'")
				}
				switch value {
				case "":
					inLocalPackages = true
				case "[]":
					inLocalPackages = false
				default:
					throw syntaxError(lineNumber, "local_packages must be a block list")
				}
				continue
			}

			guard current != nil, indent > entryIndent else {
				throw syntaxError(lineNumber, "unexpected indentation")
			}
			let (key, value) = try keyValue(content, line: lineNumber)
			switch key {
			case "targets":
				guard value.isEmpty else {
					throw syntaxError(lineNumber, "targets must be a block list ('- Name' on the following lines)")
				}
				inTargets = true
			default:
				throw syntaxError(lineNumber, "unknown key '\(key)' in local_packages entry")
			}
		}
		try finishEntry()
		return SwiftBeansScanConfiguration(localPackages: packages)
	}

	/// Removes a `#` comment that starts the line or follows whitespace, outside quotes.
	private static func stripComment(_ line: String) -> String {
		var quote: Character?
		var previous: Character = " "
		for index in line.indices {
			let character = line[index]
			if let open = quote {
				if character == open { quote = nil }
			} else if character == "\"" || character == "'" {
				quote = character
			} else if character == "#", previous == " " || previous == "\t" {
				return String(line[..<index])
			}
			previous = character
		}
		return line
	}

	private static func keyValue(_ text: String, line: Int) throws(ScanConfigurationError) -> (String, String) {
		guard let colon = text.firstIndex(of: ":") else {
			throw syntaxError(line, "expected 'key: value'")
		}
		let key = text[..<colon].trimmingCharacters(in: .whitespaces)
		let value = text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces)
		return (key, value)
	}

	/// Returns the unquoted scalar, or `nil` when empty.
	private static func scalar(_ text: String, line: Int) throws(ScanConfigurationError) -> String? {
		let trimmed = text.trimmingCharacters(in: .whitespaces)
		guard let first = trimmed.first else { return nil }
		if first == "\"" || first == "'" {
			guard trimmed.count >= 2, trimmed.last == first else {
				throw syntaxError(line, "unterminated quote")
			}
			let inner = String(trimmed.dropFirst().dropLast())
			return inner.isEmpty ? nil : inner
		}
		if first == "[" || first == "{" {
			throw syntaxError(line, "inline lists and maps are not supported")
		}
		return trimmed
	}

	private static func syntaxError(_ line: Int, _ message: String) -> ScanConfigurationError {
		ScanConfigurationError(kind: .syntax, line: line, message: message)
	}
}

/// What the plugin hands the generator (`--input <file>.json`).
public struct GeneratorInput: Sendable, Codable, Equatable {
	/// Absolute paths of the target's own Swift sources.
	public var targetSources: [String]
	public var localPackages: [LocalPackageSources]

	public init(targetSources: [String], localPackages: [LocalPackageSources] = []) {
		self.targetSources = targetSources
		self.localPackages = localPackages
	}

	public struct LocalPackageSources: Sendable, Codable, Equatable {
		/// Swift module name of the package target.
		public var module: String
		/// Absolute paths of the target's Swift sources.
		public var sources: [String]

		public init(module: String, sources: [String]) {
			self.module = module
			self.sources = sources
		}
	}
}

/// What the plugin hands the generator at plan time (`--request <file>.json`).
///
/// It names where to scan, not what to scan: the generator re-reads the config file and re-walks
/// the local package folders on every build, so new files are picked up without a re-plan.
public struct GeneratorRequest: Sendable, Codable, Equatable {
	/// Package folder (SPM) or `.xcodeproj` folder (Xcode); the only place the config file is looked up.
	public var scanRoot: String
	/// Absolute paths of the target's Swift sources, as listed by the build system.
	public var targetSources: [String]
	public var configFileName: String

	public init(scanRoot: String, targetSources: [String], configFileName: String = ".swiftbeans.yml") {
		self.scanRoot = scanRoot
		self.targetSources = targetSources
		self.configFileName = configFileName
	}
}

/// The `.swift` files of one `local_packages` target.
struct LocalPackageTargetSources: Equatable, Sendable {
	/// Target name as written in the config.
	var target: String
	/// Swift module name of the target (SwiftPM's c99name).
	var module: String
	/// Sorted, standardized, symlink-resolved files.
	var files: [URL]
}

enum ScanSetResolver {
	/// Resolves `local_packages` to one entry per listed target (in config order), each with its
	/// sorted `.swift` files. Paths are relative to `configDirectory`, standardized and symlink-resolved.
	/// A file reached through two entries is kept only in the first; entries left empty are omitted.
	static func localPackageSources(
		for configuration: SwiftBeansScanConfiguration,
		configDirectory: URL,
		fileManager: FileManager = .default
	) throws(ScanConfigurationError) -> [LocalPackageTargetSources] {
		var seenPaths = Set<String>()
		var result: [LocalPackageTargetSources] = []
		for package in configuration.localPackages {
			let packageRoot = configDirectory
				.appending(path: package.path, directoryHint: .isDirectory)
				.standardizedFileURL
				.resolvingSymlinksInPath()
			let entry = "local_packages path '\(package.path)'"
			guard isDirectory(packageRoot, fileManager) else {
				throw ScanConfigurationError(
					kind: .missingPackage,
					line: package.line,
					message: "\(entry): folder not found at \(packageRoot.path)"
				)
			}
			guard fileManager.fileExists(atPath: packageRoot.appending(path: "Package.swift").path) else {
				throw ScanConfigurationError(
					kind: .notAPackage,
					line: package.line,
					message: "\(entry): no Package.swift in \(packageRoot.path)"
				)
			}
			for target in package.targets {
				let sourcesRoot = packageRoot.appending(path: "Sources/\(target)", directoryHint: .isDirectory)
				guard isDirectory(sourcesRoot, fileManager) else {
					throw ScanConfigurationError(
						kind: .missingTarget,
						line: package.line,
						message: "\(entry) target '\(target)': no Sources/\(target) folder in \(packageRoot.path)"
					)
				}
				let files = swiftFiles(in: sourcesRoot, fileManager)
					.sorted { $0.path < $1.path }
					.filter { seenPaths.insert($0.path).inserted }
				if !files.isEmpty {
					result.append(LocalPackageTargetSources(
						target: target,
						module: moduleName(forTarget: target),
						files: files
					))
				}
			}
		}
		return result
	}

	/// SwiftPM's c99name: characters not valid in a Swift identifier become `_`,
	/// and a leading digit gets a `_` prefix.
	static func moduleName(forTarget target: String) -> String {
		var scalars = String.UnicodeScalarView()
		for scalar in target.unicodeScalars {
			scalars.append(scalar == "_" || scalar.properties.isXIDContinue ? scalar : "_")
		}
		if let first = scalars.first, first.properties.numericType != nil || !(first == "_" || first.properties.isXIDStart) {
			scalars.insert("_", at: scalars.startIndex)
		}
		return String(scalars)
	}

	private static func isDirectory(_ url: URL, _ fileManager: FileManager) -> Bool {
		var isDirectory: ObjCBool = false
		return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
	}

	private static func swiftFiles(in directory: URL, _ fileManager: FileManager) -> [URL] {
		guard let enumerator = fileManager.enumerator(
			at: directory,
			includingPropertiesForKeys: [.isRegularFileKey],
			options: [.skipsHiddenFiles]
		) else {
			return []
		}
		var files: [URL] = []
		for case let url as URL in enumerator where url.pathExtension == "swift" {
			guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
				continue
			}
			files.append(url.standardizedFileURL.resolvingSymlinksInPath())
		}
		return files
	}
}
