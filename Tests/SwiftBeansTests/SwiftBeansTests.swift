import Testing
@testable import SwiftBeans

@Test
func beanScopeRawValuesAreStable() {
	#expect(BeanScope.singleton.rawValue == "singleton")
	#expect(BeanScope.transient.rawValue == "transient")
}
