import Foundation
import Testing

@testable import SwiftBeansGeneratorCore

/// Compile emitted code against the locally built runtime and macro executable, without another build.
@Suite("Child contexts — generated source compilation", .serialized)
struct GeneratedChildContractCompileTests {
	private struct Compilation {
		var status: Int32
		var diagnostics: String
	}
	private func compile(_ source: String, mainActorDefault: Bool = false, foreignModule: Bool = false) throws
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
		let plugin = ["SwiftBeansMacros-tool", "SwiftBeansMacros"].map { products.appending(path: $0) }.first {
			FileManager.default.isExecutableFile(atPath: $0.path)
		}!
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
		if foreignModule {
			let foreign = folder.appending(path: "Foreign.swift")
			try "public final class AppContext { public init() {} }".write(
				to: foreign, atomically: true, encoding: .utf8)
			let built = try run([
				"-swift-version", "6", "-module-cache-path", folder.appending(path: "cache").path,
				"-emit-module", "-module-name", "Foreign", "-emit-module-path",
				folder.appending(path: "Foreign.swiftmodule").path, foreign.path,
			])
			try #require(built.status == 0, "\(built.diagnostics)")
		}
		var arguments = [
			"-swift-version", "6", "-strict-concurrency=complete", "-warnings-as-errors", "-typecheck",
			"-module-name", "ChildFixture", "-module-cache-path", folder.appending(path: "cache").path,
			"-I", modules.path, "-I", folder.path, "-load-plugin-executable",
			plugin.path + "#SwiftBeansMacros", originalURL.path, generatedURL.path,
		]
		if mainActorDefault { arguments += ["-default-isolation", "MainActor"] }
		return try run(arguments)
	}

	private func generateWithContextSource(_ text: String) -> GenerationResult {
		SwiftBeansGeneration.generate(sources: [appFile("/App/CompileFixture.swift", text)])
	}

	private static let source = """
		import SwiftBeans
		@MainActor @ApplicationContext final class AppContext {}
		@MainActor @Service final class Transport {}
		struct User { let id: Int }
		@MainActor @ChildContext(of: ChildFixture.AppContext.self, teardown: .managed)
		final class Session { @ContextInput let currentUser: User }
		@MainActor @Service(in: Session.self, scope: .transient)
		final class Model { init(transport: Transport, user: User) {} }
		@MainActor @Service(in: Session.self)
		final class Detail { init(transport: Transport, @Assisted id: Int) {} }
		@MainActor @Service(in: Session.self, scope: .transient)
		final class Coordinator {
			init(make: @escaping @MainActor () -> Model, detail: @escaping @MainActor (Int) -> Detail, asyncMake: @escaping @MainActor () async throws -> Model) {}
		}
		@MainActor final class FakeParent: AppContextProtocol { let transport = Transport() }
		@MainActor final class FakeChild: SessionProtocol {
			let currentUser = User(id: 1)
			var model: Model { Model(transport: Transport(), user: currentUser) }
			func detail(id: Int) -> Detail { Detail(transport: Transport(), id: id) }
			var coordinator: Coordinator { Coordinator(make: { self.model }, detail: { self.detail(id: $0) }, asyncMake: { self.model }) }
			func close() async {}
		}
		@MainActor func use() async {
			let child: any SessionProtocol = Session(parent: FakeParent(), currentUser: User(id: 1))
			_ = child.coordinator
			await child.close()
			let fake: any SessionProtocol = FakeChild()
			await fake.close()
		}
		"""

	@Test(arguments: [false, true])
	func
		`Given emitted actor contracts and fakes When compiled Then Swift strict concurrency accepts both defaults`(
			_ mainActor: Bool
		) throws
	{
		let result = try compile(Self.source, mainActorDefault: mainActor)
		#expect(result.status == 0, "\(result.diagnostics)")
	}

	@Test
	func `Given a foreign same-named parent When compiler checks the witness Then identity mismatch is rejected`()
		throws
	{
		let source = Self.source.replacingOccurrences(
			of: "import SwiftBeans", with: "import SwiftBeans\nimport Foreign"
		).replacingOccurrences(of: "ChildFixture.AppContext.self", with: "Foreign.AppContext.self")
		let result = try compile(source, foreignModule: true)
		#expect(result.status != 0)
		#expect(result.diagnostics.contains("cannot convert"), "\(result.diagnostics)")
	}

	@Test func `Given actor-erasing factory When compiled Then the invalid actor conversion fails`() throws {
		let source = Self.source.replacingOccurrences(
			of: "make: @escaping @MainActor () -> Model", with: "make: @escaping @Sendable () -> Model")
		let result = try compile(source)
		#expect(result.status != 0)
		#expect(result.diagnostics.contains("MainActor"), "\(result.diagnostics)")
	}

	@Test func `Given nested context names When generated Then original lexical parent lookup compiles`() throws {
		let source = """
			import SwiftBeans
			enum Contexts {
				@ApplicationContext final class Root {}
				@ChildContext(of: Root.self) final class Child { @ContextInput let value: Int }
			}
			"""
		let result = try compile(source)
		#expect(result.status == 0, "\(result.diagnostics)")
	}
	@Test func `Given empty configuration with foreign owner When compiled Then its reference is still validated`()
		throws
	{
		let source =
			Self.source.replacingOccurrences(
				of: "import SwiftBeans", with: "import SwiftBeans\nimport Foreign")
			+ "\n@Configuration(in: Foreign.AppContext.self) enum Empty {}\n"
		let result = try compile(source, foreignModule: true)
		#expect(result.status != 0)
		#expect(result.diagnostics.contains("cannot convert"), "\(result.diagnostics)")
	}

}
