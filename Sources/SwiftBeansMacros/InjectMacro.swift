import SwiftBeansSyntaxRules
import SwiftSyntax
import SwiftSyntaxMacros

/// Marks the initializer the generated graph calls when a `@Service` has several.
public struct InjectMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		context.diagnose(SwiftBeansSyntaxRules.injectViolations(declaration, attribute: node))
		return []
	}
}
