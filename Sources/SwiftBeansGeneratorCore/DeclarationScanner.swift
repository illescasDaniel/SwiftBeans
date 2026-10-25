import SwiftBeansSyntaxRules
import SwiftParser
import SwiftSyntax

/// Everything the later stages need from one parsed file.
struct ScannedFile {
	var source: SourceFile
	var contexts: [ContextDecl] = []
	var children: [ChildContextDecl] = []
	var owners: [SourcePosition: OwnerReference] = [:]
	var configurationOwners: [String: OwnerReference] = [:]
	var contextDiagnostics: [GeneratorDiagnostic] = []
	var hasContextFeatures = false
	var types: [TypeDecl] = []
	var extensions: [ExtensionDecl] = []
	var services: [ServiceDecl] = []
	var beans: [BeanDecl] = []
	/// Annotated declarations under `#if` (not supported in v1).
	var conditionalDecls: [SourcePosition] = []
	/// `@Assisted` on stored properties of scanned types (parameters only; SPEC Assisted providers, rule 7).
	var assistedPropertyLocations: [SourcePosition] = []
	/// `@Qualifier` on stored properties of scanned types (parameters only; qualifiers SPEC).
	var qualifierPropertyLocations: [SourcePosition] = []
	var imports: [ImportRecord] = []
	/// Initializer bodies of every scanned type (and extension), for the inter-bean call diagnostic.
	var initializerBodies: [InitializerBody] = []
}

/// A call written as `name(...)` or `base.name(...)`.
struct CallSite {
	/// The spelled base (`AppConfiguration`, `Self`), `nil` for a bare call.
	var base: String?
	var name: String
	var location: SourcePosition
}

struct InitializerBody {
	/// Qualified name of the declaring (or extended) type.
	var typeName: String
	var calls: [CallSite]
}

struct ContextDecl {
	/// Qualified name, e.g. `App.Context`.
	var name: String
	/// Last name component, used for the protocol name.
	var simpleName: String
	var location: SourcePosition
	var isMainActor = false
}

enum TypeKind {
	case `class`
	case `struct`
	case actor
	case `enum`
	case `protocol`
}

struct TypeDecl {
	var name: String
	var kind: TypeKind
	var isConfiguration: Bool
	/// `public` or `open`.
	var isPublic: Bool
	var initializers: [InitializerInfo]
	/// Memberwise initializer parameters (structs).
	var memberwise: [ParameterInfo]
	/// A stored property carries an attribute (property wrapper) — no usable memberwise init.
	var hasWrappedProperty: Bool
	var location: SourcePosition
	/// Supported keys in the inheritance clause (superclass, protocols), for collection membership.
	var inheritedTypes: [TypeKey]
}

struct ExtensionDecl {
	var extendedName: String
	var initializers: [InitializerInfo]
	var inheritedTypes: [TypeKey]
}

struct InitializerInfo {
	var location: SourcePosition
	var isInject: Bool
	var isPublic: Bool
	/// Not `private` / `fileprivate` / failable.
	var isCandidate: Bool
	var hasEffects: Bool
	var parameters: [ParameterInfo]
}

struct ParameterInfo {
	/// `nil` for `_`.
	var label: String?
	/// The second name when present, else the first; as spelled, backticks included.
	var internalName: String
	var hasDefault: Bool
	/// The parameter's start, for missing-dependency errors.
	var location: SourcePosition
	/// The type, for unsupported-key errors.
	var typeLocation: SourcePosition
	/// `nil` when the type is not written (`var retries = 3`). For a defaulted optional, the wrapped type's key.
	var key: Result<KeyNormalization.Normalized, UnsupportedKey>?
	/// `[any P]`: an empty collection is a valid injection.
	var elementSpelledWithAny: Bool
	var typeSpelling: String
	/// `KeyNormalization.canonicalSpelling` of the type, to match assisted arguments against factory parameters.
	var canonicalType: String
	/// Non-nil when the type is a function type (a factory request).
	var factory: Result<FactoryType, UnsupportedFactory>?
	/// `@Assisted` / `@SwiftBeans.Assisted`.
	var isAssisted: Bool
	/// `@Qualifier(…)` / `@SwiftBeans.Qualifier(…)`.
	var qualifier: QualifierUse?
	/// `T...`
	var isVariadic: Bool
	/// `inout T`
	var isInout: Bool
	/// The default value expression, when written.
	var defaultLocation: SourcePosition?
}

