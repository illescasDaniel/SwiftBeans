import SwiftBeansSyntaxRules

/// One accessor's worth of wiring.
struct BeanProvider {
	enum Construction: Equatable {
		/// `TypeName(args)`
		case initializer(typeName: String)
		/// `TypeName.method(args)`
		case staticMethod(typeName: String, name: String)
	}

	var key: TypeKey
	var spelledWithAny: Bool
	var scope: ScopeLiteral
	var origin: SourceFile.Origin
	/// The annotated declaration, for diagnostics.
	var location: SourcePosition
	/// `ReportService`, `AppConfiguration.urlSession`.
	var displayName: String
	var construction: Construction
	var parameters: [BeanParameter]
	/// Keys the type named by `key` declares in scanned inheritance clauses, transitively; it can join `[K]` for each.
	var conformances: Set<TypeKey>

	/// True when any parameter is `@Assisted`: the accessor is a method, not a property.
	var isAssisted: Bool {
		parameters.contains { $0.assisted != nil }
	}
}

struct BeanParameter {
	/// `nil` for `_`.
	var label: String?
	/// `nil` when the parameter can only take its default (unsupported or unwritten type), and always for an assisted one.
	var key: TypeKey?
	var spelledWithAny: Bool
	/// `[any P]`: with no array bean and no members, the parameter gets `[]`.
	var elementSpelledWithAny: Bool
	var hasDefault: Bool
	var location: SourcePosition
	/// Non-nil for an `@Assisted` parameter.
	var assisted: AssistedArgument?
}

/// A runtime argument of an assisted provider's method accessor.
struct AssistedArgument {
	/// External label; `nil` for `_`.
	var label: String?
	/// As spelled, backticks included.
	var internalName: String
	/// As written in the source.
	var typeSpelling: String
}

/// Builds providers from scanned declarations, matching extensions and initializers across files.
struct ProviderResolver {
	private(set) var providers: [BeanProvider] = []
	private(set) var diagnostics: [GeneratorDiagnostic] = []

	private let types: [String: TypeDecl]
	private let configurationNames: Set<String>
	private let extensionInitializers: [String: [InitializerInfo]]
	/// Inheritance clauses of every scanned type and extension, by qualified type name.
	private let inheritedTypes: [String: [TypeKey]]

	static func resolve(_ files: [ScannedFile]) -> (providers: [BeanProvider], diagnostics: [GeneratorDiagnostic]) {
		var resolver = ProviderResolver(files)
		for file in files {
			for location in file.conditionalDecls {
				resolver.error("decl.conditional", at: location, "SwiftBeans declarations inside '#if' blocks are not supported in v1")
			}
			for location in file.assistedPropertyLocations {
				resolver.error("assisted.property", at: location, "@Assisted can only be applied to parameters, not stored properties")
			}
			for service in file.services {
				resolver.resolve(service, origin: file.source.origin)
			}
			for bean in file.beans {
				resolver.resolve(bean, origin: file.source.origin)
			}
		}
		return (resolver.providers, resolver.diagnostics)
	}

	private init(_ files: [ScannedFile]) {
		var types: [String: TypeDecl] = [:]
		var extensionInitializers: [String: [InitializerInfo]] = [:]
		var inheritedTypes: [String: [TypeKey]] = [:]
		for file in files {
			for type in file.types {
				if types[type.name] == nil {
					types[type.name] = type
				}
				inheritedTypes[type.name, default: []] += type.inheritedTypes
			}
			for extensionDecl in file.extensions {
				extensionInitializers[extensionDecl.extendedName, default: []] += extensionDecl.initializers
				inheritedTypes[extensionDecl.extendedName, default: []] += extensionDecl.inheritedTypes
			}
		}
		self.types = types
		self.extensionInitializers = extensionInitializers
		self.inheritedTypes = inheritedTypes
		configurationNames = Set(files.flatMap(\.types).filter(\.isConfiguration).map(\.name))
	}

	// MARK: - @Service

