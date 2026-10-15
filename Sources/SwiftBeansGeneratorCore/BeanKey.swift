/// Graph identity: a normalized type plus an optional `named:` / `@Qualifier` name.
///
/// `JSONDecoder` named `snakeCase` and `JSONEncoder` named `snakeCase` are unrelated keys.
/// An unqualified key behaves exactly like its `TypeKey` (description, accessor, order).
struct BeanKey: Hashable, Sendable, Comparable, CustomStringConvertible {
	var type: TypeKey
	/// `nil` for the default (unnamed) bean of `type`.
	var qualifier: String?

	init(_ type: TypeKey, qualifier: String? = nil) {
		self.type = type
		self.qualifier = qualifier
	}

	/// `JSONDecoder`, `JSONDecoder named "snakeCase"`.
	var description: String {
		guard let qualifier else { return type.description }
		return "\(type) named \"\(qualifier)\""
	}

	/// For diagnostics: `'JSONDecoder'`, `'JSONDecoder' named "snakeCase"`.
	var quoted: String {
		guard let qualifier else { return "'\(type)'" }
		return "'\(type)' named \"\(qualifier)\""
	}

	/// `jsonDecoder`; `snakeCaseJSONDecoder` when qualified.
	var accessorName: String {
		type.accessorName(prefix: qualifier ?? "")
	}

	/// `accessorName` without backticks, used as the registry key.
	var registryKey: String {
		accessorName.replacingOccurrences(of: "`", with: "")
	}

	/// By type, then the unqualified key before named ones, then by name.
	static func < (lhs: BeanKey, rhs: BeanKey) -> Bool {
		(lhs.type.description, lhs.qualifier ?? "") < (rhs.type.description, rhs.qualifier ?? "")
	}
}
