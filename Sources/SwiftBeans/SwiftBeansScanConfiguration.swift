/// Contents of a `.swiftbeans.yml` scan configuration file.
///
/// Declares additional local packages/targets that participate in component scan
/// (needed for Xcode apps without a root `Package.swift`).
public struct SwiftBeansScanConfiguration: Codable, Sendable, Equatable {
	public var localPackages: [LocalPackage]

	public init(localPackages: [LocalPackage] = []) {
		self.localPackages = localPackages
	}

	enum CodingKeys: String, CodingKey {
		case localPackages = "local_packages"
	}

	public struct LocalPackage: Codable, Sendable, Equatable {
		/// Path relative to the project/package root that contains the `.swiftbeans.yml` (or the app root).
		public var path: String
		/// SPM / Xcode target names under that package whose sources should be scanned.
		public var targets: [String]

		public init(path: String, targets: [String]) {
			self.path = path
			self.targets = targets
		}
	}
}
