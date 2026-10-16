import SwiftParser
import SwiftSyntax

/// Normalized type used as a graph key. `any` is not part of the key.
indirect enum TypeKey: Hashable, Sendable, Comparable, CustomStringConvertible {
	/// `Outer.Inner<…>`
	case nominal([NominalComponent])
	/// `[T]` and `Array<T>`
	case array(TypeKey)
	/// `[K: V]` and `Dictionary<K, V>`
	case dictionary(TypeKey, TypeKey)

	struct NominalComponent: Hashable, Sendable {
		var name: String
		var genericArguments: [TypeKey]

		init(_ name: String, _ genericArguments: [TypeKey] = []) {
			self.name = name
			self.genericArguments = genericArguments
		}
	}

	/// Canonical spelling, e.g. `Outer.Inner`, `[String: User]`, `Cache<User>`.
	var description: String {
		switch self {
		case .nominal(let components):
			return components.map { component in
				component.genericArguments.isEmpty
					? component.name
					: "\(component.name)<\(component.genericArguments.map(\.description).joined(separator: ", "))>"
			}.joined(separator: ".")
		case .array(let element):
			return "[\(element)]"
		case .dictionary(let key, let value):
			return "[\(key): \(value)]"
		}
	}

	/// The last nominal component's name (`Diagnostics.Logger` → `Logger`), for missing-dependency hints.
	var lastComponentName: String? {
		if case .nominal(let components) = self {
			return components.last?.name
		}
		return nil
	}

	/// SPEC accessor naming; Swift keywords come back escaped (`` `class` ``).
	var accessorName: String {
		accessorName(prefix: "")
	}

	/// `prefix` then the name pieces, lowercased as one name: `snakeCase` + `JSONDecoder` → `snakeCaseJSONDecoder`.
	func accessorName(prefix: String) -> String {
		let name = Self.lowercasingLeadingWord(prefix + namePieces.joined())
		return Self.keywords.contains(name) ? "`\(name)`" : name
	}

	/// `accessorName` without backticks, used as the registry key.
	var registryKey: String {
		accessorName.replacingOccurrences(of: "`", with: "")
	}

	static func < (lhs: TypeKey, rhs: TypeKey) -> Bool {
		lhs.description < rhs.description
	}

	/// Generic arguments come before the name they qualify: `Cache<User>` → `User`, `Cache`.
	private var namePieces: [String] {
		switch self {
		case .nominal(let components):
			return components.flatMap { $0.genericArguments.flatMap(\.namePieces) + [$0.name] }
		case .array(let element):
			return element.namePieces + ["Array"]
		case .dictionary(let key, let value):
			return key.namePieces + value.namePieces + ["Dictionary"]
		}
	}

	/// `URLSession` → `urlSession`, `ID` → `id`, `UserService` → `userService`.
	private static func lowercasingLeadingWord(_ name: String) -> String {
		var characters = Array(name)
		var end = 0
		while end < characters.count, characters[end].isUppercase {
			end += 1
		}
		// Keep the capital that starts the next word: `URLSession` lowercases `URL`, not `URLS`.
		if end > 1, end < characters.count, characters[end].isLowercase {
			end -= 1
		}
		for index in 0..<max(end, min(1, characters.count)) {
			characters[index] = Character(characters[index].lowercased())
		}
		return String(characters)
	}

	private static let keywords: Set<String> = [
		"associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init",
		"inout", "internal", "let", "open", "operator", "private", "precedencegroup", "protocol", "public",
		"rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue",
		"default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return",
		"throw", "switch", "where", "while", "as", "false", "is", "nil", "super", "throws", "true", "try",
	]
}

/// Why a type cannot be a graph key.
struct UnsupportedKey: Error, Equatable, Sendable, CustomStringConvertible {
	enum Reason: Equatable, Sendable {
		case optional
		case implicitlyUnwrappedOptional
		case tuple
		case function
		case opaque
		case metatype
		case selfType
		case composition
		case unrecognized
	}

	var reason: Reason

	var description: String {
		switch reason {
		case .optional: "optional types cannot be injected; inject the wrapped type or give the parameter a default value"
		case .implicitlyUnwrappedOptional: "implicitly unwrapped optional types cannot be injected"
		case .tuple: "tuple types cannot be injected"
		case .function: "function types cannot be injected"
		case .opaque: "opaque 'some' types cannot be injected"
		case .metatype: "metatypes cannot be injected"
		case .selfType: "'Self' cannot be injected"
		case .composition: "protocol compositions cannot be injected"
		case .unrecognized: "this type cannot be injected"
		}
	}
}