/// A `@Qualifier` attribute on a parameter.
struct QualifierUse {
	/// The attribute.
	var location: SourcePosition
	var name: Result<String, LocatedViolation>
}

/// A `SwiftBeansSyntaxRules.Violation` the generator reports itself, at a scanned position.
struct LocatedViolation: Error {
	var id: String
	var message: String
	var location: SourcePosition
}

struct ServiceDecl {
	var typeName: String
	var scope: ScopeLiteral
	/// `named:`
	var qualifier: String?
	/// The `scope:` argument; non-nil only when a literal scope is written explicitly.
	var scopeLocation: SourcePosition?
	/// `boundTo:` key, when present.
	var boundTo: (key: Result<KeyNormalization.Normalized, UnsupportedKey>, location: SourcePosition, spelling: String)?
	var location: SourcePosition
}

struct BeanDecl {
	/// Qualified name of the declaring (or extended) type.
	var enclosingName: String
	var name: String
	var scope: ScopeLiteral
	/// `named:`
	var qualifier: String?
	/// The `scope:` argument; non-nil only when a literal scope is written explicitly.
	var scopeLocation: SourcePosition?
	var isPublic: Bool
	var parameters: [ParameterInfo]
	var returnKey: Result<KeyNormalization.Normalized, UnsupportedKey>
	var returnTypeLocation: SourcePosition
	var returnSpelling: String
	var location: SourcePosition
	/// Calls in the function body, for the inter-bean call diagnostic.
	var bodyCalls: [CallSite]
}

struct ImportRecord: Hashable {
	var module: String
	var testable: Bool
	var preconcurrency: Bool
	/// `nil` = unconditional; else a `#if` expression.
	var condition: String?
}

/// Parses one file and collects SwiftBeans declarations, types, extensions and imports.
struct DeclarationScanner {
	private let source: SourceFile
	private let converter: SourceLocationConverter
	private let tree: SourceFileSyntax
	private var result: ScannedFile

	static func scan(_ source: SourceFile) -> ScannedFile {
		var scanner = DeclarationScanner(source: source)
		scanner.run()
		return scanner.result
	}

	private init(source: SourceFile) {
		self.source = source
		tree = Parser.parse(source: source.text)
		converter = SourceLocationConverter(fileName: source.path, tree: tree)
		result = ScannedFile(source: source)
	}

	private mutating func run() {
		walk(tree.statements, conditions: [])
	}

	// MARK: - Walk

	private enum Enclosing {
		case type(String)
		case `extension`(String, isPublic: Bool)

		var name: String {
			switch self {
			case .type(let name), .extension(let name, _): name
			}
		}
	}

	private mutating func walk(_ statements: CodeBlockItemListSyntax, conditions: [ConditionTerm]) {
		for statement in statements {
			guard case .decl(let decl) = statement.item else { continue }
			if let importDecl = decl.as(ImportDeclSyntax.self) {
				recordImport(importDecl, conditions: conditions)
			} else if let ifConfig = decl.as(IfConfigDeclSyntax.self) {
				forEachClause(of: ifConfig, conditions: conditions) { scanner, elements, terms in
					if case .statements(let nested) = elements {
						scanner.walk(nested, conditions: terms)
					}
				}
			} else {
				visit(decl, enclosing: nil, conditional: !conditions.isEmpty)
			}
		}
	}

	private mutating func walkMembers(_ members: MemberBlockItemListSyntax, enclosing: Enclosing, conditional: Bool) {
		for member in members {
			if let ifConfig = member.decl.as(IfConfigDeclSyntax.self) {
				forEachClause(of: ifConfig, conditions: []) { scanner, elements, _ in
					if case .decls(let nested) = elements {
						scanner.walkMembers(nested, enclosing: enclosing, conditional: true)
					}
				}
			} else {
				visit(member.decl, enclosing: enclosing, conditional: conditional)
			}
		}
	}

