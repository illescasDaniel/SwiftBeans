import SwiftSyntax
import SwiftSyntaxMacros

/// Marker macro — discovery is performed by the generator.
public struct ServiceMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		_ = node
		_ = declaration
		_ = protocols
		_ = context
		return []
	}
}
