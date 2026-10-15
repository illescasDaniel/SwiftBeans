/// How the graph supplies a non-assisted parameter (SPEC collection-injection → Rules).
enum Injection: Equatable {
	/// `self.<accessor>` of the provider for this key. The provider may be assisted; callers decide what that means.
	case key(TypeKey)
	/// `[self.a, self.b]`: provider indices in accessor-name order; empty for `[any E]` without members.
	case collection([Int])
}

/// Shared by the validator and the code generator so they agree on every parameter.
struct ParameterInjection {
	private let providers: [BeanProvider]
	private let providedKeys: Set<TypeKey>
	private var membersByElement: [TypeKey: [Int]] = [:]

	init(_ providers: [BeanProvider]) {
		self.providers = providers
		providedKeys = Set(providers.map(\.key))
		for (index, provider) in providers.enumerated() where !provider.isAssisted {
			for element in provider.conformances.union([provider.key]) {
				membersByElement[element, default: []].append(index)
			}
		}
		for element in membersByElement.keys {
			membersByElement[element]!.sort {
				(providers[$0].key.accessorName, providers[$0].location) < (providers[$1].key.accessorName, providers[$1].location)
			}
		}
	}

	/// `nil` when the graph cannot supply `parameter` of `providers[consumer]`.
	///
	/// A provider for `[E]` itself always wins; otherwise a `[E]` parameter collects the members of `E`
	/// (never the consumer), or gets `[]` when spelled `[any E]` and required. A defaulted one with nothing to inject keeps its default.
	func injection(for parameter: BeanParameter, of consumer: Int) -> Injection? {
		guard let key = parameter.key, parameter.assisted == nil else { return nil }
		if providedKeys.contains(key) {
			return .key(key)
		}
		guard case .array(let element) = key else { return nil }
		let members = (membersByElement[element] ?? []).filter { $0 != consumer }
		if !members.isEmpty || (parameter.elementSpelledWithAny && !parameter.hasDefault) {
			return .collection(members)
		}
		return nil
	}
}
