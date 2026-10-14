import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Validates that `@Bean` is applied to a static function.
public struct BeanMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		_ = node
		guard let function = declaration.as(FunctionDeclSyntax.self) else {
			throw SwiftBeansMacroError.message("@Bean can only be applied to a function")
		}
		let isStatic = function.modifiers.contains { $0.name.text == "static" }
		guard isStatic else {
			throw SwiftBeansMacroError.message("@Bean methods must be static")
		}
		_ = context
		return []
	}
}
