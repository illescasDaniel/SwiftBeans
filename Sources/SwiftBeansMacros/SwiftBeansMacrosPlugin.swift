import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftBeansMacrosPlugin: CompilerPlugin {
	let providingMacros: [Macro.Type] = [
		ApplicationContextMacro.self,
		ChildContextMacro.self,
		ContextInputMacro.self,
		ConfigurationMacro.self,
		BeanMacro.self,
		ServiceMacro.self,
		InjectMacro.self,
	]
}
