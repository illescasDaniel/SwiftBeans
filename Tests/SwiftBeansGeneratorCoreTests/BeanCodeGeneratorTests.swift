import SwiftBeans
import SwiftBeansGeneratorCore
import Testing

@Suite("BeanCodeGenerator")
struct BeanCodeGeneratorTests {
	@Test
	func `Given singleton service When generated Then uses registry`() throws {
		let graph = try BeanGraphValidator.validate(
			providers: [
				BeanProvider(
					key: InjectableKey(typeName: "UserService"),
					scope: .singleton,
					sourceName: "UserService",
					factory: .service(typeName: "UserService", parameters: [])
				),
			],
			contextTypeName: "AppContext"
		)
		let code = try BeanCodeGenerator.generate(graph: graph)
		#expect(code.contains("import Foundation"))
		#expect(code.contains("extension AppContext"))
		#expect(code.contains("var userService: UserService"))
		#expect(code.contains("_swiftBeansRegistry.singleton(key: \"UserService\")"))
		#expect(code.contains("UserService()"))
	}

	@Test
	func `Given transient bean When generated Then constructs each time`() throws {
		let graph = try BeanGraphValidator.validate(
			providers: [
				BeanProvider(
					key: InjectableKey(typeName: "Validator"),
					scope: .transient,
					sourceName: "AppConfiguration.validator",
					factory: .bean(
						configurationType: "AppConfiguration",
						methodName: "validator",
						parameters: []
					)
				),
			],
			contextTypeName: "AppContext"
		)
		let code = try BeanCodeGenerator.generate(graph: graph)
		#expect(code.contains("var validator: Validator"))
		#expect(!code.contains("singleton(key: \"Validator\")"))
		#expect(code.contains("AppConfiguration.validator()"))
	}

	@Test
	func `Given bean with dependency When generated Then passes accessor`() throws {
		let graph = try BeanGraphValidator.validate(
			providers: [
				BeanProvider(
					key: InjectableKey(typeName: "URLSession"),
					sourceName: "AppConfiguration.urlSession",
					factory: .bean(
						configurationType: "AppConfiguration",
						methodName: "urlSession",
						parameters: []
					)
				),
				BeanProvider(
					key: InjectableKey(typeName: "UserService"),
					dependencies: [InjectableKey(typeName: "URLSession")],
					sourceName: "UserService",
					factory: .service(
						typeName: "UserService",
						parameters: [BeanParameter(label: "urlSession", typeName: "URLSession")]
					)
				),
			],
			contextTypeName: "AppContext"
		)
		let code = try BeanCodeGenerator.generate(graph: graph)
		#expect(code.contains("UserService(urlSession: self.urlSession)"))
		#expect(code.contains("var urlSession: URLSession"))
	}
}
