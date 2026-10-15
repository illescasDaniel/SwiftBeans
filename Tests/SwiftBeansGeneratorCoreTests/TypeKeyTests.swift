import Testing
@testable import SwiftBeansGeneratorCore

@Suite("TypeKey — SPEC Injectable keys and accessor names")
struct TypeKeyTests {
	@Test(arguments: [
		("[String:Int]", "[String: Int]"),
		("Dictionary<String, Int>", "[String: Int]"),
		("Dictionary<String,Int>", "[String: Int]"),
		("Array<User>", "[User]"),
		("(any Store)", "Store"),
		("any Store", "Store"),
		("((Store))", "Store"),
		("Box< Int >", "Box<Int>"),
		("Outer.Inner<Int>", "Outer.Inner<Int>"),
		("[Array<String>]", "[[String]]"),
	])
	func `Given equivalent spellings When normalized Then they are one key with a canonical description`(
		spelling: String,
		canonical: String
	) throws {
		let key = try KeyNormalization.key(forSpelling: spelling).get().key
		let expected = try KeyNormalization.key(forSpelling: canonical).get().key
		#expect(key == expected)
		#expect(key.description == canonical)
	}

	@Test(arguments: [
		("Swift.String", "String"),
		("Outer.Inner", "Inner"),
		("[String]", "Set<String>"),
	])
	func `Given different spellings When normalized Then keys differ`(lhs: String, rhs: String) throws {
		let left = try KeyNormalization.key(forSpelling: lhs).get().key
		let right = try KeyNormalization.key(forSpelling: rhs).get().key
		#expect(left != right)
	}

	@Test(arguments: [
		("any Store", true),
		("(any Store)", true),
		("Store", false),
		("[any Store]", false),
	])
	func `Given a spelling When normalized Then any is recorded only at the top level`(
		spelling: String,
		spelledWithAny: Bool
	) throws {
		#expect(try KeyNormalization.key(forSpelling: spelling).get().spelledWithAny == spelledWithAny)
	}

	@Test(arguments: [
		("Logger?", UnsupportedKey.Reason.optional),
		("Optional<Logger>", .optional),
		("Logger!", .implicitlyUnwrappedOptional),
		("(Int, String)", .tuple),
		("() -> Void", .function),
		("@escaping () -> Void", .function),
		("some View", .opaque),
		("Int.Type", .metatype),
		("any Store.Type", .metatype),
		("Self", .selfType),
		("any Reader & Writer", .composition),
		("Reader & Writer", .composition),
	])
	func `Given an unsupported type When normalized Then it fails with the reason`(
		spelling: String,
		reason: UnsupportedKey.Reason
	) {
		#expect(throws: UnsupportedKey(reason: reason)) {
			try KeyNormalization.key(forSpelling: spelling).get()
		}
	}

	@Test(arguments: [
		("UserService", "userService"),
		("URLSession", "urlSession"),
		("HTTPClient", "httpClient"),
		("any HTTPClient", "httpClient"),
		("ID", "id"),
		("URL", "url"),
		("Outer.Inner", "outerInner"),
		("Foundation.URLSession", "foundationURLSession"),
		("[User]", "userArray"),
		("[URL]", "urlArray"),
		("[String: User]", "stringUserDictionary"),
		("Cache<User>", "userCache"),
		("Pair<Left, Right>", "leftRightPair"),
		("Class", "`class`"),
		("Default", "`default`"),
		("Protocol", "`protocol`"),
	])
	func `Given a key When naming its accessor Then the SPEC naming table applies`(
		spelling: String,
		accessor: String
	) throws {
		#expect(try KeyNormalization.key(forSpelling: spelling).get().key.accessorName == accessor)
	}
}