	private mutating func visit(_ decl: DeclSyntax, enclosing: Enclosing?, conditional: Bool) {
		if let group = decl.asProtocol(DeclGroupSyntax.self), let kind = typeKind(of: decl) {
			visitType(group, decl: decl, kind: kind, enclosing: enclosing, conditional: conditional)
		} else if let extensionDecl = decl.as(ExtensionDeclSyntax.self) {
			let name = extensionDecl.extendedType.trimmedDescription
			result.extensions.append(ExtensionDecl(
				extendedName: name,
				initializers: initializers(in: extensionDecl.memberBlock.members),
				inheritedTypes: inheritedTypes(extensionDecl.inheritanceClause)
			))
			recordInitializerBodies(extensionDecl.memberBlock.members, typeName: name)
			let isPublic = extensionDecl.modifiers.contains { isPublicModifier($0) }
			walkMembers(extensionDecl.memberBlock.members, enclosing: .extension(name, isPublic: isPublic), conditional: conditional)
		} else if let variable = decl.as(VariableDeclSyntax.self),
		          SwiftBeansSyntaxRules.find(.contextInput, in: variable.attributes) != nil {
			result.hasContextFeatures = true
			if !result.children.contains(where: { $0.context.name == enclosing?.name }) {
				report(SwiftBeansSyntaxRules.contextInputViolations(variable, inChild: false))
			}
		} else if let function = decl.as(FunctionDeclSyntax.self),
		          let attribute = SwiftBeansSyntaxRules.find(.bean, in: function.attributes),
		          let enclosing
		{
			if conditional {
				result.conditionalDecls.append(position(function))
			} else {
				visitBean(function, attribute: attribute, enclosing: enclosing)
			}
		}
	}

	private mutating func visitType(
		_ group: some DeclGroupSyntax,
		decl: DeclSyntax,
		kind: TypeKind,
		enclosing: Enclosing?,
		conditional: Bool
	) {
		let simpleName = decl.asProtocol(NamedDeclSyntax.self)?.name.text ?? ""
		let name = enclosing.map { "\($0.name).\(simpleName)" } ?? simpleName
		let attributes = group.attributes
		let context = SwiftBeansSyntaxRules.find(.applicationContext, in: attributes)
		let child = SwiftBeansSyntaxRules.find(.childContext, in: attributes)
		let service = SwiftBeansSyntaxRules.find(.service, in: attributes)
		let configuration = SwiftBeansSyntaxRules.find(.configuration, in: attributes)
		let location = position(decl)

		if conditional, context != nil || child != nil || service != nil || configuration != nil {
			result.conditionalDecls.append(location)
		} else {
			if let context, SwiftBeansSyntaxRules.applicationContextViolations(decl, attribute: context).isEmpty {
				result.contexts.append(ContextDecl(name: name, simpleName: simpleName, location: location, isMainActor: SwiftBeansSyntaxRules.isMainActor(attributes)))
			}
			if let child {
				recordChild(group, decl: decl, attribute: child, name: name, simpleName: simpleName, location: location)
			}
			if let configuration, let owner = recordOwner(configuration, scope: enclosing?.name ?? "") {
				result.configurationOwners[name] = owner
			}
			if let service {
				if let owner = recordOwner(service, scope: enclosing?.name ?? "") { result.owners[location] = owner }
				recordService(decl, attribute: service, typeName: name, location: location)
			}
		}

		let members = group.memberBlock.members
		var memberwise: [ParameterInfo] = []
		var hasWrappedProperty = false
		if kind == .struct {
			(memberwise, hasWrappedProperty) = memberwiseParameters(members)
		}
		result.types.append(TypeDecl(
			name: name,
			kind: kind,
			isConfiguration: configuration != nil && !conditional,
			isPublic: group.modifiers.contains { isPublicModifier($0) },
			initializers: initializers(in: members),
			memberwise: memberwise,
			hasWrappedProperty: hasWrappedProperty,
			location: location,
			inheritedTypes: inheritedTypes(group.inheritanceClause)
		))
		recordMarkerProperties(members)
		recordInitializerBodies(members, typeName: name)
		walkMembers(members, enclosing: .type(name), conditional: conditional)
	}

	private mutating func report(_ violations: [Violation]) {
		for violation in violations {
			result.contextDiagnostics.append(GeneratorDiagnostic(id: violation.id, location: position(violation.node), message: violation.message))
		}
	}

