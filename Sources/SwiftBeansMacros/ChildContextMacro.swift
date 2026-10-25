import SwiftBeansSyntaxRules
import SwiftSyntax
import SwiftSyntaxMacros

/// Emits only per-instance storage and construction; the generator owns graph wiring.
public struct ChildContextMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		let violations = SwiftBeansSyntaxRules.childContextViolations(declaration, attribute: node)
		guard violations.isEmpty else {
			context.diagnose(violations)
			return []
		}
		let parent = SwiftBeansSyntaxRules.argument("of", of: node).flatMap(SwiftBeansSyntaxRules.typeLiteral)!
		let protocolName = parent.split(separator: ".").last! + "Protocol"
		let managed = (try? SwiftBeansSyntaxRules.teardown(of: node).get()) == .managed
		let inputs = declaration.memberBlock.members.compactMap { member -> (String, String)? in
			guard let variable = member.decl.as(VariableDeclSyntax.self),
				SwiftBeansSyntaxRules.find(.contextInput, in: variable.attributes) != nil,
				let binding = variable.bindings.first, let type = binding.typeAnnotation?.type
			else { return nil }
			return (binding.pattern.trimmedDescription, type.trimmedDescription)
		}
		let enclosingNames = context.lexicalContext.compactMap { syntax -> String? in
			guard
				syntax.is(ClassDeclSyntax.self) || syntax.is(StructDeclSyntax.self)
					|| syntax.is(EnumDeclSyntax.self),
				let named = syntax.asProtocol(NamedDeclSyntax.self)
			else { return nil }
			return named.name.text
		}.reversed()
		let name = (Array(enclosingNames) + [declaration.as(ClassDeclSyntax.self)!.name.text]).joined(
			separator: ".")
		let registry =
			managed
			? "SwiftBeansManagedRegistry(contextName: \(name.debugDescription))" : "SwiftBeansRegistry()"
		let arguments = (["parent: any \(protocolName)"] + inputs.map { "\($0.0): \($0.1)" }).joined(
			separator: ", ")
		let assignments = (["self._swiftBeansParent = parent"] + inputs.map { "self.\($0.0) = \($0.0)" })
			.joined(separator: "\n\t")
		var members = [
			DeclSyntax(stringLiteral: "let _swiftBeansRegistry = \(registry)"),
			DeclSyntax(stringLiteral: "let _swiftBeansParent: any \(protocolName)"),
			DeclSyntax(stringLiteral: "init(\(arguments)) {\n\t\(assignments)\n}"),
		]
		if managed {
			members.append(
				DeclSyntax(
					stringLiteral: "func close() async {\n\tawait _swiftBeansRegistry.close()\n}"))
		}
		return members
	}
}

public struct ContextInputMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		let nearestClass = context.lexicalContext.first?.as(ClassDeclSyntax.self)
		let inChild =
			nearestClass.map { SwiftBeansSyntaxRules.find(.childContext, in: $0.attributes) != nil }
			?? false
		context.diagnose(SwiftBeansSyntaxRules.contextInputViolations(declaration, inChild: inChild))
		return []
	}
}
