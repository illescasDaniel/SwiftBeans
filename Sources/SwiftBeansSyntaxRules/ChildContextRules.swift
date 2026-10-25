import SwiftSyntax

public enum TeardownLiteral: String, Sendable {
	case arc
	case managed
}

extension SwiftBeansSyntaxRules {
	public static func typeLiteral(_ expression: ExprSyntax) -> String? {
		guard let member = expression.as(MemberAccessExprSyntax.self),
			member.declName.baseName.tokenKind == .keyword(.self), let base = member.base
		else { return nil }
		func isName(_ node: ExprSyntax) -> Bool {
			if node.is(DeclReferenceExprSyntax.self) { return true }
			if let member = node.as(MemberAccessExprSyntax.self), let base = member.base {
				return member.declName.argumentNames == nil && isName(base)
			}
			return false
		}
		return isName(base) ? base.trimmedDescription : nil
	}

	public static func argument(_ label: String, of attribute: AttributeSyntax) -> ExprSyntax? {
		attribute.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == label })?
			.expression
	}

	public static func owner(of attribute: AttributeSyntax) -> Result<String?, Violation> {
		guard let expression = argument("in", of: attribute) else { return .success(nil) }
		guard let name = typeLiteral(expression) else {
			return .failure(
				Violation(
					id: "context.ownerNotLiteral",
					message: "in: must name a context type, for example SessionContext.self",
					node: Syntax(expression)))
		}
		return .success(name)
	}

	public static func teardown(of attribute: AttributeSyntax) -> Result<TeardownLiteral, Violation> {
		guard let expression = argument("teardown", of: attribute) else { return .success(.arc) }
		if let member = expression.as(MemberAccessExprSyntax.self),
			member.declName.argumentNames == nil,
			let value = TeardownLiteral(rawValue: member.declName.baseName.text),
			member.base == nil
				|| ["ChildContextTeardown", "SwiftBeans.ChildContextTeardown"].contains(
					member.base!.trimmedDescription)
		{
			return .success(value)
		}
		return .failure(
			Violation(
				id: "context.teardownNotLiteral", message: "teardown must be .arc or .managed",
				node: Syntax(expression)))
	}

	public static func isMainActor(_ attributes: AttributeListSyntax) -> Bool {
		attributes.contains { element in
			guard case .attribute(let attribute) = element else { return false }
			return ["MainActor", "_Concurrency.MainActor", "Swift.MainActor"].contains(
				attribute.attributeName.trimmedDescription)
		}
	}

	public static func contextInputViolations(_ declaration: some DeclSyntaxProtocol, inChild: Bool) -> [Violation]
	{
		guard inChild else {
			return [
				Violation(
					id: "context.inputOutsideChild",
					message: "@ContextInput is only supported inside @ChildContext",
					node: Syntax(declaration))
			]
		}
		guard let variable = declaration.as(VariableDeclSyntax.self),
			variable.bindingSpecifier.tokenKind == .keyword(.let), variable.bindings.count == 1,
			let binding = variable.bindings.first, binding.pattern.is(IdentifierPatternSyntax.self),
			let type = binding.typeAnnotation?.type, binding.initializer == nil,
			binding.accessorBlock == nil,
			!variable.modifiers.contains(where: {
				[.keyword(.static), .keyword(.class)].contains($0.name.tokenKind)
			}),
			!type.is(OptionalTypeSyntax.self), !type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
		else {
			return [
				Violation(
					id: "context.invalidInput",
					message:
						"@ContextInput requires one stored instance let with an explicit nonoptional type and no default",
					node: Syntax(declaration))
			]
		}
		let name = binding.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
		if name == "parent" || name.hasPrefix("_swiftBeans") {
			return [
				Violation(
					id: "context.reservedName", message: "context input name '\(name)' is reserved",
					node: Syntax(binding.pattern))
			]
		}
		return []
	}

	public static func childContextViolations(_ declaration: some DeclSyntaxProtocol, attribute: AttributeSyntax)
		-> [Violation]
	{
		guard let type = declaration.as(ClassDeclSyntax.self) else {
			return [
				Violation(
					id: "context.notClass", message: "@ChildContext requires a final class",
					node: Syntax(attribute))
			]
		}
		var result: [Violation] = []
		if !type.modifiers.contains(where: { $0.name.tokenKind == .keyword(.final) }) {
			result.append(
				Violation(
					id: "context.notFinal", message: "@ChildContext classes must be final",
					node: Syntax(type.classKeyword)))
		}
		if let generics = type.genericParameterClause {
			result.append(
				Violation(
					id: "context.generic", message: "@ChildContext cannot be generic",
					node: Syntax(generics)))
		}
		if argument("of", of: attribute).flatMap(typeLiteral) == nil {
			result.append(
				Violation(
					id: "context.invalidParent", message: "of: must name a parent context type",
					node: Syntax(attribute)))
		}
		if case .failure(let violation) = teardown(of: attribute) { result.append(violation) }
		let managed = (try? teardown(of: attribute).get()) == .managed
		if managed && !isMainActor(type.attributes) {
			result.append(
				Violation(
					id: "context.managedIsolation",
					message: "managed child contexts require explicit @MainActor",
					node: Syntax(attribute)))
		}
		for member in type.memberBlock.members {
			if member.decl.is(InitializerDeclSyntax.self) {
				result.append(
					Violation(
						id: "context.customInitializer",
						message:
							"@ChildContext owns its initializer; remove the handwritten initializer",
						node: Syntax(member.decl)))
			}
			if let variable = member.decl.as(VariableDeclSyntax.self) {
				if find(.contextInput, in: variable.attributes) != nil {
					result += contextInputViolations(variable, inChild: true)
				}
				for binding in variable.bindings {
					let name =
						binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text ?? ""
					if name.hasPrefix("_swiftBeans") || (managed && name == "close") {
						result.append(
							Violation(
								id: "context.reservedName",
								message:
									"'\(name)' conflicts with a generated context member",
								node: Syntax(binding)))
					}
				}
			}
			if managed, let function = member.decl.as(FunctionDeclSyntax.self),
				function.name.text == "close"
			{
				result.append(
					Violation(
						id: "context.reservedName",
						message: "close is generated for managed contexts",
						node: Syntax(function.name)))
			}
		}
		return result
	}
}