	private mutating func resolve(_ service: ServiceDecl, origin: SourceFile.Origin) {
		guard let type = types[service.typeName] else { return }

		let keyResult: Result<KeyNormalization.Normalized, UnsupportedKey>
		if let boundTo = service.boundTo {
			keyResult = boundTo.key
		} else {
			keyResult = KeyNormalization.key(forSpelling: service.typeName)
		}
		let normalized: KeyNormalization.Normalized
		switch keyResult {
		case .success(let value):
			normalized = value
		case .failure(let unsupported):
			let location = service.boundTo?.location ?? service.location
			let spelling = service.boundTo?.spelling ?? service.typeName
			error("key.unsupported", at: location, "cannot provide '\(spelling)': \(unsupported)")
			return
		}

		var parameters: [ParameterInfo] = []
		var selectedIsPublic = false
		let candidates = (type.initializers + (extensionInitializers[type.name] ?? [])).filter(\.isCandidate)
		if let selected = selectInitializer(candidates, for: type) {
			parameters = selected.parameters
			selectedIsPublic = selected.isPublic
			if selected.hasEffects {
				error(
					"init.effects",
					at: selected.location,
					"the initializer SwiftBeans calls for '\(type.name)' cannot be async or throw; generated accessors are synchronous and non-throwing"
				)
			}
		} else if candidates.isEmpty, type.kind == .struct {
			if type.hasWrappedProperty {
				error(
					"init.propertyWrapper",
					at: type.location,
					"'\(type.name)' has property-wrapper stored properties; declare an initializer for SwiftBeans to call"
				)
			} else {
				parameters = type.memberwise
			}
		}

		if case .localPackage(let module) = origin, !(type.isPublic && selectedIsPublic) {
			error(
				"package.notPublic",
				at: service.location,
				"'\(type.name)' is declared in local package '\(module)'; it must be public (or open) with a public initializer to be injected"
			)
		}

		let resolved = resolveParameters(parameters)
		providers.append(BeanProvider(
			key: normalized.key,
			spelledWithAny: normalized.spelledWithAny,
			scope: scope(service.scope, scopeLocation: service.scopeLocation, parameters: resolved),
			origin: origin,
			location: service.location,
			displayName: type.name,
			construction: .initializer(typeName: type.name),
			parameters: resolved,
			conformances: conformances(of: normalized.key)
		))
	}

	/// The single candidate, or the `@Inject` one. Reports ambiguity; `nil` when none is declared.
	private mutating func selectInitializer(_ candidates: [InitializerInfo], for type: TypeDecl) -> InitializerInfo? {
		if candidates.count <= 1 {
			return candidates.first
		}
		let injected = candidates.filter(\.isInject)
		if injected.count == 1 {
			return injected[0]
		}
		let notes = candidates.map(\.location).sorted().map {
			GeneratorDiagnostic(severity: .note, id: "init.candidate", location: $0, message: "candidate initializer")
		}
		let problem = injected.isEmpty ? "has several initializers" : "has more than one @Inject initializer"
		diagnostics.append(GeneratorDiagnostic(
			id: "init.ambiguous",
			location: type.location,
			message: "'\(type.name)' \(problem); mark exactly one with @Inject",
			notes: notes
		))
		return nil
	}

	// MARK: - @Bean

