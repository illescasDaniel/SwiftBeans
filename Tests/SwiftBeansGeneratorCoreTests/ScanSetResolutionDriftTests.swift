import Foundation
import Testing

/// Build tool plugins cannot link library targets, so the plugin compiles its own copy of
/// `ScanSetResolution.swift`. Only the GeneratorCore copy is unit-tested; this keeps them identical.
@Suite("ScanSetResolution plugin copy")
struct ScanSetResolutionDriftTests {
	@Test
	func `Given the plugin copy When compared to the canonical source Then they are byte identical`() throws {
		let packageRoot = URL(filePath: #filePath)
			.deletingLastPathComponent() // SwiftBeansGeneratorCoreTests
			.deletingLastPathComponent() // Tests
			.deletingLastPathComponent()
		let canonical = packageRoot.appending(path: "Sources/SwiftBeansGeneratorCore/ScanSetResolution.swift")
		let pluginCopy = packageRoot.appending(path: "Plugins/SwiftBeansPlugin/ScanSetResolution.swift")

		let canonicalData = try Data(contentsOf: canonical)
		let pluginData = try Data(contentsOf: pluginCopy)

		#expect(
			canonicalData == pluginData,
			"Plugins/SwiftBeansPlugin/ScanSetResolution.swift differs from the canonical copy; copy the GeneratorCore file over it."
		)
	}
}
