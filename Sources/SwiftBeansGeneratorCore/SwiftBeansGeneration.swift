import Foundation

/// One Swift file to scan, with where it came from.
package struct SourceFile: Sendable, Equatable {
	package enum Origin: Sendable, Equatable {
		/// A source of the target the plugin is applied to.
		case target
		/// A source of a `.swiftbeans.yml` local package target, compiled as `module`.
		case localPackage(module: String)
	}

	package var path: String
	package var text: String
	package var origin: Origin

	package init(path: String, text: String, origin: Origin = .target) {
		self.path = path
		self.text = text
		self.origin = origin
	}
}

/// 1-based position in a scanned file.
package struct SourcePosition: Sendable, Hashable, Comparable, CustomStringConvertible {
	package var file: String
	package var line: Int
	package var column: Int

	package init(file: String, line: Int, column: Int) {
		self.file = file
		self.line = line
		self.column = column
	}

	package static func < (lhs: SourcePosition, rhs: SourcePosition) -> Bool {
		(lhs.file, lhs.line, lhs.column) < (rhs.file, rhs.line, rhs.column)
	}

	/// `file:line:column`
	package var description: String { "\(file):\(line):\(column)" }
}

/// A located generator error, warning or note.
package struct GeneratorDiagnostic: Sendable, Equatable {
	package enum Severity: String, Sendable {
		case error
		case warning
		case note
	}

	package var severity: Severity
	/// Stable identifier, e.g. `graph.missingDependency`.
	package var id: String
	package var location: SourcePosition
	package var message: String
	/// Related locations (severity `.note`).
	package var notes: [GeneratorDiagnostic]

	package init(
		severity: Severity = .error,
		id: String,
		location: SourcePosition,
		message: String,
		notes: [GeneratorDiagnostic] = []
	) {
		self.severity = severity
		self.id = id
		self.location = location
		self.message = message
		self.notes = notes
	}

	/// `<file>:<line>:<column>: error: <message>`, then one line per note.
	package var rendered: String {
		([self] + notes)
			.map { "\($0.location): \($0.severity.rawValue): \($0.message)" }
			.joined(separator: "\n")
	}
}

package struct GenerationResult: Sendable, Equatable {
	/// Sorted by location, then message.
	package var diagnostics: [GeneratorDiagnostic]
	/// Generated Swift source; `nil` when `diagnostics` contains an error.
	package var output: String?
	/// `SwiftBeansGraph.md` contents; `nil` whenever `output` is.
	package var graphMarkdown: String?
	/// `SwiftBeansGraph.dot` contents; `nil` whenever `output` is.
	package var graphDot: String?

	package init(
		diagnostics: [GeneratorDiagnostic],
		output: String?,
		graphMarkdown: String? = nil,
		graphDot: String? = nil
	) {
		self.diagnostics = diagnostics
		self.output = output
		self.graphMarkdown = graphMarkdown
		self.graphDot = graphDot
	}

	package var errors: [GeneratorDiagnostic] {
		diagnostics.filter { $0.severity == .error }
	}
}

