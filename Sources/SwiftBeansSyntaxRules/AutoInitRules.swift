// The single source of truth for `@Service(..., autoInit: true)`.
//
// `autoInitModel` decides which stored properties become initializer parameters and how each is
// spelled. The service macro emits `model.initializer`; the generator's scanner turns the same
// initializer's signature into its `InitializerInfo`, so both sides agree by construction.
// See specs/service-auto-init/ARCHITECTURE.md.

import SwiftSyntax

/// One generated-init parameter, derived from one stored-property binding.
public struct AutoInitParameter {
	/// The property identifier: both the label and the internal name.
	public var name: TokenSyntax
	/// The property's type as written (trimmed).
	public var type: TypeSyntax
	/// The binding, for generator diagnostics (missing dependency, `qualifier.assisted`).
	public var binding: PatternBindingSyntax
	/// `var x: T?` / `Optional<T>` without a value; rendered `= nil`.
	public var defaultsToNil: Bool
	/// A syntactic function type (possibly attributed or parenthesized); rendered with `@escaping`.
	public var isEscapingFunction: Bool
	/// The property's `@Assisted` / `@Qualifier(…)` attributes, copied onto the parameter.
	public var assisted: AttributeSyntax?
	public var qualifier: AttributeSyntax?
}

/// The rule violations that stop an initializer from being generated (an array is not an `Error`).
public struct AutoInitViolations: Error {
	public var violations: [Violation]
}

public struct AutoInitModel {
	/// `public` (for `public`/`open`), `package`, or `nil` for no modifier.
	public var accessModifier: Keyword?
	public var parameters: [AutoInitParameter]

	/// The emitted declaration, rendered from the fields above. The macro returns it, and the generator
	/// reads its signature.
	public var initializer: InitializerDeclSyntax {
		var modifiers = DeclModifierListSyntax()
		if let accessModifier {
			modifiers = [DeclModifierSyntax(name: .keyword(accessModifier, trailingTrivia: .space))]
		}
		let list = FunctionParameterListSyntax(
			parameters.enumerated().map { index, parameter in
				parameter.rendered(isLast: index == parameters.count - 1)
			})
		let statements = CodeBlockItemListSyntax(
			parameters.map { parameter in
				let target = MemberAccessExprSyntax(
					base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
					declName: DeclReferenceExprSyntax(baseName: parameter.name.trimmed))
				let assignment = AssignmentExprSyntax(equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space))
				let value = DeclReferenceExprSyntax(baseName: parameter.name.trimmed)
				return CodeBlockItemSyntax(
					leadingTrivia: [.newlines(1), .tabs(1)],
					item: .expr(
						ExprSyntax(
							SequenceExprSyntax(elements: [ExprSyntax(target), ExprSyntax(assignment), ExprSyntax(value)]))))
			})
		return InitializerDeclSyntax(
			modifiers: modifiers,
			signature: FunctionSignatureSyntax(
				parameterClause: FunctionParameterClauseSyntax(parameters: list)),
			body: CodeBlockSyntax(
				leftBrace: .leftBraceToken(leadingTrivia: .space),
				statements: statements,
				rightBrace: .rightBraceToken(leadingTrivia: parameters.isEmpty ? [] : .newline)))
	}
}

extension AutoInitParameter {
	fileprivate func rendered(isLast: Bool) -> FunctionParameterSyntax {
		var attributes = AttributeListSyntax()
		for marker in [assisted, qualifier].compactMap({ $0 }) {
			attributes.append(.attribute(marker.trimmed.with(\.trailingTrivia, .space)))
		}
		var renderedType = type.trimmed
		if isEscapingFunction {
			let escaping = AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("escaping")))
				.with(\.trailingTrivia, .space)
			if let attributed = renderedType.as(AttributedTypeSyntax.self) {
				var list = AttributeListSyntax([.attribute(escaping)])
				list.append(contentsOf: attributed.attributes)
				renderedType = TypeSyntax(attributed.with(\.attributes, list))
			} else {
				renderedType = TypeSyntax(AttributedTypeSyntax(specifiers: [], attributes: [.attribute(escaping)], baseType: renderedType))
			}
		}
		return FunctionParameterSyntax(
			attributes: attributes,
			firstName: name.trimmed,
			colon: .colonToken(trailingTrivia: .space),
			type: renderedType,
			defaultValue: defaultsToNil
				? InitializerClauseSyntax(
					equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
					value: NilLiteralExprSyntax(nilKeyword: .keyword(.nil)))
				: nil,
			trailingComma: isLast ? nil : .commaToken(trailingTrivia: .space))
	}
}

