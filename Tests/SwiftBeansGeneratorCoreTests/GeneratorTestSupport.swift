import Testing
@testable import SwiftBeansGeneratorCore

/// `@ApplicationContext final class AppContext {}` in `/App/AppContext.swift`.
let appContextFile = SourceFile(
	path: "/App/AppContext.swift",
	text: """
		@ApplicationContext
		final class AppContext {}
		"""
)

/// A target source at `path`.
func appFile(_ path: String, _ text: String) -> SourceFile {
	SourceFile(path: path, text: text, origin: .target)
}

/// A local package source compiled as `module`.
func packageFile(_ module: String, _ path: String, _ text: String) -> SourceFile {
	SourceFile(path: path, text: text, origin: .localPackage(module: module))
}

/// Runs the generator on `files` plus `appContextFile`.
func generateWithContext(_ files: SourceFile...) -> GenerationResult {
	SwiftBeansGeneration.generate(sources: [appContextFile] + files)
}

extension GenerationResult {
	/// `"<id> <file>:<line>:<column>"` for every error, in reported order.
	var errorSummary: [String] {
		errors.map { "\($0.id) \($0.location)" }
	}

	/// Every rendered diagnostic, joined by newlines (for failure messages).
	var renderedDiagnostics: String {
		diagnostics.map(\.rendered).joined(separator: "\n")
	}
}

/// Expects a successful run whose output contains every fragment.
func expectOutput(
	_ result: GenerationResult,
	contains fragments: [String],
	sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
	#expect(result.errors.isEmpty, "unexpected errors:\n\(result.renderedDiagnostics)", sourceLocation: sourceLocation)
	guard let output = result.output else {
		Issue.record("no output", sourceLocation: sourceLocation)
		return
	}
	for fragment in fragments {
		#expect(output.contains(fragment), "missing \(fragment.debugDescription) in:\n\(output)", sourceLocation: sourceLocation)
	}
}

/// Expects a successful run whose output contains none of the fragments.
func expectOutput(
	_ result: GenerationResult,
	excludes fragments: [String],
	sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
	guard let output = result.output else {
		Issue.record("no output:\n\(result.renderedDiagnostics)", sourceLocation: sourceLocation)
		return
	}
	for fragment in fragments {
		#expect(!output.contains(fragment), "unexpected \(fragment.debugDescription) in:\n\(output)", sourceLocation: sourceLocation)
	}
}

/// Number of non-overlapping occurrences of `fragment` in `text`.
func occurrences(of fragment: String, in text: String) -> Int {
	text.components(separatedBy: fragment).count - 1
}
