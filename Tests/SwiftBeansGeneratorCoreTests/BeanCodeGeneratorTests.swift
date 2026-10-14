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
	func `Given AppContext When generated Then emits AppContextProtocol and conformance`() throws {
		let graph = try BeanGraphValidator.validate(
			providers: [
				BeanProvider(
					key: InjectableKey(typeName: "UserService"),
					scope: .singleton,
					sourceName: "UserService",
					factory: .service(typeName: "UserService", parameters: [])
				),
				BeanProvider(
					key: InjectableKey(typeName: "any HTTPClient"),
					scope: .singleton,
					sourceName: "AppConfiguration.httpClient",
					factory: .bean(
						configurationType: "AppConfiguration",
						methodName: "httpClient",
						parameters: []
					)
				),
			],
			contextTypeName: "AppContext"
		)
		let code = try BeanCodeGenerator.generate(graph: graph)
		#expect(code.contains("protocol AppContextProtocol: AnyObject {"))
		#expect(code.contains("var userService: UserService { get }"))
		#expect(code.contains("var httpClient: any HTTPClient { get }"))
		#expect(code.contains("extension AppContext: AppContextProtocol {}"))
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

	@Test
	func `Given protocol-bound service When generated Then accessor returns protocol type`() throws {
		let graph = try BeanGraphValidator.validate(
			providers: [
				BeanProvider(
					key: InjectableKey(typeName: "ItemRepository"),
					scope: .singleton,
					sourceName: "FakeItemRepository",
					factory: .service(typeName: "FakeItemRepository", parameters: [])
				),
			],
			contextTypeName: "AppContext"
		)
		let code = try BeanCodeGenerator.generate(graph: graph)
		#expect(code.contains("var itemRepository: ItemRepository"))
		#expect(code.contains("FakeItemRepository()"))
		#expect(code.contains("singleton(key: \"ItemRepository\")"))
	}

	@Test
	func `Given configuration bean When generated Then calls static factory`() throws {
		let graph = try BeanGraphValidator.validate(
			providers: [
				BeanProvider(
					key: InjectableKey(typeName: "AppClock"),
					scope: .singleton,
					sourceName: "AppConfiguration.appClock",
					factory: .bean(
						configurationType: "AppConfiguration",
						methodName: "appClock",
						parameters: []
					)
				),
			],
			contextTypeName: "AppContext"
		)
		let code = try BeanCodeGenerator.generate(graph: graph)
		#expect(code.contains("var appClock: AppClock"))
		#expect(code.contains("AppConfiguration.appClock()"))
	}

	@Test
	func `Given any Protocol bean When generated Then accessor strips existential prefix`() throws {
		let graph = try BeanGraphValidator.validate(
			providers: [
				BeanProvider(
					key: InjectableKey(typeName: "any HTTPDataRequestHandler"),
					scope: .singleton,
					sourceName: "AppConfiguration.httpDataRequestHandler",
					factory: .bean(
						configurationType: "AppConfiguration",
						methodName: "httpDataRequestHandler",
						parameters: []
					)
				),
				BeanProvider(
					key: InjectableKey(typeName: "any HTTPClient"),
					dependencies: [InjectableKey(typeName: "any HTTPDataRequestHandler")],
					scope: .singleton,
					sourceName: "AppConfiguration.httpClient",
					factory: .bean(
						configurationType: "AppConfiguration",
						methodName: "httpClient",
						parameters: [
							BeanParameter(label: "httpDataRequestHandler", typeName: "any HTTPDataRequestHandler"),
						]
					)
				),
			],
			contextTypeName: "AppContext"
		)
		let code = try BeanCodeGenerator.generate(graph: graph, additionalImports: ["HTTIES"])
		#expect(code.contains("import HTTIES"))
		#expect(code.contains("var httpClient: any HTTPClient"))
		#expect(code.contains("var httpDataRequestHandler: any HTTPDataRequestHandler"))
		#expect(code.contains("httpDataRequestHandler: self.httpDataRequestHandler"))
		#expect(!code.contains("var any "))
		#expect(code.contains("protocol AppContextProtocol: AnyObject {"))
		#expect(code.contains("var httpClient: any HTTPClient { get }"))
		#expect(code.contains("var httpDataRequestHandler: any HTTPDataRequestHandler { get }"))
		#expect(code.contains("extension AppContext: AppContextProtocol {}"))
	}
}
