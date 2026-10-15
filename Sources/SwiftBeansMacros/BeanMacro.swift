import SwiftBeansSyntaxRules
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates a `@Bean` factory; discovery is performed by the generator.
public struct BeanMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		context.diagnose(SwiftBeansSyntaxRules.beanViolations(declaration, attribute: node))
		return []
	}
}
