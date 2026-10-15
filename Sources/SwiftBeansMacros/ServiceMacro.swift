import SwiftBeansSyntaxRules
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates a `@Service` type; discovery is performed by the generator.
public struct ServiceMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		context.diagnose(SwiftBeansSyntaxRules.serviceViolations(declaration, attribute: node))
		return []
	}
}