	private mutating func recordOwner(_ attribute: AttributeSyntax, scope: String) -> OwnerReference? {
		guard let expression = SwiftBeansSyntaxRules.argument("in", of: attribute) else { return nil }
		result.hasContextFeatures = true
		switch SwiftBeansSyntaxRules.owner(of: attribute) {
		case .success(let name): return name.map { OwnerReference(name: $0, lexicalScope: scope, location: position(expression)) }
		case .failure(let violation): report([violation]); return nil
		}
	}

	private mutating func recordChild(_ group: some DeclGroupSyntax, decl: DeclSyntax, attribute: AttributeSyntax, name: String, simpleName: String, location: SourcePosition) {
		result.hasContextFeatures = true
		let violations = SwiftBeansSyntaxRules.childContextViolations(decl, attribute: attribute)
		report(violations)
		guard violations.isEmpty,
		      let expression = SwiftBeansSyntaxRules.argument("of", of: attribute),
		      let parent = SwiftBeansSyntaxRules.typeLiteral(expression) else { return }
		var inputs: [ContextInputDecl] = []
		for member in group.memberBlock.members {
			guard let variable = member.decl.as(VariableDeclSyntax.self),
			      SwiftBeansSyntaxRules.find(.contextInput, in: variable.attributes) != nil,
			      let binding = variable.bindings.first, let type = binding.typeAnnotation?.type else { continue }
			switch KeyNormalization.key(for: type) {
			case .success(let normalized):
				inputs.append(ContextInputDecl(name: binding.pattern.trimmedDescription, typeSpelling: type.trimmedDescription, key: BeanKey(normalized.key), emittedType: normalized.emittedType, spelledWithAny: normalized.spelledWithAny, location: position(binding)))
			case .failure(let reason):
				result.contextDiagnostics.append(GeneratorDiagnostic(id: "context.invalidInput", location: position(type), message: "unsupported context input: \(reason)"))
			}
		}
		result.children.append(ChildContextDecl(
			context: ContextDecl(name: name, simpleName: simpleName, location: location, isMainActor: SwiftBeansSyntaxRules.isMainActor(group.attributes)),
			parent: OwnerReference(name: parent, lexicalScope: name.components(separatedBy: ".").dropLast().joined(separator: "."), location: position(expression)),
			teardown: (try? SwiftBeansSyntaxRules.teardown(of: attribute).get()) ?? .arc,
			inputs: inputs
		))
	}

	/// `@Assisted` and `@Qualifier` belong on parameters; on a stored property they are errors.
	private mutating func recordMarkerProperties(_ members: MemberBlockItemListSyntax) {
		for member in members {
			guard let variable = member.decl.as(VariableDeclSyntax.self),
			      variable.bindings.contains(where: { isStored($0) })
			else { continue }
			for case .attribute(let attribute) in variable.attributes {
				if SwiftBeansSyntaxRules.isAssisted(attribute) {
					result.assistedPropertyLocations.append(position(attribute))
				} else if SwiftBeansSyntaxRules.isQualifier(attribute) {
					result.qualifierPropertyLocations.append(position(attribute))
				}
			}
		}
	}

	private mutating func recordService(_ decl: DeclSyntax, attribute: AttributeSyntax, typeName: String, location: SourcePosition) {
		// Wrong kind, generic types and bad names are the macro's errors; they cannot be wired.
		let skipped: Set<String> = ["service.wrongKind", "service.generic", "qualifier.notLiteral", "qualifier.invalidName"]
		guard !SwiftBeansSyntaxRules.serviceViolations(decl, attribute: attribute).contains(where: { skipped.contains($0.id) }) else {
			return
		}
		var boundTo: ServiceDecl.BoundTo?
		if let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
		   let argument = arguments.first(where: { $0.label?.text == "boundTo" })
		{
			var spelling = argument.expression.trimmedDescription
			if let member = argument.expression.as(MemberAccessExprSyntax.self),
			   member.declName.baseName.tokenKind == .keyword(.self),
			   let base = member.base
			{
				spelling = base.trimmedDescription
			}
			boundTo = (KeyNormalization.key(forSpelling: spelling), position(argument.expression), spelling)
		}
		result.services.append(ServiceDecl(
			typeName: typeName,
			scope: (try? SwiftBeansSyntaxRules.scope(of: attribute).get()) ?? .singleton,
			qualifier: try? SwiftBeansSyntaxRules.named(of: attribute).get(),
			scopeLocation: scopeLocation(of: attribute),
			boundTo: boundTo,
			location: location
		))
	}

