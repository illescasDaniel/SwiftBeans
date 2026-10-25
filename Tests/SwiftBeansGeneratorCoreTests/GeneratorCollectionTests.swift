import Testing
@testable import SwiftBeansGeneratorCore

private let trackerProtocolFile = appFile("/App/AnalyticsTracker.swift", """
	protocol AnalyticsTracker {
		func track(_ event: String)
	}
	""")

private let analyticsFile = appFile("/App/Analytics.swift", """
	@Service
	final class Analytics {
		init(trackers: [any AnalyticsTracker]) {}
	}
	""")

@Suite("Generator — SPEC collection-injection")
struct GeneratorCollectionTests {
	// MARK: - Members

	@Test
	func `Given two conforming services When a consumer injects the any collection Then it gets both in accessor-name order`() throws {
		let result = generateWithContext(trackerProtocolFile, analyticsFile, appFile("/App/Trackers.swift", """
			@Service
			final class FirebaseTracker: AnalyticsTracker {
				init() {}
			}

			@Service
			final class ConsoleTracker: AnalyticsTracker {
				init() {}
			}
			"""))
		expectOutput(result, contains: ["Analytics(trackers: [self.consoleTracker, self.firebaseTracker])"])
		let output = try #require(result.output)
		#expect(!output.contains("analyticsTrackerArray"), "no aggregate accessor:\n\(output)")
	}

	@Test
	func `Given protocol-bound, concrete and bean members When a plain collection is injected Then all are listed by accessor name`() {
		let result = generateWithContext(trackerProtocolFile, appFile("/App/Trackers.swift", """
			@Service(boundTo: AnalyticsTracker.self)
			final class RemoteTracker {
				init() {}
			}

			@Service
			final class ConsoleTracker: AnalyticsTracker {
				init() {}
			}

			struct FileTracker: AnalyticsTracker {}

			@Configuration
			enum TrackingConfiguration {
				@Bean
				static func fileTracker() -> FileTracker { FileTracker() }
			}

			@Service
			final class Dashboard {
				init(trackers: [AnalyticsTracker]) {}
			}
			"""))
		expectOutput(result, contains: [
			"Dashboard(trackers: [self.analyticsTracker, self.consoleTracker, self.fileTracker])",
		])
	}

	@Test
	func `Given conformance in an extension or through a superclass When the collection is injected Then both types are members`() {
		let result = generateWithContext(trackerProtocolFile, analyticsFile, appFile("/App/Trackers.swift", """
			@Service
			final class AlphaTracker {
				init() {}
			}

			class BaseTracker: AnalyticsTracker {}

			@Service
			final class CrashTracker: BaseTracker {
				override init() {}
			}
			"""), appFile("/App/AlphaTracker+Analytics.swift", """
			extension AlphaTracker: AnalyticsTracker {}
			"""))
		expectOutput(result, contains: ["Analytics(trackers: [self.alphaTracker, self.crashTracker])"])
	}

	@Test
	func `Given a bean bound to a sub-protocol When the parent collection is injected Then it is a member`() {
		let result = generateWithContext(trackerProtocolFile, analyticsFile, appFile("/App/Special.swift", """
			protocol SpecialTracker: AnalyticsTracker {}

			@Configuration
			enum TrackingConfiguration {
				@Bean
				static func special() -> any SpecialTracker { fatalError() }
			}
			"""))
		expectOutput(result, contains: ["Analytics(trackers: [self.specialTracker])"])
	}

	@Test
	func `Given a service bound to another protocol When its type also conforms to the element Then it is not a member`() {
		let result = generateWithContext(trackerProtocolFile, analyticsFile, appFile("/App/Bound.swift", """
			protocol Logger {}

			@Service(boundTo: Logger.self)
			final class LoggingTracker: AnalyticsTracker, Logger {
				init() {}
			}
			"""))
		expectOutput(result, contains: ["Analytics(trackers: [])"])
	}

	// MARK: - Empty and missing

	@Test
	func `Given no members When an any collection is injected Then it receives an empty array`() {
		let result = generateWithContext(trackerProtocolFile, analyticsFile)
		expectOutput(result, contains: ["Analytics(trackers: [])"])
	}