extension SwiftBeansSyntaxRules {
	/// `false` when `autoInit:` is absent. `service.autoInit` when it is not a Boolean literal.
	public static func autoInit(of attribute: AttributeSyntax) -> Result<Bool, Violation> {
		guard let expression = argument("autoInit", of: attribute) else { return .success(false) }
		if let literal = expression.as(BooleanLiteralExprSyntax.self) {
			return .success(literal.literal.tokenKind == .keyword(.true))
		}
		return .failure(
			Violation(
				id: "service.autoInit", message: "autoInit must be the literal true or false",
				node: Syntax(expression)))
	}

	/// Inclusion rules (SPEC "Generated initializer" 1–8) plus the rejected forms
	/// `autoInit.existingInit`, `autoInit.propertyAttribute`, `autoInit.pattern` and `autoInit.missingType`.
	/// It never fails with an empty array.
	public static func autoInitModel(_ declaration: some DeclGroupSyntax) -> Result<AutoInitModel, AutoInitViolations> {
		var violations: [Violation] = []
		var parameters: [AutoInitParameter] = []
		var reportedExistingInit = false

		for member in declaration.memberBlock.members {
			if let initializer = member.decl.as(InitializerDeclSyntax.self) {
				if !reportedExistingInit {
					reportedExistingInit = true
					violations.append(
						Violation(
							id: "autoInit.existingInit",
							message:
								"'autoInit: true' generates the initializer; remove this initializer or remove 'autoInit: true'",
							node: Syntax(initializer.initKeyword)))
				}
				continue
			}
			guard let variable = member.decl.as(VariableDeclSyntax.self), !isTypeLevelOrLazy(variable) else {
				continue
			}
			let isVar = variable.bindingSpecifier.tokenKind == .keyword(.var)
			var checkedAttributes = false
			for binding in variable.bindings where isStored(binding) && binding.initializer == nil {
				if !checkedAttributes {
					checkedAttributes = true
					for element in variable.attributes {
						if case .attribute(let attribute) = element, isAllowedPropertyAttribute(attribute) { continue }
						violations.append(
							Violation(
								id: "autoInit.propertyAttribute",
								message:
									"'autoInit: true' cannot copy this attribute onto an initializer parameter; declare an initializer instead",
								node: Syntax(element)))
					}
				}
				guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
					violations.append(
						Violation(
							id: "autoInit.pattern",
							message:
								"'autoInit: true' needs each stored property to be a single named binding such as 'let name: Type'",
							node: Syntax(binding.pattern)))
					continue
				}
				guard let type = binding.typeAnnotation?.type else {
					violations.append(
						Violation(
							id: "autoInit.missingType",
							message:
								"'autoInit: true' needs a type annotation on stored property '\(identifier.identifier.text)'",
							node: Syntax(binding)))
					continue
				}
				var assisted: AttributeSyntax?
				var qualifier: AttributeSyntax?
				for case .attribute(let attribute) in variable.attributes {
					if assisted == nil, isAssisted(attribute) { assisted = attribute }
					if qualifier == nil, isQualifier(attribute) { qualifier = attribute }
				}
				parameters.append(
					AutoInitParameter(
						name: identifier.identifier,
						type: type.trimmed,
						binding: binding,
						defaultsToNil: isVar && isOptional(type),
						isEscapingFunction: isFunctionType(type),
						assisted: assisted,
						qualifier: qualifier))
			}
		}
		if !violations.isEmpty { return .failure(AutoInitViolations(violations: violations)) }
		return .success(AutoInitModel(accessModifier: accessModifier(of: declaration.modifiers), parameters: parameters))
	}

	/// `assisted.property` / `qualifier.property` placement, plus the qualifier-name rules for `@Qualifier`.
	/// Only the marker macros call this; `enclosing` is `context.lexicalContext.first`.
	public static func propertyMarkerViolations(
		_ declaration: some DeclSyntaxProtocol,
		attribute: AttributeSyntax,
		enclosing: Syntax?
	) -> [Violation] {
		// `@Observable` copies a property's attributes onto its `@ObservationIgnored` backing property
		// (`_name`), and the compiler expands them there with no lexical context. The original property is
		// validated separately, so only that exact shape is exempt.
		if enclosing == nil, let variable = declaration.as(VariableDeclSyntax.self),
			variable.attributes.contains(where: {
				$0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ObservationIgnored"
			}),
			variable.bindings.allSatisfy({
				$0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text.hasPrefix("_") == true
			})
		{
			return []
		}
		var violations: [Violation] = []
		let isAssistedMarker = isAssisted(attribute)
		if !isValidMarkerPlacement(declaration, enclosing: enclosing) {
			let name = isAssistedMarker ? "Assisted" : "Qualifier"
			violations.append(
				Violation(
					id: isAssistedMarker ? "assisted.property" : "qualifier.property",
					message:
						"@\(name) on a stored property requires '@Service(autoInit: true)' on the enclosing type; add 'autoInit: true' to the @Service, or mark the initializer parameter instead",
					node: Syntax(attribute)))
		}
		if isQualifier(attribute), case .failure(let violation) = qualifierName(of: attribute) {
			violations.append(violation)
		}
		return violations
	}

	// MARK: - Helpers

	private static func isTypeLevelOrLazy(_ variable: VariableDeclSyntax) -> Bool {
		variable.modifiers.contains {
			[.keyword(.static), .keyword(.class), .keyword(.lazy)].contains($0.name.tokenKind)
		}
	}

	/// No accessor block, or only `willSet` / `didSet` observers.
	private static func isStored(_ binding: PatternBindingSyntax) -> Bool {
		guard let accessorBlock = binding.accessorBlock else { return true }
		guard case .accessors(let accessors) = accessorBlock.accessors else { return false }
		return accessors.allSatisfy {
			$0.accessorSpecifier.tokenKind == .keyword(.willSet)
				|| $0.accessorSpecifier.tokenKind == .keyword(.didSet)
		}
	}

	private static func accessModifier(of modifiers: DeclModifierListSyntax) -> Keyword? {
		for modifier in modifiers where modifier.detail == nil {
			switch modifier.name.tokenKind {
			case .keyword(.public), .keyword(.open): return .public
			case .keyword(.package): return .package
			default: continue
			}
		}
		return nil
	}

	/// `@ObservationIgnored`, `@available` and the SwiftBeans markers (bare or module-qualified).
	private static func isAllowedPropertyAttribute(_ attribute: AttributeSyntax) -> Bool {
		if isAssisted(attribute) || isQualifier(attribute) { return true }
		if let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) {
			return ["ObservationIgnored", "available"].contains(identifier.name.text)
		}
		if let member = attribute.attributeName.as(MemberTypeSyntax.self),
			member.baseType.as(IdentifierTypeSyntax.self)?.name.text == "Observation"
		{
			return member.name.text == "ObservationIgnored"
		}
		return false
	}

	/// `T?`, `Optional<T>` or `Swift.Optional<T>`.
	private static func isOptional(_ type: TypeSyntax) -> Bool {
		if type.is(OptionalTypeSyntax.self) { return true }
		if let identifier = type.as(IdentifierTypeSyntax.self) {
			return identifier.name.text == "Optional" && identifier.genericArgumentClause?.arguments.count == 1
		}
		if let member = type.as(MemberTypeSyntax.self) {
			return member.name.text == "Optional"
				&& member.baseType.as(IdentifierTypeSyntax.self)?.name.text == "Swift"
				&& member.genericArgumentClause?.arguments.count == 1
		}
		return false
	}

	/// A function type, possibly attributed or wrapped in one pair of parentheses. Optionals are not.
	private static func isFunctionType(_ type: TypeSyntax) -> Bool {
		if type.is(FunctionTypeSyntax.self) { return true }
		if let attributed = type.as(AttributedTypeSyntax.self) { return isFunctionType(attributed.baseType) }
		if let tuple = type.as(TupleTypeSyntax.self), tuple.elements.count == 1, let element = tuple.elements.first,
			element.firstName == nil
		{
			return isFunctionType(element.type)
		}
		return false
	}

	private static func isValidMarkerPlacement(_ declaration: some DeclSyntaxProtocol, enclosing: Syntax?) -> Bool {
		guard let variable = declaration.as(VariableDeclSyntax.self), !isTypeLevelOrLazy(variable),
			variable.bindings.allSatisfy({ isStored($0) }), let enclosing
		else { return false }
		let attributes: AttributeListSyntax
		if let type = enclosing.as(ClassDeclSyntax.self) {
			attributes = type.attributes
		} else if let type = enclosing.as(StructDeclSyntax.self) {
			attributes = type.attributes
		} else if let type = enclosing.as(ActorDeclSyntax.self) {
			attributes = type.attributes
		} else {
			return false
		}
		guard let service = find(.service, in: attributes) else { return false }
		if case .success(true) = autoInit(of: service) { return true }
		return false
	}
}