	private mutating func visitBean(_ function: FunctionDeclSyntax, attribute: AttributeSyntax, enclosing: Enclosing) {
		// Without a return type, with generic parameters or a bad name there is no key; the macro reports it.
		let skipped: Set<String> = ["bean.noReturnType", "bean.generic", "qualifier.notLiteral", "qualifier.invalidName"]
		guard !SwiftBeansSyntaxRules.beanViolations(function, attribute: attribute).contains(where: { skipped.contains($0.id) }),
		      let returnType = function.signature.returnClause?.type
		else {
			return
		}
		if let owner = recordOwner(attribute, scope: enclosing.name) { result.owners[position(function)] = owner }
		var isPublic = function.modifiers.contains { isPublicModifier($0) }
		if case .extension(_, let extensionIsPublic) = enclosing, extensionIsPublic,
		   !function.modifiers.contains(where: { isRestrictingModifier($0) })
		{
			isPublic = true
		}
		result.beans.append(BeanDecl(
			enclosingName: enclosing.name,
			name: function.name.text,
			scope: (try? SwiftBeansSyntaxRules.scope(of: attribute).get()) ?? .singleton,
			qualifier: try? SwiftBeansSyntaxRules.named(of: attribute).get(),
			scopeLocation: scopeLocation(of: attribute),
			isPublic: isPublic,
			parameters: parameters(function.signature.parameterClause.parameters),
			returnKey: KeyNormalization.key(for: returnType),
			returnTypeLocation: position(returnType),
			returnSpelling: returnType.trimmedDescription,
			location: position(function),
			bodyCalls: function.body.map(calls(in:)) ?? []
		))
	}

	private mutating func recordInitializerBodies(_ members: MemberBlockItemListSyntax, typeName: String) {
		for member in members {
			guard let initializer = member.decl.as(InitializerDeclSyntax.self), let body = initializer.body else { continue }
			let calls = calls(in: body)
			if !calls.isEmpty {
				result.initializerBodies.append(InitializerBody(typeName: typeName, calls: calls))
			}
		}
	}

