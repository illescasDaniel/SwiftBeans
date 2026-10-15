import Testing
@testable import SwiftBeansGeneratorCore

/// Core SPEC scenarios (configuration beans, services, binding, scopes, context protocol)
/// through `SwiftBeansGeneration.generate(sources:)`.
@Suite("Generator — SPEC core scenarios")
struct GeneratorScenarioTests {
	@Test
	func `Given a configuration bean and a service needing it When generated Then the service receives the bean`() {
		let result = generateWithContext(appFile("/App/Wiring.swift", """
			@Configuration
			enum AppConfiguration {
				@Bean
				static func urlSession() -> URLSession { .shared }
			}

			@Service
			final class UserService {
				init(urlSession: URLSession) {}
			}
			"""))
		expectOutput(result, contains: [
			"var urlSession: URLSession {",
			"AppConfiguration.urlSession()",
			"var userService: UserService {",
			"_swiftBeansRegistry.singleton(key: \"userService\")",
			"UserService(urlSession: self.urlSession)",
		])
	}

	@Test
	func `Given a service with several constructor dependencies When generated Then all come from the graph`() {
		let result = generateWithContext(appFile("/App/Services.swift", """
			@Service
			final class APIClient {
				init() {}
			}

			@Service
			final class UserService {
				init() {}
			}

			@Service
			final class OrderService {
				init(api: APIClient, users: UserService) {}
			}
			"""))
		expectOutput(result, contains: ["OrderService(api: self.apiClient, users: self.userService)"])
	}

	@Test
	func `Given a protocol-bound service When generated Then dependents receive it as the protocol`() {
		let result = generateWithContext(appFile("/App/Services.swift", """
			@Service(boundTo: APIClient.self)
			final class DefaultAPIClient: APIClient {
				init() {}
			}

			@Service
			final class UserService {
				init(api: APIClient) {}
			}
			"""))
		expectOutput(result, contains: [
			"var apiClient: APIClient {",
			"DefaultAPIClient()",
			"UserService(api: self.apiClient)",
		])
	}

	@Test
	func `Given a transient bean When generated Then the accessor constructs without the registry`() {
		let result = generateWithContext(appFile("/App/Configuration.swift", """
			@Configuration
			enum AppConfiguration {
				@Bean(scope: .transient)
				static func validator() -> Validator { Validator() }
			}
			"""))
		expectOutput(result, contains: ["var validator: Validator {", "AppConfiguration.validator()"])
		expectOutput(result, excludes: ["singleton(key: \"validator\")"])
	}

	@Test
	func `Given an unlabeled initializer parameter When generated Then the argument has no label`() {
		let result = generateWithContext(appFile("/App/Services.swift", """
			@Service
			final class APIClient {
				init() {}
			}

			@Service
			final class UserService {
				init(_ api: APIClient) {}
			}
			"""))
		expectOutput(result, contains: ["UserService(self.apiClient)"])
	}

	@Test
	func `Given AppContext When generated Then AppContextProtocol lists every accessor and AppContext conforms`() {
		let result = generateWithContext(appFile("/App/Wiring.swift", """
			@Service
			final class UserService {
				init() {}
			}

			@Configuration
			enum AppConfiguration {
				@Bean
				static func httpClient() -> any HTTPClient { fatalError() }
			}
			"""))
		expectOutput(result, contains: [
			"protocol AppContextProtocol: AnyObject {",
			"var httpClient: any HTTPClient { get }",
			"var userService: UserService { get }",
			"extension AppContext {",
			"extension AppContext: AppContextProtocol {}",
		])
	}

	@Test
	func `Given providers declared in any order When generated Then accessors are sorted by name`() throws {
		let result = generateWithContext(appFile("/App/Services.swift", """
			@Service
			final class Zebra {
				init() {}
			}

			@Service
			final class Apple {
				init() {}
			}
			"""))
		let output = try #require(result.output)
		let apple = try #require(output.range(of: "var apple: Apple {"))
		let zebra = try #require(output.range(of: "var zebra: Zebra {"))
		#expect(apple.lowerBound < zebra.lowerBound)
	}
}
