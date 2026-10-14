import SwiftBeans
import SwiftBeansGeneratorCore
import Testing

@Suite("BeanGraphValidator — SPEC compile-time-di")
struct BeanGraphValidatorTests {
	@Test
	func `Given configuration bean and service When validated Then graph accepts providers`() throws {
		let providers = [
			BeanProvider(
				key: InjectableKey(typeName: "URLSession"),
				scope: .singleton,
				sourceName: "AppConfiguration.urlSession"
			),
			BeanProvider(
				key: InjectableKey(typeName: "UserService"),
				dependencies: [InjectableKey(typeName: "URLSession")],
				scope: .singleton,
				sourceName: "UserService"
			),
		]
		let graph = try BeanGraphValidator.validate(providers: providers)
		#expect(graph.provider(for: InjectableKey(typeName: "UserService")) != nil)
		#expect(graph.provider(for: InjectableKey(typeName: "URLSession"))?.scope == .singleton)
	}

	@Test
	func `Given service with constructor deps When validated Then all deps are present`() throws {
		let providers = [
			BeanProvider(key: InjectableKey(typeName: "APIClient"), sourceName: "DefaultAPIClient"),
			BeanProvider(key: InjectableKey(typeName: "UserService"), sourceName: "UserService"),
			BeanProvider(
				key: InjectableKey(typeName: "OrderService"),
				dependencies: [
					InjectableKey(typeName: "APIClient"),
					InjectableKey(typeName: "UserService"),
				],
				sourceName: "OrderService"
			),
		]
		let graph = try BeanGraphValidator.validate(providers: providers)
		#expect(graph.providers.count == 3)
	}

	@Test
	func `Given service bound to protocol When validated Then key is the protocol`() throws {
		let providers = [
			BeanProvider(
				key: InjectableKey(typeName: "APIClient"),
				sourceName: "DefaultAPIClient"
			),
			BeanProvider(
				key: InjectableKey(typeName: "UserService"),
				dependencies: [InjectableKey(typeName: "APIClient")],
				sourceName: "UserService"
			),
		]
		let graph = try BeanGraphValidator.validate(providers: providers)
		#expect(graph.provider(for: InjectableKey(typeName: "APIClient"))?.sourceName == "DefaultAPIClient")
	}

	@Test
	func `Given missing dependency When validated Then fails naming consumer and type`() {
		let providers = [
			BeanProvider(
				key: InjectableKey(typeName: "UserService"),
				dependencies: [InjectableKey(typeName: "Analytics")],
				sourceName: "UserService"
			),
		]
		#expect {
			try BeanGraphValidator.validate(providers: providers)
		} throws: { error in
			guard case BeanGraphError.missingDependency(let consumer, let missing) = error else {
				return false
			}
			return consumer == "UserService" && missing == "Analytics"
		}
	}

	@Test
	func `Given cyclic dependency When validated Then fails with cycle diagnostic`() {
		let providers = [
			BeanProvider(
				key: InjectableKey(typeName: "A"),
				dependencies: [InjectableKey(typeName: "B")],
				sourceName: "A"
			),
			BeanProvider(
				key: InjectableKey(typeName: "B"),
				dependencies: [InjectableKey(typeName: "A")],
				sourceName: "B"
			),
		]
		#expect {
			try BeanGraphValidator.validate(providers: providers)
		} throws: { error in
			guard case BeanGraphError.cycle(let nodes) = error else {
				return false
			}
			return nodes.contains("A") && nodes.contains("B")
		}
	}

	@Test
	func `Given duplicate providers When validated Then fails with duplicate diagnostic`() {
		let providers = [
			BeanProvider(key: InjectableKey(typeName: "Foo"), sourceName: "FooService"),
			BeanProvider(key: InjectableKey(typeName: "Foo"), sourceName: "FooBean"),
		]
		#expect {
			try BeanGraphValidator.validate(providers: providers)
		} throws: { error in
			guard case BeanGraphError.duplicateProvider(let typeName, let sources) = error else {
				return false
			}
			return typeName == "Foo" && sources.sorted() == ["FooBean", "FooService"]
		}
	}

	@Test
	func `Given transient and singleton scopes When validated Then scopes are preserved`() throws {
		let providers = [
			BeanProvider(
				key: InjectableKey(typeName: "Validator"),
				scope: .transient,
				sourceName: "AppConfiguration.validator"
			),
			BeanProvider(
				key: InjectableKey(typeName: "UserService"),
				scope: .singleton,
				sourceName: "UserService"
			),
		]
		let graph = try BeanGraphValidator.validate(providers: providers)
		#expect(graph.provider(for: InjectableKey(typeName: "Validator"))?.scope == .transient)
		#expect(graph.provider(for: InjectableKey(typeName: "UserService"))?.scope == .singleton)
	}
}
