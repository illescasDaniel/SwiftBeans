import Foundation
import Testing

@testable import SwiftBeansGeneratorCore

@Suite("Nested existential spelling — generated source compilation", .serialized)
struct GeneratedExistentialContractCompileTests {
	private struct Compilation {
		var status: Int32
		var diagnostics: String
	}
	private func compile(_ source: String, existentialAny: Bool = false) throws
		-> Compilation
	{
		let folder = FileManager.default.temporaryDirectory.appending(
			path: "SwiftBeansCompile-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: folder) }
		let repo = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
			.deletingLastPathComponent()
		let products =
			ProcessInfo.processInfo.environment["SWIFTBEANS_TEST_PRODUCTS"].map { URL(filePath: $0) }
			?? repo.appending(path: ".build/debug")
		let modules =
			FileManager.default.fileExists(atPath: products.appending(path: "Modules").path)
			? products.appending(path: "Modules") : products
		let plugin = try #require(["SwiftBeansMacros-tool", "SwiftBeansMacros"].map { products.appending(path: $0) }.first {
			FileManager.default.isExecutableFile(atPath: $0.path)
		})
		let result = generateWithContextSource(source)
		let generated = try #require(result.output, "\(result.renderedDiagnostics)")
		let originalURL = folder.appending(path: "Client.swift")
		let generatedURL = folder.appending(path: "Generated.swift")
		try source.write(to: originalURL, atomically: true, encoding: .utf8)
		try generated.write(to: generatedURL, atomically: true, encoding: .utf8)
		func run(_ arguments: [String]) throws -> Compilation {
			let process = Process()
			process.executableURL = URL(filePath: "/usr/bin/env")
			process.arguments = ["swiftc"] + arguments
			let pipe = Pipe()
			process.standardOutput = pipe
			process.standardError = pipe
			try process.run()
			let data = pipe.fileHandleForReading.readDataToEndOfFile()
			process.waitUntilExit()
			return Compilation(
				status: process.terminationStatus, diagnostics: String(decoding: data, as: UTF8.self))
		}
		var arguments = [
			"-swift-version", "6", "-strict-concurrency=complete", "-warnings-as-errors", "-typecheck",
			"-module-name", "ChildFixture", "-module-cache-path", folder.appending(path: "cache").path,
			"-I", modules.path, "-I", folder.path, "-load-plugin-executable",
			plugin.path + "#SwiftBeansMacros", originalURL.path, generatedURL.path,
		]
		if existentialAny { arguments += ["-enable-upcoming-feature", "ExistentialAny"] }
		return try run(arguments)
	}

	private func generateWithContextSource(_ text: String) -> GenerationResult {
		SwiftBeansGeneration.generate(sources: [appFile("/App/CompileFixture.swift", text)])
	}

	@Test(arguments: [false, true])
	func `Given nested existential declarations When compiled Then protocols accessors and calls agree`(enabled: Bool) throws {
		let result = try compile(Self.source, existentialAny: enabled)
		#expect(result.status == 0, "\(result.diagnostics)")
	}

	private static let source = """
		import SwiftBeans
		protocol P {}
		extension P { typealias Alias = Int }
		struct Value: P {}
		struct Item {}
		struct Box<T> { let value: T }
		@ApplicationContext final class AppContext {}
		@ChildContext(of: AppContext.self) final class Session { @ContextInput let input: Box<[any P]> }
		@Configuration enum Config {
			@Bean static func alias() -> (any P).Alias { 1 }
			@Bean(named: "assisted") static func assistedArray(@Assisted item: Item) -> [any P] { [Value()] }
			@Bean static func array() -> [any P] { [Value()] }
			@Bean static func dictionary() -> [String: any P] { ["one": Value()] }
			@Bean static func nested() -> Box<[String: [any P]]> { Box(value: ["one": [Value()]]) }
			@Bean static func assisted(@Assisted item: Item) -> Box<any P> { Box(value: Value()) }
		}
		@Service final class Consumer {
			init(array: [any P], dictionary: [String: any P], nested: Box<[String: [any P]]>,
				deferred: () -> [any P], assisted: (Item) -> Box<any P>) {}
		}
		@Service(in: Session.self) final class ChildConsumer { init(array: [any P], input: Box<[any P]>) {} }
		final class Fake: AppContextProtocol {
			var pAlias: P.Alias { 1 }
			func assistedPArray(item: Item) -> [any P] { [] }
			var pArray: [any P] { [] }
			var stringPDictionary: [String: any P] { [:] }
			var stringPArrayDictionaryBox: Box<[String: [any P]]> { Box(value: [:]) }
			func pBox(item: Item) -> Box<any P> { Box(value: Value()) }
			var consumer: Consumer { fatalError() }
		}
		func check(_ context: AppContext, _ child: Session, _ fake: any AppContextProtocol) {
			let _: P.Alias = context.pAlias
			let _: [any P] = context.assistedPArray(item: Item())
			let _: [any P] = context.pArray
			let _: [String: any P] = context.stringPDictionary
			let _: Box<[String: [any P]]> = context.stringPArrayDictionaryBox
			let _: Box<any P> = context.pBox(item: Item())
			let _: Consumer = context.consumer
			let _: ChildConsumer = child.childConsumer
			let _: [any P] = fake.pArray
		}
		"""
}
