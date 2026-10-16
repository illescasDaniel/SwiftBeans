/// How a function-typed parameter is wired against the graph.
enum FactoryBinding {
	/// `{ self.t }`
	case deferred(BeanProvider)
	/// `{ self.t($0, label: $1) }`
	case assisted(BeanProvider)
	/// No provider for the return key.
	case missing
	/// A provider exists but the function type does not fit it; `expected` is the signature that would.
	case mismatch(BeanProvider, expected: String)

	/// `providersByKey` holds the first provider per key (duplicates are reported separately).
	static func resolve(_ factory: FactoryType, providersByKey: (TypeKey) -> BeanProvider?) -> FactoryBinding {
		guard let provider = providersByKey(factory.returnKey) else { return .missing }
		let assisted = provider.parameters.compactMap(\.assisted)
		let expected = "(\(assisted.map(\.canonicalType).joined(separator: ", "))) -> \(provider.key)"
		guard provider.isAssisted else {
			return factory.parameterTypes.isEmpty ? .deferred(provider) : .mismatch(provider, expected: expected)
		}
		return assisted.map(\.canonicalType) == factory.parameterTypes
			? .assisted(provider)
			: .mismatch(provider, expected: expected)
	}

	/// The closure literal, e.g. `{ self.itemDetailViewModel(item: $0) }`.
	static func closure(for provider: BeanProvider) -> String {
		guard provider.isAssisted else { return "{ self.\(provider.key.accessorName) }" }
		let arguments = provider.parameters.compactMap(\.assisted).enumerated().map { index, argument in
			argument.label.map { "\($0): $\(index)" } ?? "$\(index)"
		}.joined(separator: ", ")
		return "{ self.\(provider.key.accessorName)(\(arguments)) }"
	}
}