enum KeyNormalization {
	typealias Normalized = (key: TypeKey, spelledWithAny: Bool)

	/// Normalizes `type`: strips `any`, parentheses and whitespace; desugars `Array` / `Dictionary`.
	static func key(for type: TypeSyntax) -> Result<Normalized, UnsupportedKey> {
		let unwrapped = strippingParentheses(type)
		var spelledWithAny = false
		var keyType = unwrapped
		if let existential = unwrapped.as(SomeOrAnyTypeSyntax.self), existential.someOrAnySpecifier.tokenKind == .keyword(.any) {
			spelledWithAny = true
			keyType = existential.constraint
		}
		do {
			return .success((try normalize(keyType), spelledWithAny))
		} catch {
			return .failure(error)
		}
	}

	/// Parses `spelling` as a type, then normalizes it (tests and diagnostics).
	static func key(forSpelling spelling: String) -> Result<Normalized, UnsupportedKey> {
		var parser = Parser(spelling)
		return key(for: TypeSyntax.parse(from: &parser))
	}

	/// The wrapped type of `T?` / `T!` / `Optional<T>`, if `type` is an optional.
	static func optionalWrapped(_ type: TypeSyntax) -> TypeSyntax? {
		let type = strippingParentheses(type)
		if let optional = type.as(OptionalTypeSyntax.self) {
			return optional.wrappedType
		}
		if let optional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
			return optional.wrappedType
		}
		if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Optional",
		   let arguments = identifier.genericArgumentClause?.arguments, arguments.count == 1
		{
			return arguments.first?.argument
		}
		return nil
	}

	/// True for `[any P]` / `Array<any P>`: the consumer accepts zero or more implementations.
	static func elementSpelledWithAny(_ type: TypeSyntax) -> Bool {
		let type = strippingParentheses(type)
		var element: TypeSyntax?
		if let array = type.as(ArrayTypeSyntax.self) {
			element = array.element
		} else if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Array",
		          let arguments = identifier.genericArgumentClause?.arguments, arguments.count == 1
		{
			element = arguments.first?.argument
		}
		guard let element else { return false }
		return strippingParentheses(element).as(SomeOrAnyTypeSyntax.self)?.someOrAnySpecifier.tokenKind == .keyword(.any)
	}

	/// Parses `spelling` as a type, then checks `elementSpelledWithAny` (tests).
	static func elementSpelledWithAny(forSpelling spelling: String) -> Bool {
		var parser = Parser(spelling)
		return elementSpelledWithAny(TypeSyntax.parse(from: &parser))
	}

	private static func normalize(_ type: TypeSyntax) throws(UnsupportedKey) -> TypeKey {
		let type = strippingParentheses(type)
		if let identifier = type.as(IdentifierTypeSyntax.self) {
			let name = identifier.name.text
			let arguments = try genericArguments(identifier.genericArgumentClause)
			switch (name, arguments.count) {
			case ("Self", _): throw UnsupportedKey(reason: .selfType)
			case ("Optional", 1): throw UnsupportedKey(reason: .optional)
			case ("Array", 1): return .array(arguments[0])
			case ("Dictionary", 2): return .dictionary(arguments[0], arguments[1])
			default: return .nominal([.init(name, arguments)])
			}
		}
		if let member = type.as(MemberTypeSyntax.self) {
			guard case .nominal(let base) = try normalize(member.baseType) else {
				throw UnsupportedKey(reason: .unrecognized)
			}
			return .nominal(base + [.init(member.name.text, try genericArguments(member.genericArgumentClause))])
		}
		if let array = type.as(ArrayTypeSyntax.self) {
			return .array(try normalize(array.element))
		}
		if let dictionary = type.as(DictionaryTypeSyntax.self) {
			return .dictionary(try normalize(dictionary.key), try normalize(dictionary.value))
		}
		if let existential = type.as(SomeOrAnyTypeSyntax.self) {
			guard existential.someOrAnySpecifier.tokenKind == .keyword(.any) else {
				throw UnsupportedKey(reason: .opaque)
			}
			return try normalize(existential.constraint)
		}
		if let attributed = type.as(AttributedTypeSyntax.self) {
			return try normalize(attributed.baseType)
		}
		if type.is(OptionalTypeSyntax.self) { throw UnsupportedKey(reason: .optional) }
		if type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) { throw UnsupportedKey(reason: .implicitlyUnwrappedOptional) }
		if type.is(TupleTypeSyntax.self) { throw UnsupportedKey(reason: .tuple) }
		if type.is(FunctionTypeSyntax.self) { throw UnsupportedKey(reason: .function) }
		if type.is(MetatypeTypeSyntax.self) { throw UnsupportedKey(reason: .metatype) }
		if type.is(CompositionTypeSyntax.self) { throw UnsupportedKey(reason: .composition) }
		throw UnsupportedKey(reason: .unrecognized)
	}

	private static func genericArguments(_ clause: GenericArgumentClauseSyntax?) throws(UnsupportedKey) -> [TypeKey] {
		guard let clause else { return [] }
		var keys: [TypeKey] = []
		for argument in clause.arguments {
			keys.append(try normalize(argument.argument))
		}
		return keys
	}

	/// `((T))` → `T`; a one-element unlabeled tuple type is just parentheses.
	private static func strippingParentheses(_ type: TypeSyntax) -> TypeSyntax {
		var type = type
		while let tuple = type.as(TupleTypeSyntax.self), tuple.elements.count == 1,
		      let element = tuple.elements.first, element.firstName == nil, element.ellipsis == nil
		{
			type = element.type
		}
		return type
	}
}

