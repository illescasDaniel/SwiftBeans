// Declaration-local SwiftBeans rules shared by the macros and the generator.
//
// The macros report each `Violation` as a positioned diagnostic. The generator runs the same
// rules and never reports them (the macro already fails the build), so nothing is reported twice.
// See specs/compile-time-di/ARCHITECTURE.md → SwiftBeansSyntaxRules.

import SwiftSyntax

/// A SwiftBeans attribute recognized on a declaration.
public enum SwiftBeansAttribute: String, Sendable, CaseIterable {
	case applicationContext = "ApplicationContext"
	case configuration = "Configuration"
	case bean = "Bean"
	case service = "Service"
	case inject = "Inject"
}

/// Build-time value of a `scope:` argument.
public enum ScopeLiteral: String, Sendable, Equatable {
	case singleton
	case transient
}

/// One broken rule, located at the syntax node a diagnostic should point at.
public struct Violation: Error, Equatable {
	/// Stable identifier, e.g. `bean.notStatic`.
	public var id: String
	public var message: String
	public var node: Syntax

	public init(id: String, message: String, node: Syntax) {
		self.id = id
		self.message = message
		self.node = node
	}
}

public enum SwiftBeansSyntaxRules {
	/// `@Service` / `@SwiftBeans.Service` → `.service`; `@Other.Service` or unknown names → `nil`.
	public static func attribute(_ attribute: AttributeSyntax) -> SwiftBeansAttribute? {
		swiftBeansName(of: attribute).flatMap { SwiftBeansAttribute(rawValue: $0) }
	}

	/// `Assisted`, `SwiftBeans.Assisted`; `@Other.Assisted` → false. Generic arguments are not part of an attribute name.
	public static func isAssisted(_ attribute: AttributeSyntax) -> Bool {
		swiftBeansName(of: attribute) == "Assisted"
	}

	/// True when any attribute on the parameter is `@Assisted` / `@SwiftBeans.Assisted`.
	public static func isAssisted(_ parameter: FunctionParameterSyntax) -> Bool {
		parameter.attributes.contains { element in
			if case .attribute(let attribute) = element { return isAssisted(attribute) }
			return false
		}
	}

	/// The attribute's name when it is written bare or qualified with `SwiftBeans`.
	private static func swiftBeansName(of attribute: AttributeSyntax) -> String? {
		let type = attribute.attributeName
		if let identifier = type.as(IdentifierTypeSyntax.self) {
			return identifier.name.text
		}
		if let member = type.as(MemberTypeSyntax.self),
		   member.baseType.as(IdentifierTypeSyntax.self)?.name.text == "SwiftBeans"
		{
			return member.name.text
		}
		return nil
	}

	/// The first SwiftBeans attribute of `kind` in `attributes`, if any.
	public static func find(_ kind: SwiftBeansAttribute, in attributes: AttributeListSyntax) -> AttributeSyntax? {
		for element in attributes {
			if case .attribute(let candidate) = element, attribute(candidate) == kind {
				return candidate
			}
		}
		return nil
	}

	/// `.singleton` when `scope:` is absent; a violation when it is not a supported literal.
	public static func scope(of attribute: AttributeSyntax) -> Result<ScopeLiteral, Violation> {
		guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
		      let argument = arguments.first(where: { $0.label?.text == "scope" })
		else {
			return .success(.singleton)
		}
		if let member = argument.expression.as(MemberAccessExprSyntax.self),
		   let literal = ScopeLiteral(rawValue: member.declName.baseName.text),
		   member.declName.argumentNames == nil,
		   isScopeBase(member.base)
		{
			return .success(literal)
		}
		return .failure(Violation(
			id: "scope.notLiteral",
			message: "scope must be '.singleton' or '.transient'",
			node: Syntax(argument.expression)
		))
	}

