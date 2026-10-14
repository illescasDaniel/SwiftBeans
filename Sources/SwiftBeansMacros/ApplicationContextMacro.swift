import SwiftSyntax
import SwiftSyntaxMacros

public struct ApplicationContextMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		_ = node
		_ = protocols
		_ = context
		guard declaration.is(ClassDeclSyntax.self) else {
			throw SwiftBeansMacroError.message("@ApplicationContext can only be applied to a class")
		}
		// Internal (same-module) so generated extensions in other files can use it.
		return [
			"let _swiftBeansRegistry = SwiftBeansRegistry()",
		]
	}
}
