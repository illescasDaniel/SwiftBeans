import Foundation
import Testing
@testable import SwiftBeansGeneratorCore

@Suite("ScanSetResolver — SPEC Source discovery")
struct ScanSetResolverTests {
	@Test
	func `Given a local package target When resolved Then all nested swift files are returned sorted`() throws {
		let tree = try TemporaryTree()
		try tree.makePackage("App/Packages/Net")
		try tree.write("App/Packages/Net/Sources/Net/Zeta.swift")
		try tree.write("App/Packages/Net/Sources/Net/Alpha.swift")
		try tree.write("App/Packages/Net/Sources/Net/Remote/Client.swift")
		try tree.write("App/Packages/Net/Sources/Net/README.md")
		try tree.write("App/Packages/Net/Sources/Other/Ignored.swift")

		let sources = try ScanSetResolver.localPackageSources(
			for: configuration(("Packages/Net", ["Net"])),
			configDirectory: tree.url("App")
		)

		#expect(sources == [
			tree.resolved("App/Packages/Net/Sources/Net/Alpha.swift"),
			tree.resolved("App/Packages/Net/Sources/Net/Remote/Client.swift"),
			tree.resolved("App/Packages/Net/Sources/Net/Zeta.swift"),
		])
	}

	@Test
	func `Given several packages and targets When resolved Then files from all are merged and sorted`() throws {
		let tree = try TemporaryTree()
		try tree.makePackage("App/Packages/Net")
		try tree.write("App/Packages/Net/Sources/Net/Net.swift")
		try tree.write("App/Packages/Net/Sources/Models/Model.swift")
		try tree.makePackage("App/Packages/Home")
		try tree.write("App/Packages/Home/Sources/Home/Home.swift")

		let sources = try ScanSetResolver.localPackageSources(
			for: configuration(
				("Packages/Net", ["Net", "Models"]),
				("Packages/Home", ["Home"])
			),
			configDirectory: tree.url("App")
		)

		#expect(sources == [
			tree.resolved("App/Packages/Home/Sources/Home/Home.swift"),
			tree.resolved("App/Packages/Net/Sources/Models/Model.swift"),
			tree.resolved("App/Packages/Net/Sources/Net/Net.swift"),
		])
	}

	@Test
	func `Given the same target reached by two spellings When resolved Then each file appears once`() throws {
		let tree = try TemporaryTree()
		try tree.makePackage("App/Packages/Net")
		try tree.write("App/Packages/Net/Sources/Net/Net.swift")

		let sources = try ScanSetResolver.localPackageSources(
			for: configuration(
				("Packages/Net", ["Net"]),
				("./Packages/../Packages/Net/", ["Net"])
			),
			configDirectory: tree.url("App")
		)

		#expect(sources == [tree.resolved("App/Packages/Net/Sources/Net/Net.swift")])
	}

	@Test
	func `Given a path outside the config folder When resolved Then it is normalized without dot-dot components`() throws {
		let tree = try TemporaryTree()
		try tree.makePackage("Shared/Net")
		try tree.write("Shared/Net/Sources/Net/Net.swift")
		try tree.makeDirectory("Apps/Demo")

		let sources = try ScanSetResolver.localPackageSources(
			for: configuration(("../../Shared/Net", ["Net"])),
			configDirectory: tree.url("Apps/Demo")
		)

		#expect(sources == [tree.resolved("Shared/Net/Sources/Net/Net.swift")])
		#expect(sources.allSatisfy { !$0.pathComponents.contains("..") })
	}

	@Test
	func `Given a symlinked package path When resolved Then real paths are returned`() throws {
		let tree = try TemporaryTree()
		try tree.makePackage("Real/Net")
		try tree.write("Real/Net/Sources/Net/Net.swift")
		try tree.makeDirectory("App")
		try FileManager.default.createSymbolicLink(
			at: tree.url("App/NetLink"),
			withDestinationURL: tree.url("Real/Net")
		)

		let sources = try ScanSetResolver.localPackageSources(
			for: configuration(("NetLink", ["Net"]), ("../Real/Net", ["Net"])),
			configDirectory: tree.url("App")
		)

		#expect(sources == [tree.resolved("Real/Net/Sources/Net/Net.swift")])
	}

	@Test
	func `Given no local packages When resolved Then no files are returned`() throws {
		let tree = try TemporaryTree()
		let sources = try ScanSetResolver.localPackageSources(
			for: SwiftBeansScanConfiguration(),
			configDirectory: tree.root
		)
		#expect(sources.isEmpty)
	}

	@Test
	func `Given a missing package folder When resolved Then fails naming the entry`() throws {
		let tree = try TemporaryTree()
		try tree.makeDirectory("App")

		let error = #expect(throws: ScanConfigurationError.self) {
			try ScanSetResolver.localPackageSources(
				for: configuration(("Packages/Missing", ["Missing"]), line: 4),
				configDirectory: tree.url("App")
			)
		}
		#expect(error?.kind == .missingPackage)
		#expect(error?.line == 4)
		#expect(error?.message.contains("Packages/Missing") == true)
	}

	@Test
	func `Given a folder without Package swift When resolved Then fails as not a package`() throws {
		let tree = try TemporaryTree()
		try tree.write("App/Packages/Net/Sources/Net/Net.swift")

		let error = #expect(throws: ScanConfigurationError.self) {
			try ScanSetResolver.localPackageSources(
				for: configuration(("Packages/Net", ["Net"]), line: 2),
				configDirectory: tree.url("App")
			)
		}
		#expect(error?.kind == .notAPackage)
		#expect(error?.line == 2)
		#expect(error?.message.contains("Packages/Net") == true)
	}

	@Test
	func `Given a target without a Sources folder When resolved Then fails naming the target`() throws {
		let tree = try TemporaryTree()
		try tree.makePackage("App/Packages/Net")
		try tree.write("App/Packages/Net/Sources/Net/Net.swift")

		let error = #expect(throws: ScanConfigurationError.self) {
			try ScanSetResolver.localPackageSources(
				for: configuration(("Packages/Net", ["Net", "Typo"]), line: 6),
				configDirectory: tree.url("App")
			)
		}
		#expect(error?.kind == .missingTarget)
		#expect(error?.line == 6)
		#expect(error?.message.contains("Typo") == true)
	}

	// MARK: - Helpers

	private func configuration(
		_ entries: (path: String, targets: [String])...,
		line: Int = 2
	) -> SwiftBeansScanConfiguration {
		SwiftBeansScanConfiguration(localPackages: entries.map {
			.init(path: $0.path, targets: $0.targets, line: line)
		})
	}
}

/// A uniquely named temporary folder, removed when the test's fixture is released.
private final class TemporaryTree {
	let root: URL

	init() throws {
		root = FileManager.default.temporaryDirectory
			.appending(path: "SwiftBeansTests-\(UUID().uuidString)", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
	}

	deinit {
		try? FileManager.default.removeItem(at: root)
	}

	func url(_ relativePath: String) -> URL {
		root.appending(path: relativePath)
	}

	/// Expected form of a returned path: standardized and symlink-resolved (e.g. `/var` → `/private/var`).
	func resolved(_ relativePath: String) -> URL {
		url(relativePath).standardizedFileURL.resolvingSymlinksInPath()
	}

	func makeDirectory(_ relativePath: String) throws {
		try FileManager.default.createDirectory(at: url(relativePath), withIntermediateDirectories: true)
	}

	func write(_ relativePath: String, contents: String = "") throws {
		let file = url(relativePath)
		try FileManager.default.createDirectory(
			at: file.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try Data(contents.utf8).write(to: file)
	}

	func makePackage(_ relativePath: String) throws {
		try write("\(relativePath)/Package.swift", contents: "// swift-tools-version: 6.0\n")
	}
}
