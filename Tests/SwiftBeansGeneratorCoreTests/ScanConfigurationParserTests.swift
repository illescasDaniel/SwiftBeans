import Foundation
import Testing
@testable import SwiftBeansGeneratorCore

@Suite("ScanConfigurationParser — SPEC Source discovery")
struct ScanConfigurationParserTests {
	@Test
	func `Given block lists When parsed Then packages targets and entry lines are read`() throws {
		let yaml = """
			# .swiftbeans.yml
			local_packages:
			  - path: Packages/Networking
			    targets:
			      - Networking
			      - NetworkingModels
			  - path: Packages/FeatureHome
			    targets:
			      - FeatureHome
			"""
		let config = try ScanConfigurationParser.parse(yaml)
		#expect(config == SwiftBeansScanConfiguration(localPackages: [
			.init(path: "Packages/Networking", targets: ["Networking", "NetworkingModels"], line: 3),
			.init(path: "Packages/FeatureHome", targets: ["FeatureHome"], line: 7),
		]))
	}

	@Test
	func `Given quoted values When parsed Then quotes are stripped`() throws {
		let yaml = """
			local_packages:
			  - path: "Packages/Networking"
			    targets:
			      - 'Networking'
			      - "Models"
			"""
		let config = try ScanConfigurationParser.parse(yaml)
		#expect(config.localPackages.map(\.path) == ["Packages/Networking"])
		#expect(config.localPackages.map(\.targets) == [["Networking", "Models"]])
	}

	@Test
	func `Given comments When parsed Then comments are ignored but hash inside quotes is kept`() throws {
		let yaml = """
			# leading comment
			local_packages: # trailing comment
			  # comment between entries
			  - path: "Packages/C#Interop" # trailing comment
			    targets:
			      - Interop # trailing comment
			"""
		let config = try ScanConfigurationParser.parse(yaml)
		#expect(config.localPackages.map(\.path) == ["Packages/C#Interop"])
		#expect(config.localPackages.map(\.targets) == [["Interop"]])
	}

	@Test
	func `Given CRLF line endings When parsed Then values have no trailing carriage return`() throws {
		let yaml = "local_packages:\r\n  - path: Packages/Net\r\n    targets:\r\n      - Net\r\n"
		let config = try ScanConfigurationParser.parse(yaml)
		#expect(config.localPackages.map(\.path) == ["Packages/Net"])
		#expect(config.localPackages.map(\.targets) == [["Net"]])
	}

	@Test(arguments: [
		"",
		"# only a comment\n",
		"local_packages: []\n",
		"local_packages:\n",
	])
	func `Given empty configuration When parsed Then there are no local packages`(yaml: String) throws {
		let config = try ScanConfigurationParser.parse(yaml)
		#expect(config.localPackages.isEmpty)
	}

	@Test
	func `Given a file that is not UTF-8 When loaded Then fails as unreadable`() throws {
		let file = FileManager.default.temporaryDirectory
			.appending(path: "swiftbeans-\(UUID().uuidString).yml")
		try Data([0xFF, 0xFE, 0x00]).write(to: file)
		defer { try? FileManager.default.removeItem(at: file) }

		let error = #expect(throws: ScanConfigurationError.self) {
			try ScanConfigurationParser.load(contentsOf: file)
		}
		#expect(error?.kind == .unreadable)
	}

	@Test(arguments: [
		// Inline list is outside the documented schema.
		("local_packages:\n  - path: Packages/Net\n    targets: [Net]\n", 3),
		// Unknown top-level key.
		("local_packages: []\nexclude:\n  - Foo\n", 2),
		// Unknown key inside an entry.
		("local_packages:\n  - path: Packages/Net\n    product: Net\n", 3),
		// Entry that does not start with `path`.
		("local_packages:\n  - targets:\n      - Net\n", 2),
		// Entry without targets.
		("local_packages:\n  - path: Packages/Net\n", 2),
		// Empty path.
		("local_packages:\n  - path:\n    targets:\n      - Net\n", 2),
		// Unterminated quote.
		("local_packages:\n  - path: \"Packages/Net\n    targets:\n      - Net\n", 2),
	])
	func `Given yaml outside the schema When parsed Then fails with a syntax error on the offending line`(
		yaml: String,
		expectedLine: Int
	) {
		let error = #expect(throws: ScanConfigurationError.self) {
			try ScanConfigurationParser.parse(yaml)
		}
		#expect(error?.kind == .syntax)
		#expect(error?.line == expectedLine)
	}
}
