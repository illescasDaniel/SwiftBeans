import Foundation
import Testing
@testable import SwiftBeans

@Test
func beanScopeRawValuesAreStable() {
	#expect(BeanScope.singleton.rawValue == "singleton")
	#expect(BeanScope.transient.rawValue == "transient")
}

@Test
func scanConfigurationDecodesSnakeCaseKeys() throws {
	let json = """
		{
			"local_packages": [
				{
					"path": "Packages/Networking",
					"targets": ["Networking"]
				}
			]
		}
		"""
	let data = Data(json.utf8)
	let config = try JSONDecoder().decode(SwiftBeansScanConfiguration.self, from: data)
	#expect(config.localPackages.count == 1)
	#expect(config.localPackages[0].path == "Packages/Networking")
	#expect(config.localPackages[0].targets == ["Networking"])
}
