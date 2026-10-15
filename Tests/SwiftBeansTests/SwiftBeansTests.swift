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

private final class Parser {
	let decoder: String
	let retries: Int

	init(@Qualifier("snakeCase") decoder: String, @SwiftBeans.Qualifier("retries") retries: Int = 3) {
		self.decoder = decoder
		self.retries = retries
	}
}

@Test
func qualifierParameterTakesAPlainValueAndTheBodySeesIt() {
	let parser = Parser(decoder: "snake")
	#expect(parser.decoder == "snake")
	#expect(parser.retries == 3)
	#expect(Parser(decoder: "x", retries: 1).retries == 1)
	#expect(Qualifier(wrappedValue: 7, "seven").wrappedValue == 7)
}

@Test
func assistedParameterTakesAPlainValueAndTheBodySeesIt() {
	let result: Int = doubled(21)
	#expect(result == 42)
	#expect(Assisted(wrappedValue: "x").wrappedValue == "x")
}
