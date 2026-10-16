/// Graph-level checks: duplicate keys, accessor collisions, missing dependencies, factories, assisted keys, cycles.
///
/// Keys are `(type, qualifier)`. Every check iterates providers sorted by `(key, location)`, never dictionary order.
enum GraphValidator {
	static func validate(_ providers: [BeanProvider]) -> [GeneratorDiagnostic] {
		let providers = providers.sorted { ($0.key, $0.location) < ($1.key, $1.location) }
		var diagnostics: [GeneratorDiagnostic] = []
		var byKey: [BeanKey: [Int]] = [:]
		for (index, provider) in providers.enumerated() {
			byKey[provider.key, default: []].append(index)
		}

		// 1. Duplicate keys.
		for key in byKey.keys.sorted() where byKey[key]!.count > 1 {
			let indices = byKey[key]!
			for index in indices {
				let others = indices.filter { $0 != index }.map { "'\(providers[$0].displayName)'" }.joined(separator: ", ")
				diagnostics.append(GeneratorDiagnostic(
					id: "graph.duplicateProvider",
					location: providers[index].location,
					message: "duplicate provider for \(key.quoted); also provided by \(others)"
				))
			}
		}

		// 2. Accessor-name collisions between different keys (a qualified key is never renamed to avoid one).
		var keysByAccessor: [String: [BeanKey]] = [:]
		for key in byKey.keys.sorted() {
			keysByAccessor[key.accessorName, default: []].append(key)
		}
		for accessor in keysByAccessor.keys.sorted() where keysByAccessor[accessor]!.count > 1 {
			let keys = keysByAccessor[accessor]!
			let names = keys.map(\.quoted).joined(separator: " and ")
			let fix = keys.contains { $0.qualifier != nil }
				? "rename a qualifier or bind one of them to a different type"
				: "bind one of them to a different type"
			for key in keys {
				for index in byKey[key]! {
					diagnostics.append(GeneratorDiagnostic(
						id: "graph.accessorCollision",
						location: providers[index].location,
						message: "accessor name '\(accessor)' is produced by both \(names); \(fix)"
					))
				}
			}
		}

		func didYouMean(_ type: TypeKey) -> [GeneratorDiagnostic] {
			providers
				.filter { $0.key.type.lastComponentName != nil && $0.key.type.lastComponentName == type.lastComponentName }
				.map {
					GeneratorDiagnostic(
						severity: .note,
						id: "graph.didYouMean",
						location: $0.location,
						message: "did you mean \($0.key.quoted) (provided by '\($0.displayName)')?"
					)
				}
		}

		// 3. Missing dependencies (a `[E]` parameter may be supplied by the members of `E`).
		let injection = ParameterInjection(providers)
		for (index, provider) in providers.enumerated() {
			for parameter in provider.parameters {
				guard let key = parameter.key, !parameter.hasDefault, injection.injection(for: parameter, of: index) == nil else { continue }
				// An unqualified parameter never picks a named provider, even a single one.
				let named = key.qualifier == nil ? providers.filter { $0.key.type == key.type } : []
				if !named.isEmpty {
					diagnostics.append(GeneratorDiagnostic(
						id: "graph.missingDependency",
						location: parameter.location,
						message: "missing dependency \(key.quoted) required by '\(provider.displayName)'; only named providers exist, add @Qualifier(\"…\") to the parameter",
						notes: named.map {
							GeneratorDiagnostic(
								severity: .note,
								id: "graph.namedCandidate",
								location: $0.location,
								message: "use @Qualifier(\"\($0.key.qualifier!)\") for '\($0.displayName)'"
							)
						}
					))
					continue
				}
				diagnostics.append(GeneratorDiagnostic(
					id: "graph.missingDependency",
					location: parameter.location,
					message: "missing dependency \(key.quoted) required by '\(provider.displayName)'",
					notes: didYouMean(key.type)
				))
			}
		}

		// 3b. Factory parameters: the return type matches the unqualified provider of that type.
		let firstByType = { (type: TypeKey) in byKey[BeanKey(type)]?.first.map { providers[$0] } }
		for provider in providers {
			for parameter in provider.parameters {
				guard let factory = parameter.factory, !parameter.hasDefault else { continue }
				switch FactoryBinding.resolve(factory, providersByKey: firstByType) {
				case .deferred, .assisted:
					break
				case .missing:
					diagnostics.append(GeneratorDiagnostic(
						id: "graph.missingDependency",
						location: parameter.location,
						message: "missing dependency '\(factory.returnKey)' required by '\(provider.displayName)' (factory '\(factory.description)')",
						notes: didYouMean(factory.returnKey)
					))
				case .mismatch(let target, let expected):
					let reason = target.isAssisted
						? "'\(target.displayName)' takes runtime arguments; inject it as '\(expected)'"
						: "'\(factory.returnKey)' takes no runtime arguments; inject it as '() -> \(factory.returnKey)'"
					diagnostics.append(GeneratorDiagnostic(
						id: "factory.unresolved",
						location: parameter.location,
						message: "factory '\(factory.description)' required by '\(provider.displayName)' does not match: \(reason)"
					))
				}
			}
		}

		// 4. Assisted keys are not injectable: the graph cannot supply runtime arguments.
		for provider in providers {
			for parameter in provider.parameters where !parameter.hasDefault {
				guard let key = parameter.key, let indices = byKey[key], indices.allSatisfy({ providers[$0].isAssisted }) else { continue }
				let assisted = providers[indices[0]]
				let selector = assisted.key.accessorName + "("
					+ assisted.parameters.compactMap(\.assisted).map { "\($0.label ?? "_"):" }.joined() + ")"
				diagnostics.append(GeneratorDiagnostic(
					id: "assisted.notInjectable",
					location: parameter.location,
					message: "\(key.quoted) takes runtime arguments and cannot be injected into '\(provider.displayName)'; call '\(selector)' on the context instead"
				))
			}
		}

		// 5. Cycles over injected edges (assisted never; factories lazy; collections depend on every member).
		let edges = providers.indices.map { index in
			providers[index].parameters.flatMap { parameter -> [Int] in
				if parameter.factory != nil { return [] }
				switch injection.injection(for: parameter, of: index) {
				case .key(let key):
					return byKey[key].flatMap { providers[$0[0]].isAssisted ? nil : [$0[0]] } ?? []
				case .collection(let members):
					return members
				case nil:
					return []
				}
			}
		}
		for component in StronglyConnectedComponents.find(nodeCount: providers.count, edges: edges) {
			let isCycle = component.count > 1 || edges[component[0]].contains(component[0])
			guard isCycle else { continue }
			let members = component.sorted { providers[$0].location < providers[$1].location }
			let names = members.map { "'\(providers[$0].displayName)'" }.joined(separator: ", ")
			diagnostics.append(GeneratorDiagnostic(
				id: "graph.cycle",
				location: providers[members[0]].location,
				message: "dependency cycle between \(names)",
				notes: members.dropFirst().map {
					GeneratorDiagnostic(
						severity: .note,
						id: "graph.cycleMember",
						location: providers[$0].location,
						message: "'\(providers[$0].displayName)' is part of the cycle"
					)
				}
			))
		}
		return diagnostics
	}
}

/// Tarjan's algorithm.
enum StronglyConnectedComponents {
	static func find(nodeCount: Int, edges: [[Int]]) -> [[Int]] {
		var index = 0
		var indices = [Int?](repeating: nil, count: nodeCount)
		var lowLinks = [Int](repeating: 0, count: nodeCount)
		var onStack = [Bool](repeating: false, count: nodeCount)
		var stack: [Int] = []
		var components: [[Int]] = []

		func connect(_ node: Int) {
			indices[node] = index
			lowLinks[node] = index
			index += 1
			stack.append(node)
			onStack[node] = true
			for next in edges[node] {
				if indices[next] == nil {
					connect(next)
					lowLinks[node] = min(lowLinks[node], lowLinks[next])
				} else if onStack[next] {
					lowLinks[node] = min(lowLinks[node], indices[next]!)
				}
			}
			if lowLinks[node] == indices[node] {
				var component: [Int] = []
				while let member = stack.popLast() {
					onStack[member] = false
					component.append(member)
					if member == node { break }
				}
				components.append(component)
			}
		}

		for node in 0..<nodeCount where indices[node] == nil {
			connect(node)
		}
		return components
	}
}
