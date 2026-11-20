import SwiftBeansSyntaxRules
import SwiftSyntax
import SwiftSyntaxMacros

/// `@Assisted` on a stored property of an `@Service(autoInit: true)` type. It expands to nothing; the
/// service macro copies the attribute onto the generated initializer's parameter, where it resolves to
/// the `Assisted` property wrapper. Anywhere else it is a positioned error.
public struct AssistedMarkerMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		context.diagnose(
			SwiftBeansSyntaxRules.propertyMarkerViolations(
				declaration, attribute: node, enclosing: context.lexicalContext.first))
		return []
	}
}

/// `@Qualifier("name")` on a stored property of an `@Service(autoInit: true)` type. See `AssistedMarkerMacro`.
public struct QualifierMarkerMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		context.diagnose(
			SwiftBeansSyntaxRules.propertyMarkerViolations(
				declaration, attribute: node, enclosing: context.lexicalContext.first))
		return []
	}
}
