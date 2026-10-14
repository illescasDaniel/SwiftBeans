import SwiftBeans
import SwiftBeansGeneratorCore
import Testing

@Suite("BeanSourceParser — SPEC compile-time-di")
struct BeanSourceParserTests {
	@Test
	func `Given annotated sources When parsed Then yields providers`() throws {
		let sources = [
			"""
			@Configuration
			enum AppConfiguration {
				@Bean
				static func urlSession() -> URLSession { URLSession.shared }
			}

			@Service
			final class UserService {
				init(urlSession: URLSession) {}
			}

			@ApplicationContext
			final class AppContext {}
			""",
		]
		let providers = try BeanSourceParser.parseProviders(fromSources: sources)
		#expect(providers.count == 2)
		#expect(providers.contains { $0.key.typeName == "URLSession" })
		#expect(providers.contains { $0.key.typeName == "UserService" })

		let graph = try BeanSourceParser.buildGraph(fromSources: sources)
		#expect(graph.contextTypeName == "AppContext")
		#expect(graph.provider(for: InjectableKey(typeName: "UserService")) != nil)
	}

	@Test
	func `Given service from another source When parsed Then joins the graph`() throws {
		let sources = [
			"""
			@Service
			final class FromPackage {
				init() {}
			}

			@ApplicationContext
			final class AppContext {}
			""",
		]
		let graph = try BeanSourceParser.buildGraph(fromSources: sources)
		#expect(graph.provider(for: InjectableKey(typeName: "FromPackage")) != nil)
	}

	@Test
	func `Given boundTo service When parsed Then key is protocol`() throws {
		let sources = [
			"""
			@Service(boundTo: APIClient.self)
			final class DefaultAPIClient: APIClient {
				init() {}
			}

			@ApplicationContext
			final class AppContext {}
			""",
		]
		let providers = try BeanSourceParser.parseProviders(fromSources: sources)
		#expect(providers.count == 1)
		#expect(providers[0].key.typeName == "APIClient")
		#expect(providers[0].sourceName == "DefaultAPIClient")
	}
}