	@Test
	func `Given no members When an Array of any is injected Then it receives an empty array`() {
		let result = generateWithContext(trackerProtocolFile, appFile("/App/Analytics.swift", """
			@Service
			final class Analytics {
				init(trackers: Array<(any AnalyticsTracker)>) {}
			}
			"""))
		expectOutput(result, contains: ["Analytics(trackers: [])"])
	}

	@Test
	func `Given no provider When a plain value collection is injected Then the dependency is missing`() throws {
		let result = generateWithContext(appFile("/App/Tags.swift", """
			@Service
			final class TagList {
				init(tags: [String]) {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errorSummary == ["graph.missingDependency /App/Tags.swift:3:7"])
		let message = try #require(result.errors.first?.message)
		#expect(message.contains("'[String]'"), "\(message)")
	}

	@Test
	func `Given no members When a plain protocol collection is injected Then the dependency is missing`() {
		let result = generateWithContext(trackerProtocolFile, appFile("/App/Analytics.swift", """
			@Service
			final class Analytics {
				init(trackers: [AnalyticsTracker]) {}
			}
			"""))
		#expect(result.errorSummary == ["graph.missingDependency /App/Analytics.swift:3:7"])
	}

	// MARK: - Array beans

	@Test
	func `Given an explicit array bean and a member When the collection is injected Then the array bean wins`() throws {
		let result = generateWithContext(trackerProtocolFile, analyticsFile, appFile("/App/Trackers.swift", """
			@Service
			final class ConsoleTracker: AnalyticsTracker {
				init() {}
			}

			@Configuration
			enum TrackingConfiguration {
				@Bean
				static func trackers() -> [any AnalyticsTracker] { [] }
			}
			"""))
		expectOutput(result, contains: [
			"Analytics(trackers: self.analyticsTrackerArray)",
			"\tvar analyticsTrackerArray: [any AnalyticsTracker] { get }\n",
		])
		expectOutput(result, excludes: ["[self.consoleTracker]"])
	}

	@Test
	func `Given a value bean of collection type When injected Then it is wired as a single provider`() {
		let result = generateWithContext(appFile("/App/Tags.swift", """
			@Configuration
			enum TagConfiguration {
				@Bean
				static func tags() -> [String] { [] }

				@Bean
				static func greeting() -> String { "" }
			}

			@Service
			final class TagList {
				init(tags: [String]) {}
			}
			"""))
		expectOutput(result, contains: ["TagList(tags: self.stringArray)"])
	}

	@Test
	func `Given no array bean and a provider of the element When a plain collection is injected Then it gets that provider`() {
		let result = generateWithContext(appFile("/App/Tags.swift", """
			@Configuration
			enum TagConfiguration {
				@Bean
				static func greeting() -> String { "" }
			}

			@Service
			final class TagList {
				init(tags: [String]) {}
			}
			"""))
		expectOutput(result, contains: ["TagList(tags: [self.string])"])
	}

	// MARK: - Exclusions

	@Test
	func `Given an assisted conforming service When the collection is injected Then it is excluded`() {
		let result = generateWithContext(trackerProtocolFile, analyticsFile, appFile("/App/Trackers.swift", """
			@Service
			final class ConsoleTracker: AnalyticsTracker {
				init() {}
			}

			@Service
			final class SessionTracker: AnalyticsTracker {
				init(@Assisted session: Session) {}
			}
			"""))
		expectOutput(result, contains: ["Analytics(trackers: [self.consoleTracker])"])
	}

	@Test
	func `Given only an assisted member When a plain collection is injected Then the dependency is missing`() {
		let result = generateWithContext(trackerProtocolFile, appFile("/App/Trackers.swift", """
			@Service
			final class SessionTracker: AnalyticsTracker {
				init(@Assisted session: Session) {}
			}

			@Service
			final class Analytics {
				init(trackers: [AnalyticsTracker]) {}
			}
			"""))
		#expect(result.errorSummary == ["graph.missingDependency /App/Trackers.swift:8:7"])
	}

	@Test
	func `Given a composite bound to the element When it injects the collection Then it is not its own member`() {
		let result = generateWithContext(trackerProtocolFile, appFile("/App/Trackers.swift", """
			@Service(boundTo: AnalyticsTracker.self)
			final class AllTrackers: AnalyticsTracker {
				init(trackers: [any AnalyticsTracker]) {}
			}

			@Service
			final class ConsoleTracker: AnalyticsTracker {
				init() {}
			}
			"""))
		expectOutput(result, contains: ["AllTrackers(trackers: [self.consoleTracker])"])
	}

	// MARK: - Defaults, cycles, scopes

	@Test
	func `Given a defaulted collection and no members When generated Then the default is kept`() {
		let result = generateWithContext(appFile("/App/Client.swift", """
			protocol Interceptor {}

			@Service
			final class Client {
				init(interceptors: [any Interceptor] = []) {}
			}
			"""))
		expectOutput(result, contains: ["\t\t\tClient()\n"])
	}

	@Test
	func `Given a defaulted collection and a member When generated Then the member is injected`() {
		let result = generateWithContext(appFile("/App/Client.swift", """
			protocol Interceptor {}

			@Service
			final class AuthInterceptor: Interceptor {
				init() {}
			}

			@Service
			final class Client {
				init(interceptors: [any Interceptor] = []) {}
			}
			"""))
		expectOutput(result, contains: ["Client(interceptors: [self.authInterceptor])"])
	}

	@Test
	func `Given a member that injects the consumer When generated Then the cycle fails the build`() throws {
		let result = generateWithContext(trackerProtocolFile, analyticsFile, appFile("/App/Loop.swift", """
			@Service
			final class LoopTracker: AnalyticsTracker {
				init(analytics: Analytics) {}
			}
			"""))
		#expect(result.output == nil)
		#expect(result.errorSummary == ["graph.cycle /App/Analytics.swift:1:1"])
		let cycle = try #require(result.errors.first)
		#expect(cycle.message.contains("'Analytics'") && cycle.message.contains("'LoopTracker'"), "\(cycle.message)")
	}

	@Test
	func `Given a transient member When listed Then its accessor is called and keeps its scope`() {
		let result = generateWithContext(trackerProtocolFile, analyticsFile, appFile("/App/Trackers.swift", """
			@Service(scope: .transient)
			final class ConsoleTracker: AnalyticsTracker {
				init() {}
			}
			"""))
		expectOutput(result, contains: [
			"\tvar consoleTracker: ConsoleTracker {\n\t\tConsoleTracker()\n\t}",
			"Analytics(trackers: [self.consoleTracker])",
		])
	}

	@Test
	func `Given a collection parameter on a bean When generated Then the bean method receives the list`() {
		let result = generateWithContext(trackerProtocolFile, appFile("/App/Config.swift", """
			@Service
			final class ConsoleTracker: AnalyticsTracker {
				init() {}
			}

			@Configuration
			enum AnalyticsConfiguration {
				@Bean
				static func pipeline(trackers: [any AnalyticsTracker]) -> Pipeline { Pipeline() }
			}
			"""))
		expectOutput(result, contains: ["AnalyticsConfiguration.pipeline(trackers: [self.consoleTracker])"])
	}

	// MARK: - Compatibility

	@Test
	func `Given a graph without collection injection When generated Then the output is unchanged`() {
		let result = generateWithContext(trackerProtocolFile, appFile("/App/Wiring.swift", """
			@Service(boundTo: AnalyticsTracker.self)
			final class ConsoleTracker: AnalyticsTracker {
				init() {}
			}

			@Configuration
			enum TagConfiguration {
				@Bean
				static func tags() -> [String] { [] }
			}

			@Service
			final class TagList {
				init(tags: [String], tracker: any AnalyticsTracker) {}
			}
			"""))
		#expect(result.output == """
			// Generated by SwiftBeans — do not edit.
			import Foundation
			import SwiftBeans

			protocol AppContextProtocol: AnyObject {
				var analyticsTracker: any AnalyticsTracker { get }
				var stringArray: [String] { get }
				var tagList: TagList { get }
			}

			extension AppContext {
				var analyticsTracker: any AnalyticsTracker {
					_swiftBeansRegistry.singleton(key: "analyticsTracker") {
						ConsoleTracker()
					}
				}

				var stringArray: [String] {
					_swiftBeansRegistry.singleton(key: "stringArray") {
						TagConfiguration.tags()
					}
				}

				var tagList: TagList {
					_swiftBeansRegistry.singleton(key: "tagList") {
						TagList(tags: self.stringArray, tracker: self.analyticsTracker)
					}
				}
			}

			extension AppContext: AppContextProtocol {}

			""", "\(result.output ?? result.renderedDiagnostics)")
	}
}