/// A function-typed dependency parameter: `(Item) -> ItemDetailViewModel`, `() -> T`.
struct FactoryType: Equatable, Sendable {
	/// Canonical spellings (`FactoryNormalization.canonicalSpelling`), in order.
	var parameterTypes: [String]
	var returnKey: TypeKey
	var returnSpelledWithAny: Bool

	/// `(Item) -> ItemDetailViewModel`
	var description: String {
		"(\(parameterTypes.joined(separator: ", "))) -> \(returnKey)"
	}
}

/// Why a function type cannot be a factory.
struct UnsupportedFactory: Error, Equatable, Sendable, CustomStringConvertible {
	var description: String
}

enum FactoryNormalization {
	/// `nil` when `type` is not a function type; attributes (`@escaping`, `@Sendable`) and parentheses are looked through.
	static func factory(for type: TypeSyntax) -> Result<FactoryType, UnsupportedFactory>? {
		guard let function = functionType(type) else { return nil }
		var parameterTypes: [String] = []
		for element in function.parameters {
			if element.ellipsis != nil {
				return .failure(UnsupportedFactory(description: "factory parameters cannot be variadic"))
			}
			if let attributed = element.type.as(AttributedTypeSyntax.self), !attributed.specifiers.isEmpty {
				return .failure(UnsupportedFactory(description: "factory parameters cannot be inout, borrowing, consuming or sending"))
			}
			parameterTypes.append(KeyNormalization.canonicalSpelling(of: element.type))
		}
		switch KeyNormalization.key(for: function.returnClause.type) {
		case .success(let normalized):
			if normalized.key == .nominal([.init("Void")]) {
				return .failure(UnsupportedFactory(description: "the factory's return type is not injectable: Void cannot be injected"))
			}
			return .success(FactoryType(
				parameterTypes: parameterTypes,
				returnKey: normalized.key,
				returnSpelledWithAny: normalized.spelledWithAny
			))
		case .failure(let unsupported):
			return .failure(UnsupportedFactory(description: "the factory's return type is not injectable: \(unsupported)"))
		}
	}

	private static func functionType(_ type: TypeSyntax) -> FunctionTypeSyntax? {
		var type = type
		while true {
			if let function = type.as(FunctionTypeSyntax.self) {
				return function
			}
			if let attributed = type.as(AttributedTypeSyntax.self) {
				type = attributed.baseType
			} else if let tuple = type.as(TupleTypeSyntax.self), tuple.elements.count == 1,
			          let element = tuple.elements.first, element.firstName == nil, element.ellipsis == nil
			{
				type = element.type
			} else {
				return nil
			}
		}
	}
}

extension KeyNormalization {
	/// Comparable spelling for assisted-factory matching: the key's description when `type` is a valid key,
	/// otherwise the spelling without whitespace and `@escaping`.
	static func canonicalSpelling(of type: TypeSyntax) -> String {
		if case .success(let normalized) = key(for: type) {
			return normalized.key.description
		}
		return type.trimmedDescription
			.replacingOccurrences(of: "@escaping", with: "")
			.filter { !$0.isWhitespace }
	}
}
