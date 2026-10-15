import Foundation
import Testing
@testable import SwiftBeansGeneratorCore

@Suite("GeneratedFileWriter — SPEC Generator rules → Generated file")
struct GeneratedFileWriterTests {
	@Test
	func `Given unchanged contents When written again Then the file and its modification date are untouched`() throws {
		let file = FileManager.default.temporaryDirectory
			.appending(path: "SwiftBeansGenerated-\(UUID().uuidString).swift")
		defer { try? FileManager.default.removeItem(at: file) }

		#expect(try GeneratedFileWriter.write("first", to: file))
		let past = Date(timeIntervalSinceNow: -3600)
		try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: file.path)

		#expect(try GeneratedFileWriter.write("first", to: file) == false)
		let unchangedDate = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
		#expect(unchangedDate == past)

		#expect(try GeneratedFileWriter.write("second", to: file))
		#expect(try String(contentsOf: file, encoding: .utf8) == "second")
	}
}
