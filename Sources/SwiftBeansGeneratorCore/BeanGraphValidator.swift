/// Validates a set of bean providers (missing deps, duplicates, cycles).
public enum BeanGraphValidator {
	public static func validate(
		providers: [BeanProvider],
		contextTypeName: String = "AppContext"
	) throws -> BeanGraph {
		try checkDuplicates(providers)
		let byKey = Dictionary(uniqueKeysWithValues: providers.map { ($0.key, $0) })
		try checkMissing(providers, byKey: byKey)
		try checkCycles(providers, byKey: byKey)
		return BeanGraph(contextTypeName: contextTypeName, providers: providers)
	}

	private static func checkDuplicates(_ providers: [BeanProvider]) throws {
		var sourcesByKey: [InjectableKey: [String]] = [:]
		for provider in providers {
			sourcesByKey[provider.key, default: []].append(provider.sourceName)
		}
		for (key, sources) in sourcesByKey where sources.count > 1 {
			throw BeanGraphError.duplicateProvider(typeName: key.typeName, sources: sources.sorted())
		}
	}

	private static func checkMissing(
		_ providers: [BeanProvider],
		byKey: [InjectableKey: BeanProvider]
	) throws {
		for provider in providers {
			for dependency in provider.dependencies {
				if byKey[dependency] == nil {
					throw BeanGraphError.missingDependency(
						consumer: provider.sourceName,
						missingType: dependency.typeName
					)
				}
			}
		}
	}

	private static func checkCycles(
		_ providers: [BeanProvider],
		byKey: [InjectableKey: BeanProvider]
	) throws {
		var visiting = Set<InjectableKey>()
		var visited = Set<InjectableKey>()
		var stack: [InjectableKey] = []

		func visit(_ key: InjectableKey) throws {
			if visited.contains(key) { return }
			if visiting.contains(key) {
				let cycleStart = stack.firstIndex(of: key) ?? 0
				let cycle = stack[cycleStart...].map(\.typeName) + [key.typeName]
				throw BeanGraphError.cycle(Array(cycle))
			}
			visiting.insert(key)
			stack.append(key)
			if let provider = byKey[key] {
				for dependency in provider.dependencies {
					try visit(dependency)
				}
			}
			_ = stack.popLast()
			visiting.remove(key)
			visited.insert(key)
		}

		for provider in providers {
			try visit(provider.key)
		}
	}
}
