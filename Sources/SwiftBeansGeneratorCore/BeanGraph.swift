import SwiftBeans

/// A type that can be injected (concrete type or `boundTo` protocol name).
public struct InjectableKey: Hashable, Sendable, Codable {
	public var typeName: String

	public init(typeName: String) {
		self.typeName = typeName
	}
}

/// External label + type for an initializer or `@Bean` parameter.
public struct BeanParameter: Equatable, Sendable, Codable {
	public var label: String
	public var typeName: String

	public init(label: String, typeName: String) {
		self.label = label
		self.typeName = typeName
	}
}

/// How to construct a bean in generated code.
public enum BeanFactoryKind: Equatable, Sendable, Codable {
	case service(typeName: String, parameters: [BeanParameter])
	case bean(configurationType: String, methodName: String, parameters: [BeanParameter])
}

/// One `@Bean` or `@Service` provider in the scanned graph.
public struct BeanProvider: Equatable, Sendable {
	public var key: InjectableKey
	/// Types required by the factory / initializer (by injectable key type name).
	public var dependencies: [InjectableKey]
	public var scope: BeanScope
	/// Source declaration name for diagnostics (e.g. type or function name).
	public var sourceName: String
	public var factory: BeanFactoryKind?

	public init(
		key: InjectableKey,
		dependencies: [InjectableKey] = [],
		scope: BeanScope = .singleton,
		sourceName: String,
		factory: BeanFactoryKind? = nil
	) {
		self.key = key
		self.dependencies = dependencies
		self.scope = scope
		self.sourceName = sourceName
		self.factory = factory
	}
}

/// Graph validation / build failures (map to generator diagnostics in Phase 4).
public enum BeanGraphError: Error, Equatable, Sendable {
	case missingDependency(consumer: String, missingType: String)
	case duplicateProvider(typeName: String, sources: [String])
	case cycle([String])
	case multipleApplicationContexts([String])
	case noApplicationContext
	case notImplemented(String)
}

/// Validated provider set ready for code generation.
public struct BeanGraph: Equatable, Sendable {
	public var contextTypeName: String
	public var providers: [BeanProvider]

	public init(contextTypeName: String, providers: [BeanProvider]) {
		self.contextTypeName = contextTypeName
		self.providers = providers
	}

	public func provider(for key: InjectableKey) -> BeanProvider? {
		providers.first { $0.key == key }
	}
}