package enum SwiftBeansGeneration {
	/// Re-resolves the scan set from disk, then runs `generate(input:)`.
	///
	/// Reads `<scanRoot>/<configFileName>` when it exists and walks each listed local package target's
	/// `Sources/<target>/` folder, so files and config added since the plugin planned the build are included.
	/// A config problem is reported as an error at the config file (and line), and nothing is generated.
	package static func generate(request: GeneratorRequest, fileManager: FileManager = .default) -> GenerationResult {
		let scanRoot = URL(filePath: request.scanRoot, directoryHint: .isDirectory)
		let configURL = scanRoot.appending(path: request.configFileName)
		var packages: [LocalPackageTargetSources] = []
		if fileManager.fileExists(atPath: configURL.path) {
			do {
				let configuration = try ScanConfigurationParser.load(contentsOf: configURL)
				packages = try ScanSetResolver.localPackageSources(
					for: configuration,
					configDirectory: scanRoot,
					fileManager: fileManager
				)
			} catch {
				return GenerationResult(
					diagnostics: [GeneratorDiagnostic(
						id: "config.invalid",
						location: SourcePosition(file: configURL.path, line: error.line ?? 1, column: 1),
						message: error.message
					)],
					output: nil
				)
			}
		}
		let input = GeneratorInput(
			targetSources: request.targetSources,
			localPackages: packages.map { .init(module: $0.module, sources: $0.files.map(\.path)) }
		)
		return generate(input: input, fileManager: fileManager)
	}

	/// Reads every file in `input`, then runs `generate(sources:)`.
	///
	/// Paths are de-duplicated after resolving symlinks; a file listed as both a target source and a
	/// package source counts as a target source.
	package static func generate(input: GeneratorInput, fileManager: FileManager = .default) -> GenerationResult {
		var origins: [(path: String, origin: SourceFile.Origin)] = input.targetSources.map { ($0, .target) }
		for package in input.localPackages {
			origins += package.sources.map { ($0, .localPackage(module: package.module)) }
		}
		var seen = Set<String>()
		var sources: [SourceFile] = []
		var diagnostics: [GeneratorDiagnostic] = []
		for (path, origin) in origins {
			let resolved = URL(filePath: path).standardizedFileURL.resolvingSymlinksInPath().path
			guard seen.insert(resolved).inserted else { continue }
			guard let data = fileManager.contents(atPath: resolved), let text = String(data: data, encoding: .utf8) else {
				diagnostics.append(GeneratorDiagnostic(
					id: "input.unreadable",
					location: SourcePosition(file: resolved, line: 1, column: 1),
					message: "cannot read Swift source"
				))
				continue
			}
			sources.append(SourceFile(path: resolved, text: text, origin: origin))
		}
		guard diagnostics.isEmpty else {
			return GenerationResult(diagnostics: diagnostics, output: nil)
		}
		return generate(sources: sources)
	}

	/// Scans, validates and generates from in-memory files.
	package static func generate(sources: [SourceFile], onParse: ((SourceFile) -> Void)? = nil) -> GenerationResult {
		let files = sources
			.sorted { $0.path < $1.path }
			.map { source in
				onParse?(source)
				return DeclarationScanner.scan(source)
			}

		var diagnostics: [GeneratorDiagnostic] = []
		let contexts = files.filter { $0.source.origin == .target }.flatMap(\.contexts)
		if contexts.count > 1 {
			let names = contexts.map { "'\($0.name)'" }.joined(separator: ", ")
			for context in contexts {
				diagnostics.append(GeneratorDiagnostic(
					id: "context.multiple",
					location: context.location,
					message: "only one @ApplicationContext is allowed per target; found \(names)"
				))
			}
		}

		let (providers, resolverDiagnostics) = ProviderResolver.resolve(files)
		diagnostics += resolverDiagnostics
		diagnostics += DirectCallAnalyzer.analyze(files)
		if files.contains(where: \.hasContextFeatures) {
			return ContextGraph.generate(files: files, providers: providers, initialDiagnostics: diagnostics)
		}
		// A target without a root context (e.g. a feature module) generates nothing to validate.
		if contexts.count == 1 {
			diagnostics += GraphValidator.validate(providers)
		}

		diagnostics = diagnostics
			.map { diagnostic in
				var diagnostic = diagnostic
				diagnostic.notes.sort { ($0.location, $0.message) < ($1.location, $1.message) }
				return diagnostic
			}
			.sorted { ($0.location, $0.message) < ($1.location, $1.message) }
		guard !diagnostics.contains(where: { $0.severity == .error }) else {
			return GenerationResult(diagnostics: diagnostics, output: nil)
		}

		var imports = files.flatMap(\.imports)
		for provider in providers {
			if case .localPackage(let module) = provider.origin {
				imports.append(ImportRecord(module: module, testable: false, preconcurrency: false, condition: nil))
			}
		}
		let output = CodeGenerator.generate(
			context: contexts.count == 1 ? contexts[0] : nil,
			providers: providers,
			imports: imports
		)
		return GenerationResult(
			diagnostics: diagnostics,
			output: output,
			graphMarkdown: GraphDump.markdown(context: contexts.count == 1 ? contexts[0] : nil, providers: providers),
			graphDot: GraphDump.dot(providers: providers)
		)
	}
}

/// Writes generated output only when it changes, so unchanged wiring does not trigger recompiles.
package enum GeneratedFileWriter {
	/// - Returns: `true` if the file was written, `false` if it already had these contents.
	@discardableResult
	package static func write(_ contents: String, to url: URL) throws -> Bool {
		let data = Data(contents.utf8)
		if let existing = try? Data(contentsOf: url), existing == data {
			return false
		}
		try data.write(to: url, options: .atomic)
		return true
	}
}
