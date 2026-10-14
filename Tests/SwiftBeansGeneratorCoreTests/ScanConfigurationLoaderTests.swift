import Foundation
import SwiftBeansGeneratorCore
import Testing

@Suite("ScanConfigurationLoader")
struct ScanConfigurationLoaderTests {
	@Test
	func `Given yaml text When decoded Then local packages parse`() throws {
		let yaml = """
			local_packages:
			  - path: Packages/Networking
			    targets:
			      - Networking
			      - NetworkingTestsSkip
			"""
		let config = try ScanConfigurationLoader.decodeYAML(Data(yaml.utf8))
		#expect(config.localPackages.count == 1)
		#expect(config.localPackages[0].path == "Packages/Networking")
		#expect(config.localPackages[0].targets == ["Networking", "NetworkingTestsSkip"])
	}
}
