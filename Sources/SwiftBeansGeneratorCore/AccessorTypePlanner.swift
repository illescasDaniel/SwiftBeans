/// Original provider visibility, before inferred spelling is applied.
struct AccessorTypeView {
	var visible: [GraphProvider]
}

struct AccessorTypePlan {
	let typesByProvider: [ProviderID: EmittedType]

	private let typesByOwner: [String: [BeanKey: EmittedType]]

	init(typesByProvider: [ProviderID: EmittedType]) {
		self.typesByProvider = typesByProvider
		var grouped: [String: [BeanKey: EmittedType]] = [:]
		for (id, type) in typesByProvider { grouped[id.owner, default: [:]][id.key] = type }
		typesByOwner = grouped
	}

	func types(ownedBy owner: String) -> [BeanKey: EmittedType] {
		typesByOwner[owner] ?? [:]
	}
}

/// Computes one spelling per declaring owner from original source evidence only.
enum AccessorTypePlanner {
	static func plan(views: [AccessorTypeView]) -> AccessorTypePlan {
		var types: [ProviderID: EmittedType] = [:]
		for view in views {
			var evidence: [TypeKey: EmittedType] = [:]
			func include(_ type: EmittedType) {
				let key = type.key
				evidence[key] = evidence[key].map { $0.merging(type) } ?? type
			}
			for provider in view.visible {
				include(provider.bean.emittedType)
				for parameter in provider.bean.parameters {
					if let type = parameter.emittedType { include(type) }
					if let factory = parameter.factory { include(factory.returnEmittedType) }
				}
			}
			for provider in view.visible {
				let type = evidence[provider.bean.key.type]!
				types[provider.id] = types[provider.id].map { $0.merging(type) } ?? type
			}
		}
		return AccessorTypePlan(typesByProvider: types)
	}
}
