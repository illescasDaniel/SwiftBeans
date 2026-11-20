import SwiftBeansSyntaxRules
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates a `@Service` type; discovery is performed by the generator.
///
/// With `autoInit: true` it also emits the initializer derived by `SwiftBeansSyntaxRules.autoInitModel`.
public struct ServiceMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		context.diagnose(SwiftBeansSyntaxRules.serviceViolations(declaration, attribute: node))
		guard case .success(true) = SwiftBeansSyntaxRules.autoInit(of: node),
			declaration.is(ClassDeclSyntax.self) || declaration.is(StructDeclSyntax.self)
				|| declaration.is(ActorDeclSyntax.self)
		else { return [] }
		switch SwiftBeansSyntaxRules.autoInitModel(declaration) {
		case .success(let model):
			return [DeclSyntax(model.initializer)]
		case .failure(let failure):
			context.diagnose(failure.violations)
			return []
		}
	}
}
