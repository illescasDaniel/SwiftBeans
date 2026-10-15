import Foundation
import Testing
@testable import SwiftBeansGeneratorCore

@Suite("GeneratorRequest — SPEC Source discovery (scan set re-resolved every run)")
struct GeneratorRequestTests {
	@Test
	func `Given a request When encoded and decoded Then it round-trips`() throws {
		let request = GeneratorRequest(scanRoot: "/App", targetSources: ["/App/AppContext.swift"])
		let data = try JSONEncoder().encode(request)
		#expect(try JSONDecoder().decode(GeneratorRequest.self, from: data) == request)
		#expect(request.configFileName == ".swiftbeans.yml")
	}

	@Test
	func `Given a generated local package When a new file is added and the request is generated again Then it joins the graph`() throws {
		let tree = try RequestTree()
		try tree.writeApp()
		try tree.writeConfig()
		try tree.makePackage("Packages/Kit")
		try tree.write("Packages/Kit/Sources/Kit/Greeter.swift", greeterSource)
		let request = tree.request()

		let first = SwiftBeansGeneration.generate(request: request)
		#expect(first.errors.isEmpty)
		#expect(first.output?.contains("var greeter: Greeter") == true)
		#expect(first.output?.contains("var clock: Clock") == false)

		try tree.write("Packages/Kit/Sources/Kit/Nested/Clock.swift", clockSource)
		let second = SwiftBeansGeneration.generate(request: request)
		#expect(second.errors.isEmpty)
		#expect(second.output?.contains("var greeter: Greeter") == true)
		#expect(second.output?.contains("var clock: Clock") == true)
	}

	@Test
	func `Given a request with no config When the config is created later Then the same request picks it up`() throws {
		let tree = try RequestTree()
		try tree.writeApp()
		try tree.makePackage("Packages/Kit")
		try tree.write("Packages/Kit/Sources/Kit/Greeter.swift", greeterSource)
		let request = tree.request()

		let before = SwiftBeansGeneration.generate(request: request)
		#expect(before.errors.isEmpty)
		#expect(before.output?.contains("Greeter") == false)
		#expect(before.output?.contains("import Kit") == false)

		try tree.writeConfig()
		let after = SwiftBeansGeneration.generate(request: request)
		#expect(after.errors.isEmpty)
		#expect(after.output?.contains("var greeter: Greeter") == true)
		#expect(after.output?.contains("import Kit") == true)
	}

	@Test
	func `Given a config edited after planning When generated Then the new local package is scanned`() throws {
		let tree = try RequestTree()
		try tree.writeApp()
		try tree.writeConfig()
		try tree.makePackage("Packages/Kit")
		try tree.write("Packages/Kit/Sources/Kit/Greeter.swift", greeterSource)
		try tree.makePackage("Packages/Time")
		try tree.write("Packages/Time/Sources/Time/Clock.swift", clockSource)
		let request = tree.request()

		#expect(SwiftBeansGeneration.generate(request: request).output?.contains("var clock: Clock") == false)

		try tree.write(".swiftbeans.yml", """
			local_packages:
			  - path: Packages/Kit
			    targets:
			      - Kit
			  - path: Packages/Time
			    targets:
			      - Time
			""")
		let result = SwiftBeansGeneration.generate(request: request)
		#expect(result.errors.isEmpty)
		#expect(result.output?.contains("var clock: Clock") == true)
		#expect(result.output?.contains("import Time") == true)
	}

	@Test
	func `Given an unchanged scan set When generated twice Then the output is byte identical and not rewritten`() throws {
		let tree = try RequestTree()
		try tree.writeApp()
		try tree.writeConfig()
		try tree.makePackage("Packages/Kit")
		try tree.write("Packages/Kit/Sources/Kit/Greeter.swift", greeterSource)
		let request = tree.request()

		let first = try #require(SwiftBeansGeneration.generate(request: request).output)
		let second = try #require(SwiftBeansGeneration.generate(request: request).output)
		#expect(first == second)

		let file = tree.url("Generated/SwiftBeansGenerated.swift")
		try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
		#expect(try GeneratedFileWriter.write(first, to: file))
		#expect(try GeneratedFileWriter.write(second, to: file) == false)
	}

	@Test
	func `Given an invalid config entry When generated Then the error names the config file and line and nothing is generated`() throws {
		let tree = try RequestTree()
		try tree.writeApp()
		try tree.write(".swiftbeans.yml", """
			local_packages:
			  - path: Packages/Missing
			    targets:
			      - Kit
			""")

		let result = SwiftBeansGeneration.generate(request: tree.request())

		#expect(result.output == nil)
		let error = try #require(result.errors.first)
		#expect(error.id == "config.invalid")
		#expect(error.location.file == tree.url(".swiftbeans.yml").path)
		#expect(error.location.line == 2)
		#expect(error.message.contains("Packages/Missing"))
	}

	@Test
	func `Given a config in a parent folder When generated Then it is ignored`() throws {
		let tree = try RequestTree()
		try tree.write("Parent/.swiftbeans.yml", """
			local_packages:
			  - path: Nowhere
			    targets:
			      - Kit
			""")
		try tree.write("Parent/App/AppContext.swift", "@ApplicationContext\nfinal class AppContext {}\n")
		let request = GeneratorRequest(
			scanRoot: tree.url("Parent/App").path,
			targetSources: [tree.url("Parent/App/AppContext.swift").path]
		)

		let result = SwiftBeansGeneration.generate(request: request)

		#expect(result.errors.isEmpty)
		#expect(result.output != nil)
	}

	private let greeterSource = """
		public protocol Greeter {}
		@Service(boundTo: Greeter.self)
		public final class LiveGreeter: Greeter { public init() {} }
		"""

	private let clockSource = """
		@Service
		public final class Clock { public init() {} }
		"""
}

private final class RequestTree {
	let root: URL

	init() throws {
		root = FileManager.default.temporaryDirectory
			.appending(path: "SwiftBeansRequestTests-\(UUID().uuidString)", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
	}

	deinit {
		try? FileManager.default.removeItem(at: root)
	}

	func url(_ relativePath: String) -> URL {
		root.appending(path: relativePath)
	}

	func write(_ relativePath: String, _ contents: String = "") throws {
		let file = url(relativePath)
		try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
		try Data(contents.utf8).write(to: file)
	}

	func makePackage(_ relativePath: String) throws {
		try write("\(relativePath)/Package.swift", "// swift-tools-version: 6.0\n")
	}

	func writeApp() throws {
		try write("AppContext.swift", "@ApplicationContext\nfinal class AppContext {}\n")
	}

	func writeConfig() throws {
		try write(".swiftbeans.yml", """
			local_packages:
			  - path: Packages/Kit
			    targets:
			      - Kit
			""")
	}

	func request() -> GeneratorRequest {
		GeneratorRequest(scanRoot: root.path, targetSources: [url("AppContext.swift").path])
	}
}
