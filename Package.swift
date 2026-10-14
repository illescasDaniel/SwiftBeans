// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
	name: "SwiftBeans",
	platforms: [
		.macOS(.v15),
		.iOS(.v18),
		.tvOS(.v18),
		.watchOS(.v11),
		.macCatalyst(.v18),
	],
	products: [
		.library(
			name: "SwiftBeans",
			targets: ["SwiftBeans"]
		),
		.library(
			name: "SwiftBeansGeneratorCore",
			targets: ["SwiftBeansGeneratorCore"]
		),
		.plugin(
			name: "SwiftBeansPlugin",
			targets: ["SwiftBeansPlugin"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0"),
	],
	targets: [
		.macro(
			name: "SwiftBeansMacros",
			dependencies: [
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
			]
		),
		.target(
			name: "SwiftBeans",
			dependencies: ["SwiftBeansMacros"],
			swiftSettings: [
				.enableUpcomingFeature("ApproachableConcurrency"),
			]
		),
		.target(
			name: "SwiftBeansGeneratorCore",
			dependencies: [
				"SwiftBeans",
				.product(name: "SwiftSyntax", package: "swift-syntax"),
				.product(name: "SwiftParser", package: "swift-syntax"),
			],
			swiftSettings: [
				.enableUpcomingFeature("ApproachableConcurrency"),
			]
		),
		.executableTarget(
			name: "SwiftBeansGenerator",
			dependencies: ["SwiftBeansGeneratorCore"],
			swiftSettings: [
				.enableUpcomingFeature("ApproachableConcurrency"),
			]
		),
		.plugin(
			name: "SwiftBeansPlugin",
			capability: .buildTool(),
			dependencies: ["SwiftBeansGenerator"]
		),
		.testTarget(
			name: "SwiftBeansTests",
			dependencies: ["SwiftBeans"],
			swiftSettings: [
				.enableUpcomingFeature("ApproachableConcurrency"),
			]
		),
		.testTarget(
			name: "SwiftBeansGeneratorCoreTests",
			dependencies: [
				"SwiftBeans",
				"SwiftBeansGeneratorCore",
			],
			swiftSettings: [
				.enableUpcomingFeature("ApproachableConcurrency"),
			]
		),
		.testTarget(
			name: "SwiftBeansMacrosTests",
			dependencies: [
				"SwiftBeansMacros",
				.product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
			]
		),
	]
)
