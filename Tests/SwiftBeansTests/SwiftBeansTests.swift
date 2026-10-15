import Testing
@testable import SwiftBeans

@Test
func beanScopeRawValuesAreStable() {
	#expect(BeanScope.singleton.rawValue == "singleton")
	#expect(BeanScope.transient.rawValue == "transient")
}

private func doubled(@Assisted _ value: Int) -> Int {
	value * 2
}

@Test
func assistedParameterTakesAPlainValueAndTheBodySeesIt() {
	let result: Int = doubled(21)
	#expect(result == 42)
	#expect(Assisted(wrappedValue: "x").wrappedValue == "x")
}
