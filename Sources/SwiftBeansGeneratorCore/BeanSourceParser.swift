import SwiftBeans
import SwiftParser
import SwiftSyntax

/// Parses annotated Swift sources into providers and application context names.
public enum BeanSourceParser {
	public static func parseProviders(fromSources sources: [String]) throws -> [BeanProvider] {
		var providers: [BeanProvider] = []
		for source in sources {
			let tree = Parser.parse(source: source)
			providers.append(contentsOf: try collectProviders(in: tree))
		}
		return providers
	}

	public static func parseApplicationContextNames(fromSources sources: [String]) throws -> [String] {
		var names: [String] = []
		for source in sources {
			let tree = Parser.parse(source: source)
			names.append(contentsOf: collectApplicationContexts(in: tree))
		}
		return names
	}

	public static func buildGraph(fromSources sources: [String]) throws -> BeanGraph {
		let contexts = try parseApplicationContextNames(fromSources: sources)
		guard !contexts.isEmpty else {
			throw BeanGraphError.noApplicationContext
		}
		guard contexts.count == 1 else {
			throw BeanGraphError.multipleApplicationContexts(contexts.sorted())
		}
		let providers = try parseProviders(fromSources: sources)
		return try BeanGraphValidator.validate(providers: providers, contextTypeName: contexts[0])
	}

	// MARK: - Walk

	private static func collectApplicationContexts(in tree: SourceFileSyntax) -> [String] {
		var names: [String] = []
		for statement in tree.statements {
			guard let classDecl = statement.item.as(ClassDeclSyntax.self),
			      hasAttribute(named: "ApplicationContext", on: classDecl.attributes)
			else {
				continue
			}
			names.append(classDecl.name.text)
		}
		return names
	}

	private static func collectProviders(in tree: SourceFileSyntax) throws -> [BeanProvider] {
		var providers: [BeanProvider] = []
		for statement in tree.statements {
			if let typeDecl = statement.item.as(ClassDeclSyntax.self) {
				providers.append(contentsOf: try providersFromService(typeDecl))
				providers.append(contentsOf: try providersFromConfiguration(typeDecl))
			} else if let enumDecl = statement.item.as(EnumDeclSyntax.self) {
				providers.append(contentsOf: try providersFromConfiguration(enumDecl))
			} else if let structDecl = statement.item.as(StructDeclSyntax.self) {
				providers.append(contentsOf: try providersFromConfiguration(structDecl))
				providers.append(contentsOf: try providersFromService(structDecl))
			}
		}
		return providers
	}

	private static func providersFromService(_ declaration: some DeclGroupSyntax & NamedDeclSyntax) throws -> [BeanProvider] {
		guard let serviceAttr = findAttribute(named: "Service", in: declaration.attributes) else {
			return []
		}
		let scope = parseScope(from: serviceAttr) ?? .singleton
		let boundTo = parseBoundToTypeName(from: serviceAttr)
		let typeName = declaration.name.text
		let keyType = boundTo ?? typeName
		let initParams = primaryInitParameters(in: declaration)
		let dependencies = initParams.map { InjectableKey(typeName: $0.typeName) }
		return [
			BeanProvider(
				key: InjectableKey(typeName: keyType),
				dependencies: dependencies,
				scope: scope,
				sourceName: typeName,
				factory: .service(typeName: typeName, parameters: initParams)
			),
		]
	}

	private static func providersFromConfiguration(_ declaration: some DeclGroupSyntax & NamedDeclSyntax) throws -> [BeanProvider] {
		guard hasAttribute(named: "Configuration", on: declaration.attributes) else {
			return []
		}
		let configurationType = declaration.name.text
		var providers: [BeanProvider] = []
		for member in declaration.memberBlock.members {
			guard let function = member.decl.as(FunctionDeclSyntax.self),
			      let beanAttr = findAttribute(named: "Bean", in: function.attributes)
			else {
				continue
			}
			guard function.modifiers.contains(where: { $0.name.text == "static" }) else {
				continue
			}
			guard let returnType = function.signature.returnClause?.type.trimmedDescription else {
				continue
			}
			let scope = parseScope(from: beanAttr) ?? .singleton
			let parameters = functionParameters(function.signature.parameterClause.parameters)
			let dependencies = parameters.map { InjectableKey(typeName: $0.typeName) }
			providers.append(
				BeanProvider(
					key: InjectableKey(typeName: returnType),
					dependencies: dependencies,
					scope: scope,
					sourceName: "\(configurationType).\(function.name.text)",
					factory: .bean(
						configurationType: configurationType,
						methodName: function.name.text,
						parameters: parameters
					)
				)
			)
		}
		return providers
	}

	// MARK: - Attributes / params

	private static func hasAttribute(named name: String, on attributes: AttributeListSyntax) -> Bool {
		findAttribute(named: name, in: attributes) != nil
	}

	private static func findAttribute(named name: String, in attributes: AttributeListSyntax) -> AttributeSyntax? {
		for element in attributes {
			guard case .attribute(let attribute) = element else { continue }
			if attribute.attributeName.trimmedDescription == name {
				return attribute
			}
		}
		return nil
	}

	private static func parseScope(from attribute: AttributeSyntax) -> BeanScope? {
		guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
			return nil
		}
		for argument in arguments where argument.label?.text == "scope" {
			let text = argument.expression.trimmedDescription
			if text.hasSuffix("singleton") { return .singleton }
			if text.hasSuffix("transient") { return .transient }
		}
		return nil
	}

	private static func parseBoundToTypeName(from attribute: AttributeSyntax) -> String? {
		guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
			return nil
		}
		for argument in arguments where argument.label?.text == "boundTo" {
			let expression = argument.expression.trimmedDescription
			// `APIClient.self` → `APIClient`
			if expression.hasSuffix(".self") {
				return String(expression.dropLast(5))
			}
			return expression
		}
		return nil
	}

	private static func primaryInitParameters(in declaration: some DeclGroupSyntax) -> [BeanParameter] {
		for member in declaration.memberBlock.members {
			guard let initializer = member.decl.as(InitializerDeclSyntax.self) else { continue }
			return functionParameters(initializer.signature.parameterClause.parameters)
		}
		return []
	}

	private static func functionParameters(_ parameters: FunctionParameterListSyntax) -> [BeanParameter] {
		parameters.map { parameter in
			let label: String
			if parameter.firstName.text == "_" {
				label = "_"
			} else {
				label = parameter.firstName.text
			}
			return BeanParameter(label: label, typeName: parameter.type.trimmedDescription)
		}
	}
}
