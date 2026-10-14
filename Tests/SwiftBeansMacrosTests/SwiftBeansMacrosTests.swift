import SwiftBeansMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("SwiftBeans macros")
struct SwiftBeansMacrosTests {
	@Test
	func applicationContextAddsRegistry() {
		assertMacroExpansion(
			"""
			@ApplicationContext
			final class AppContext {
			}
			""",
			expandedSource: """
			final class AppContext {

				let _swiftBeansRegistry = SwiftBeansRegistry()
			}
			""",
			macroSpecs: [
				"ApplicationContext": MacroSpec(type: ApplicationContextMacro.self),
			],
			indentationWidth: .tabs(1),
			failureHandler: { Issue.record("\($0.message)") }
		)
	}

	@Test
	func beanRejectsNonStaticMethod() {
		assertMacroExpansion(
			"""
			enum AppConfiguration {
				@Bean
				func urlSession() -> Int { 0 }
			}
			""",
			expandedSource: """
			enum AppConfiguration {
				func urlSession() -> Int { 0 }
			}
			""",
			diagnostics: [
				DiagnosticSpec(message: "@Bean methods must be static", line: 2, column: 2),
			],
			macroSpecs: [
				"Bean": MacroSpec(type: BeanMacro.self),
			],
			indentationWidth: .tabs(1),
			failureHandler: { Issue.record("\($0.message)") }
		)
	}
}