	private func calls(in body: CodeBlockSyntax) -> [CallSite] {
		let collector = CallCollector(viewMode: .sourceAccurate)
		collector.walk(body)
		return collector.calls.compactMap { call in
			let location = position(call)
			if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
				return CallSite(base: nil, name: reference.baseName.text, location: location)
			}
			if let member = call.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base {
				return CallSite(base: base.trimmedDescription, name: member.declName.baseName.text, location: location)
			}
			return nil
		}
	}

	/// The `scope:` argument, when it is a supported literal (a non-literal one is the macro's error).
	private func scopeLocation(of attribute: AttributeSyntax) -> SourcePosition? {
		guard case .success = SwiftBeansSyntaxRules.scope(of: attribute),
		      let argument = attribute.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == "scope" })
		else {
			return nil
		}
		return position(argument)
	}

	// MARK: - Initializers and parameters

	private func initializers(in members: MemberBlockItemListSyntax) -> [InitializerInfo] {
		members.compactMap { member in
			guard let initializer = member.decl.as(InitializerDeclSyntax.self) else { return nil }
			let modifiers = initializer.modifiers.map(\.name.tokenKind)
			let isHidden = modifiers.contains(.keyword(.private)) || modifiers.contains(.keyword(.fileprivate))
			let effects = initializer.signature.effectSpecifiers
			return InitializerInfo(
				location: position(initializer),
				isInject: SwiftBeansSyntaxRules.find(.inject, in: initializer.attributes) != nil,
				isPublic: initializer.modifiers.contains { isPublicModifier($0) },
				isCandidate: !isHidden && initializer.optionalMark == nil,
				hasEffects: effects?.asyncSpecifier != nil || effects?.throwsClause != nil,
				parameters: parameters(initializer.signature.parameterClause.parameters)
			)
		}
	}

	private func parameters(_ list: FunctionParameterListSyntax) -> [ParameterInfo] {
		list.map { parameter in
			let label = parameter.firstName.tokenKind == .wildcard ? nil : parameter.firstName.text
			let hasDefault = parameter.defaultValue != nil
			let isInout = parameter.type.as(AttributedTypeSyntax.self)?.specifiers.contains {
				$0.as(SimpleTypeSpecifierSyntax.self)?.specifier.tokenKind == .keyword(.inout)
			} == true
			return ParameterInfo(
				label: label,
				internalName: (parameter.secondName ?? parameter.firstName).text,
				hasDefault: hasDefault,
				location: position(parameter),
				typeLocation: position(parameter.type),
				key: KeyNormalization.key(for: keyType(parameter.type, hasDefault: hasDefault)),
				elementSpelledWithAny: KeyNormalization.elementSpelledWithAny(keyType(parameter.type, hasDefault: hasDefault)),
				typeSpelling: parameter.type.trimmedDescription,
				canonicalType: KeyNormalization.canonicalSpelling(of: parameter.type),
				factory: FactoryNormalization.factory(for: parameter.type),
				isAssisted: SwiftBeansSyntaxRules.isAssisted(parameter),
				qualifier: SwiftBeansSyntaxRules.qualifierAttribute(in: parameter.attributes).map(qualifierUse),
				isVariadic: parameter.ellipsis != nil,
				isInout: isInout,
				defaultLocation: parameter.defaultValue.map { position($0.value) }
			)
		}
	}

	/// Stored properties in declaration order, as memberwise parameters.
	private func memberwiseParameters(_ members: MemberBlockItemListSyntax) -> ([ParameterInfo], hasWrappedProperty: Bool) {
		var parameters: [ParameterInfo] = []
		var hasWrappedProperty = false
		for member in members {
			guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
			let modifiers = variable.modifiers.map(\.name.tokenKind)
			if modifiers.contains(.keyword(.static)) || modifiers.contains(.keyword(.class)) || modifiers.contains(.keyword(.lazy)) {
				continue
			}
			// `@Assisted` / `@Qualifier` on a property is reported by `recordMarkerProperties`; it is not a parameter.
			if variable.attributes.contains(where: { element in
				if case .attribute(let attribute) = element {
					return SwiftBeansSyntaxRules.isAssisted(attribute) || SwiftBeansSyntaxRules.isQualifier(attribute)
				}
				return false
			}) {
				continue
			}
			let isLet = variable.bindingSpecifier.tokenKind == .keyword(.let)
			for binding in variable.bindings {
				guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self), isStored(binding) else { continue }
				if !variable.attributes.isEmpty {
					hasWrappedProperty = true
				}
				let type = binding.typeAnnotation?.type
				// `let x = …` is not a memberwise parameter; `var x: T = …` and `var x: T?` are defaulted.
				if isLet, binding.initializer != nil { continue }
				let hasDefault = binding.initializer != nil
					|| (!isLet && type.map { KeyNormalization.optionalWrapped($0) != nil } == true)
				parameters.append(ParameterInfo(
					label: identifier.identifier.text,
					internalName: identifier.identifier.text,
					hasDefault: hasDefault,
					location: position(binding),
					typeLocation: type.map { position($0) } ?? position(binding),
					key: type.map { KeyNormalization.key(for: keyType($0, hasDefault: hasDefault)) },
					elementSpelledWithAny: type.map { KeyNormalization.elementSpelledWithAny(keyType($0, hasDefault: hasDefault)) } ?? false,
					typeSpelling: type?.trimmedDescription ?? "",
					canonicalType: type.map { KeyNormalization.canonicalSpelling(of: $0) } ?? "",
					factory: type.flatMap { FactoryNormalization.factory(for: $0) },
					isAssisted: false,
					qualifier: nil,
					isVariadic: false,
					isInout: false,
					defaultLocation: binding.initializer.map { position($0.value) }
				))
			}
		}
		return (parameters, hasWrappedProperty)
	}

	private func qualifierUse(_ attribute: AttributeSyntax) -> QualifierUse {
		QualifierUse(
			location: position(attribute),
			name: SwiftBeansSyntaxRules.qualifierName(of: attribute).mapError { violation in
				LocatedViolation(id: violation.id, message: violation.message, location: position(violation.node))
			}
		)
	}

	/// A defaulted `T?` parameter is looked up as `T`.
	private func keyType(_ type: TypeSyntax, hasDefault: Bool) -> TypeSyntax {
		if hasDefault, let wrapped = KeyNormalization.optionalWrapped(type) {
			return wrapped
		}
		return type
	}

	/// Entries that are not valid keys (e.g. compositions) can never match a collection element, so they are dropped.
	private func inheritedTypes(_ clause: InheritanceClauseSyntax?) -> [TypeKey] {
		clause?.inheritedTypes.compactMap { try? KeyNormalization.key(for: $0.type).get().key } ?? []
	}

	/// No accessor block, or only `willSet` / `didSet` observers.
	private func isStored(_ binding: PatternBindingSyntax) -> Bool {
		guard let accessorBlock = binding.accessorBlock else { return true }
		guard case .accessors(let accessors) = accessorBlock.accessors else { return false }
		return accessors.allSatisfy {
			$0.accessorSpecifier.tokenKind == .keyword(.willSet) || $0.accessorSpecifier.tokenKind == .keyword(.didSet)
		}
	}

	// MARK: - Imports

	private mutating func recordImport(_ importDecl: ImportDeclSyntax, conditions: [ConditionTerm]) {
		guard let module = importDecl.path.first?.name.text else { return }
		var testable = false
		var preconcurrency = false
		for case .attribute(let attribute) in importDecl.attributes {
			switch attribute.attributeName.trimmedDescription {
			case "testable": testable = true
			case "preconcurrency": preconcurrency = true
			default: break
			}
		}
		result.imports.append(ImportRecord(
			module: module,
			testable: testable,
			preconcurrency: preconcurrency,
			condition: ConditionTerm.render(conditions)
		))
	}

	/// Calls `body` for each clause with its effective condition: earlier clauses negated, then its own.
	private mutating func forEachClause(
		of ifConfig: IfConfigDeclSyntax,
		conditions: [ConditionTerm],
		_ body: (inout DeclarationScanner, IfConfigClauseSyntax.Elements?, [ConditionTerm]) -> Void
	) {
		var previous: [ConditionTerm] = []
		for clause in ifConfig.clauses {
			var terms = conditions + previous
			if let condition = clause.condition?.trimmedDescription {
				terms.append(ConditionTerm(expression: condition, negated: false))
				previous.append(ConditionTerm(expression: condition, negated: true))
			}
			body(&self, clause.elements, terms)
		}
	}

	// MARK: - Helpers

	private func typeKind(of decl: DeclSyntax) -> TypeKind? {
		if decl.is(ClassDeclSyntax.self) { return .class }
		if decl.is(StructDeclSyntax.self) { return .struct }
		if decl.is(ActorDeclSyntax.self) { return .actor }
		if decl.is(EnumDeclSyntax.self) { return .enum }
		if decl.is(ProtocolDeclSyntax.self) { return .protocol }
		return nil
	}

	private func isPublicModifier(_ modifier: DeclModifierSyntax) -> Bool {
		modifier.name.tokenKind == .keyword(.public) || modifier.name.tokenKind == .keyword(.open)
	}

	private func isRestrictingModifier(_ modifier: DeclModifierSyntax) -> Bool {
		[.keyword(.internal), .keyword(.private), .keyword(.fileprivate), .keyword(.package)].contains(modifier.name.tokenKind)
	}

	private func position(_ node: some SyntaxProtocol) -> SourcePosition {
		let location = node.startLocation(converter: converter)
		return SourcePosition(file: source.path, line: location.line, column: location.column)
	}
}

extension ServiceDecl {
	typealias BoundTo = (key: Result<KeyNormalization.Normalized, UnsupportedKey>, location: SourcePosition, spelling: String)
}

/// One part of a `#if` condition.
struct ConditionTerm {
	var expression: String
	var negated: Bool

	/// `a` alone; otherwise `(a) && !(b)`. `nil` when there are no terms.
	static func render(_ terms: [ConditionTerm]) -> String? {
		if terms.isEmpty { return nil }
		if terms.count == 1, !terms[0].negated { return terms[0].expression }
		return terms.map { $0.negated ? "!(\($0.expression))" : "(\($0.expression))" }.joined(separator: " && ")
	}
}

/// Collects call expressions, without entering nested type declarations.
private final class CallCollector: SyntaxVisitor {
	private(set) var calls: [FunctionCallExprSyntax] = []

	override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
		calls.append(node)
		return .visitChildren
	}

	override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}
