# Examples

## SwiftBeansExample

Path: `Examples/SwiftBeansExample/`

Multiplatform SwiftUI app (iOS + macOS) wired for local development:

- Local package: `Packages/SwiftBeans/` — directory of symlinks to repo `Package.swift` / `Sources` / `Plugins` / `Tests` (not a single symlink to the repo root, which nested `Examples` under the package path)
- Product: `SwiftBeans`
- Build tool plugin: `SwiftBeansPlugin` (via `productName = "plugin:SwiftBeansPlugin"` in the pbxproj)
- Shared scheme: `SwiftBeansExample` (supports **My Mac** and iOS Simulator)
- `.swiftbeans.yml` at the example root
- MVVM demo (see `SwiftBeansExample/`):

```text
MyApp
  └─ ItemListView(viewModel: context.itemListViewModel)
       └─ ItemListViewModel          @Service(scope: .transient)
            └─ FetchItemsUseCase     @Service
                 └─ ItemRepository   protocol
                      └─ FakeItemRepository   @Service(boundTo: ItemRepository.self)
```

If Xcode still shows **Missing package product 'SwiftBeans'**: close the project, reopen `Examples/SwiftBeansExample/SwiftBeansExample.xcodeproj` (not the repo-root `Package.swift`), then **File → Packages → Reset Package Caches** and build again.

**SwiftUI Previews:** open only the example `.xcodeproj` (close the repo-root Swift package window if open), select scheme `SwiftBeansExample`, then **My Mac** or an iPhone Simulator.

### Build (CLI)

```bash
# macOS
xcodebuild \
  -project Examples/SwiftBeansExample/SwiftBeansExample.xcodeproj \
  -scheme SwiftBeansExample \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData/SwiftBeansExample \
  build

# iOS Simulator
xcodebuild \
  -project Examples/SwiftBeansExample/SwiftBeansExample.xcodeproj \
  -scheme SwiftBeansExample \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -derivedDataPath DerivedData/SwiftBeansExample \
  build
```

Requires **macOS 15+** / **iOS 18+**.
