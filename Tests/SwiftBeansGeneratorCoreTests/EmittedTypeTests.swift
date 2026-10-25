import Testing

@testable import SwiftBeansGeneratorCore

@Suite("Emitted types — identity and positional spelling")
struct EmittedTypeTests {
	private let p = EmittedType.nominal([.init(name: "P", genericArguments: [])])
	private let q = EmittedType.nominal([.init(name: "Q", genericArguments: [])])

	private func pair(_ first: EmittedType, _ second: EmittedType) -> EmittedType {
		.nominal([.init(name: "Pair", genericArguments: [first, second])])
	}

	@Test func `Given explicit wrappers When rendered Then identity erases only the markers`() {
		let type = EmittedType.array(.existential(p))
		#expect(type.key == .array(p.key))
		#expect(type.description == "[any P]")
		#expect(EmittedType.unmarked(type.key).description == "[P]")
	}

	@Test func `Given corresponding positions When merged Then union obeys order independent laws`() {
		let a = pair(.existential(p), q)
		let b = pair(p, .existential(q))
		let c = pair(p, q)
		#expect(a.merging(b).description == "Pair<any P, any Q>")
		#expect(a.merging(b) == b.merging(a))
		#expect(a.merging(a) == a)
		#expect(a.merging(b).merging(c) == a.merging(b.merging(c)))
		#expect(a.merging(b).key == c.key)
	}

	@Test func `Given wrapper and argument evidence When merged Then both positions remain distinct`() {
		let outside = EmittedType.existential(pair(p, q))
		let inside = pair(.existential(p), q)
		#expect(outside.merging(inside).description == "any Pair<any P, Q>")
		#expect(outside.merging(outside).description == "any Pair<P, Q>")
	}
	@Test(arguments: ["[any P]", "Array<(any P)>", "[String: any P]", "Box<[any P]>", "any Box<P>", "Module.Outer<any P>.Inner<any Q>"])
	func `Given parsed syntax When normalized Then emitted structure and graph identity agree`(spelling: String) throws {
		let normalized = try KeyNormalization.key(forSpelling: spelling).get()
		#expect(normalized.emittedType.key == normalized.key)
		#expect(try KeyNormalization.key(forSpelling: normalized.emittedType.description).get().emittedType == normalized.emittedType)
		#expect(EmittedType.unmarked(normalized.key).description == normalized.key.description)
	}

}
