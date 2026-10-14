enum Naming {
	/// Converts a type name to an accessor name (`UserService` → `userService`, `URLSession` → `urlSession`).
	static func accessorName(forTypeName typeName: String) -> String {
		guard !typeName.isEmpty else { return typeName }
		var characters = Array(typeName)
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
}