	public static func beanViolations(_ declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) -> [Violation] {
		guard let function = declaration.as(FunctionDeclSyntax.self) else {
			return [Violation(
				id: "bean.notFunction",
				message: "@Bean can only be applied to a static function",
				node: Syntax(attribute)
			)]
		}
		var violations: [Violation] = []
		if !function.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) {
			violations.append(Violation(id: "bean.notStatic", message: "@Bean methods must be static", node: Syntax(function.funcKeyword)))
		}
		if function.signature.returnClause == nil {
			violations.append(Violation(
				id: "bean.noReturnType",
				message: "@Bean methods must declare a return type",
				node: Syntax(function.name)
			))
		}
		if let generics = function.genericParameterClause {
			violations.append(Violation(id: "bean.generic", message: "@Bean methods cannot be generic", node: Syntax(generics)))
		}
		let effects = function.signature.effectSpecifiers
		if let async = effects?.asyncSpecifier {
			violations.append(Violation(
				id: "bean.async",
				message: "@Bean methods cannot be async; generated accessors are synchronous",
				node: Syntax(async)
			))
		}
		if let throwsSpecifier = effects?.throwsClause?.throwsSpecifier {
			violations.append(Violation(
				id: "bean.throws",
				message: "@Bean methods cannot throw; generated accessors are non-throwing",
				node: Syntax(throwsSpecifier)
			))
		}
		if case .failure(let violation) = scope(of: attribute) {
			violations.append(violation)
		}
		return violations
	}

	public static func serviceViolations(_ declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) -> [Violation] {
		let generics: GenericParameterClauseSyntax?
		if let decl = declaration.as(ClassDeclSyntax.self) {
			generics = decl.genericParameterClause
		} else if let decl = declaration.as(StructDeclSyntax.self) {
			generics = decl.genericParameterClause
		} else if let decl = declaration.as(ActorDeclSyntax.self) {
			generics = decl.genericParameterClause
		} else {
			return [Violation(
				id: "service.wrongKind",
				message: "@Service can only be applied to a class, struct or actor",
				node: Syntax(attribute)
			)]
		}
		var violations: [Violation] = []
		if let generics {
			violations.append(Violation(id: "service.generic", message: "@Service types cannot be generic", node: Syntax(generics)))
		}
		if case .failure(let violation) = scope(of: attribute) {
			violations.append(violation)
		}
		return violations
	}

	public static func configurationViolations(_ declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) -> [Violation] {
		if declaration.is(EnumDeclSyntax.self) || declaration.is(StructDeclSyntax.self)
			|| declaration.is(ClassDeclSyntax.self) || declaration.is(ActorDeclSyntax.self)
		{
			return []
		}
		return [Violation(
			id: "configuration.wrongKind",
			message: "@Configuration can only be applied to an enum, struct, class or actor",
			node: Syntax(attribute)
		)]
	}

	public static func applicationContextViolations(_ declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) -> [Violation] {
		if declaration.is(ClassDeclSyntax.self) {
			return []
		}
		return [Violation(
			id: "context.notClass",
			message: "@ApplicationContext can only be applied to a class",
			node: Syntax(attribute)
		)]
	}

	public static func injectViolations(_ declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax) -> [Violation] {
		if declaration.is(InitializerDeclSyntax.self) {
			return []
		}
		return [Violation(
			id: "inject.notInitializer",
			message: "@Inject can only be applied to an initializer",
			node: Syntax(attribute)
		)]
	}

	/// `nil` (`.singleton`), `BeanScope` or `SwiftBeans.BeanScope`.
	private static func isScopeBase(_ base: ExprSyntax?) -> Bool {
		guard let base else { return true }
		if let reference = base.as(DeclReferenceExprSyntax.self) {
			return reference.baseName.text == "BeanScope"
		}
		if let member = base.as(MemberAccessExprSyntax.self),
		   member.declName.baseName.text == "BeanScope",
		   member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "SwiftBeans"
		{
			return true
		}
		return false
	}
}
