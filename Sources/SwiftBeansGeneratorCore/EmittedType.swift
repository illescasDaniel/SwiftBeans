/// Canonical Swift type structure, retaining existential wrappers independently of graph identity.
indirect enum EmittedType: Equatable, Sendable {
	case nominal([NominalComponent])
	case array(EmittedType)
	case dictionary(EmittedType, EmittedType)
	case existential(EmittedType)

	struct NominalComponent: Equatable, Sendable {
		var name: String
		var genericArguments: [EmittedType]
	}

	var key: TypeKey {
		switch self {
		case .nominal(let components):
			return .nominal(components.map { .init($0.name, $0.genericArguments.map(\.key)) })
		case .array(let element): return .array(element.key)
		case .dictionary(let key, let value): return .dictionary(key.key, value.key)
		case .existential(let constraint): return constraint.key
		}
	}

	var description: String {
		switch self {
		case .nominal(let components):
			return components.map { component in
				component.genericArguments.isEmpty ? component.name
					: "\(component.name)<\(component.genericArguments.map(\.description).joined(separator: ", "))>"
			}.joined(separator: ".")
		case .array(let element): return "[\(element.description)]"
		case .dictionary(let key, let value): return "[\(key.description): \(value.description)]"
		case .existential(let constraint): return "any \(constraint.description)"
		}
	}

	static func unmarked(_ key: TypeKey) -> EmittedType {
		switch key {
		case .nominal(let components):
			return .nominal(components.map { .init(name: $0.name, genericArguments: $0.genericArguments.map(unmarked)) })
		case .array(let element): return .array(unmarked(element))
		case .dictionary(let key, let value): return .dictionary(unmarked(key), unmarked(value))
		}
	}

	func merging(_ other: EmittedType) -> EmittedType {
		switch (self, other) {
		case (.existential(let lhs), .existential(let rhs)):
			return .existential(lhs.merging(rhs))
		case (.existential(let lhs), _): return .existential(lhs.merging(other))
		case (_, .existential(let rhs)): return .existential(merging(rhs))
		case (.nominal(let lhs), .nominal(let rhs)):
			precondition(lhs.count == rhs.count, "mismatched emitted types")
			return .nominal(zip(lhs, rhs).map { left, right in
				precondition(left.name == right.name && left.genericArguments.count == right.genericArguments.count,
					"mismatched emitted types")
				return .init(name: left.name, genericArguments: zip(left.genericArguments, right.genericArguments).map {
					$0.merging($1)
				})
			})
		case (.array(let lhs), .array(let rhs)): return .array(lhs.merging(rhs))
		case (.dictionary(let lk, let lv), .dictionary(let rk, let rv)):
			return .dictionary(lk.merging(rk), lv.merging(rv))
		default: preconditionFailure("mismatched emitted types")
		}
	}
}
