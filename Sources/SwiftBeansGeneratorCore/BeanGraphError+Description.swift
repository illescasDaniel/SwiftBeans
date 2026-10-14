extension BeanGraphError: CustomStringConvertible {
	public var description: String {
		switch self {
		case .missingDependency(let consumer, let missingType):
			return "missing dependency '\(missingType)' required by '\(consumer)'"
		case .duplicateProvider(let typeName, let sources):
			return "duplicate provider for '\(typeName)': \(sources.joined(separator: ", "))"
		case .cycle(let nodes):
			return "dependency cycle: \(nodes.joined(separator: " -> "))"
		case .multipleApplicationContexts(let names):
			return "multiple @ApplicationContext types: \(names.joined(separator: ", "))"
		case .noApplicationContext:
			return "no @ApplicationContext found in scanned sources"
		case .notImplemented(let feature):
			return "not implemented: \(feature)"
		}
	}
}
