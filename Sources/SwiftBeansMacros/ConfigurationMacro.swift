import SwiftBeansSyntaxRules
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates a `@Configuration` type; discovery is performed by the generator.
public struct ConfigurationMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		context.diagnose(SwiftBeansSyntaxRules.configurationViolations(declaration, attribute: node))
		return []
	}
}