	private mutating func resolve(_ bean: BeanDecl, origin: SourceFile.Origin) {
		let displayName = "\(bean.enclosingName).\(bean.name)"
		guard configurationNames.contains(bean.enclosingName) else {
			error(
				"bean.outsideConfiguration",
				at: bean.location,
				"@Bean '\(displayName)' must be declared in a @Configuration type or an extension of one"
			)
			return
		}
		let normalized: KeyNormalization.Normalized
		switch bean.returnKey {
		case .success(let value):
			normalized = value
		case .failure(let unsupported):
			error("key.unsupported", at: bean.returnTypeLocation, "cannot provide '\(bean.returnSpelling)': \(unsupported)")
			return
		}
		if case .localPackage(let module) = origin, !(bean.isPublic && types[bean.enclosingName]?.isPublic == true) {
			error(
				"package.notPublic",
				at: bean.location,
				"@Bean '\(displayName)' is declared in local package '\(module)'; it must be public in a public @Configuration type"
			)
		}
		let resolved = resolveParameters(bean.parameters)
		providers.append(BeanProvider(
			key: normalized.key,
			spelledWithAny: normalized.spelledWithAny,
			scope: scope(bean.scope, scopeLocation: bean.scopeLocation, parameters: resolved),
			origin: origin,
			location: bean.location,
			displayName: displayName,
			construction: .staticMethod(typeName: bean.enclosingName, name: bean.name),
			parameters: resolved,
			conformances: conformances(of: normalized.key)
		))
	}

	// MARK: - Helpers

	/// Walks inheritance clauses from the declaration named by `key` (`Sub: Base`, `Base: P` → `Base`, `P`).
	/// Matching is by spelling, like keys; types declared outside the scan set contribute nothing.
	private func conformances(of key: TypeKey) -> Set<TypeKey> {
		var found = Set<TypeKey>()
		var pending = [key]
		while let next = pending.popLast() {
			guard case .nominal = next else { continue }
			for inherited in inheritedTypes[next.description] ?? [] where inherited != key && found.insert(inherited).inserted {
				pending.append(inherited)
			}
		}
		return found
	}

	/// An assisted provider constructs a new instance per call, so it is always transient;
	/// an explicit `.singleton` is an error at the `scope:` argument.
	private mutating func scope(_ scope: ScopeLiteral, scopeLocation: SourcePosition?, parameters: [BeanParameter]) -> ScopeLiteral {
		guard parameters.contains(where: { $0.assisted != nil }) else { return scope }
		if scope == .singleton, let scopeLocation {
			error("assisted.singleton", at: scopeLocation, "a provider with @Assisted parameters creates a new instance per call and cannot be a singleton")
		}
		return .transient
	}

	/// Unsupported keys fail the build unless the parameter has a default to fall back on.
	/// Assisted parameters are runtime arguments, not keys: their types are not normalized.
	private mutating func resolveParameters(_ parameters: [ParameterInfo]) -> [BeanParameter] {
		parameters.map { parameter in
			if parameter.isAssisted {
				if let defaultLocation = parameter.defaultLocation {
					error("assisted.default", at: defaultLocation, "@Assisted parameters cannot have a default value")
				}
				if parameter.isVariadic {
					error("assisted.variadic", at: parameter.location, "@Assisted parameters cannot be variadic")
				}
				if parameter.isInout {
					error("assisted.inout", at: parameter.location, "@Assisted parameters cannot be inout")
				}
				return BeanParameter(
					label: parameter.label,
					key: nil,
					spelledWithAny: false,
					elementSpelledWithAny: false,
					hasDefault: parameter.hasDefault,
					location: parameter.location,
					assisted: AssistedArgument(
						label: parameter.label,
						internalName: parameter.internalName,
						typeSpelling: parameter.typeSpelling
					)
				)
			}
			var key: TypeKey?
			var spelledWithAny = false
			switch parameter.key {
			case .success(let normalized):
				key = normalized.key
				spelledWithAny = normalized.spelledWithAny
			case .failure(let unsupported) where !parameter.hasDefault:
				error("key.unsupported", at: parameter.typeLocation, "cannot inject '\(parameter.typeSpelling)': \(unsupported)")
			case .failure, nil:
				break
			}
			return BeanParameter(
				label: parameter.label,
				key: key,
				spelledWithAny: spelledWithAny,
				elementSpelledWithAny: parameter.elementSpelledWithAny,
				hasDefault: parameter.hasDefault,
				location: parameter.location,
				assisted: nil
			)
		}
	}

	private mutating func error(_ id: String, at location: SourcePosition, _ message: String) {
		diagnostics.append(GeneratorDiagnostic(id: id, location: location, message: message))
	}
}
