enum Naming {
	/// Protocol seam for an `@ApplicationContext` type (`AppContext` → `AppContextProtocol`).
	static func protocolName(forContextTypeName contextTypeName: String) -> String {
		"\(contextTypeName)Protocol"
	}

	/// Converts a type name to an accessor name (`UserService` → `userService`, `URLSession` → `urlSession`).
	///
	/// Existential prefixes are stripped so `any HTTPClient` → `httpClient` (valid Swift identifier).
	static func accessorName(forTypeName typeName: String) -> String {
		let stripped = stripExistentialPrefix(typeName)
		guard !stripped.isEmpty else { return stripped }
		var characters = Array(stripped)
		if characters.count > 1, characters[0].isUppercase, characters[1].isUppercase {
			var end = 0
			while end < characters.count, characters[end].isUppercase {
				end += 1
			}
			// `URLSession` → lowercase `URL`, keep `Session`
			if end > 1, end < characters.count, characters[end].isLowercase {
				end -= 1
			}
			for index in 0..<end {
				characters[index] = Character(characters[index].lowercased())
			}
			return String(characters)
		}
		characters[0] = Character(characters[0].lowercased())
		return String(characters)
	}

	private static func stripExistentialPrefix(_ typeName: String) -> String {
		if typeName.hasPrefix("any ") {
			return String(typeName.dropFirst(4))
		}
		if typeName.hasPrefix("some ") {
			return String(typeName.dropFirst(5))
		}
		return typeName
	}
}
