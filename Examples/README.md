# Examples

## SwiftBeansIOSExample

Path: `Examples/SwiftBeansIOSExample/`

Already wired for local development:

- Local package: `Packages/SwiftBeans/` — directory of symlinks to repo `Package.swift` / `Sources` / `Plugins` / `Tests` (not a single symlink to the repo root, which nested `Examples` under the package path)
- Product: `SwiftBeans`
- Build tool plugin: `SwiftBeansPlugin` (via `productName = "plugin:SwiftBeansPlugin"` in the pbxproj)
- Shared scheme: `SwiftBeansIOSExample` (iOS only — use an **iOS Simulator** destination for Previews, not My Mac)
- `.swiftbeans.yml` at the example root
- MVVM demo (see `SwiftBeansIOSExample/`):

```text
MyApp
  └─ ItemListView(viewModel: context.itemListViewModel)
       └─ ItemListViewModel          @Service(scope: .transient)
            └─ FetchItemsUseCase     @Service
                 └─ ItemRepository   protocol
                      └─ FakeItemRepository   @Service(boundTo: ItemRepository.self)
```

If Xcode still shows **Missing package product 'SwiftBeans'**: close the project, reopen `Examples/SwiftBeansIOSExample/SwiftBeansIOSExample.xcodeproj` (not the repo-root `Package.swift`), then **File → Packages → Reset Package Caches** and build again.

**SwiftUI Previews:** open only the example `.xcodeproj` (close the repo-root Swift package window if open), select scheme `SwiftBeansIOSExample`, and pick an iPhone Simulator — not **My Mac**.

### Build (CLI)

```bash
xcodebuild \
  -project Examples/SwiftBeansIOSExample/SwiftBeansIOSExample.xcodeproj \
  -scheme SwiftBeansIOSExample \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -derivedDataPath DerivedData/SwiftBeansIOSExample \
  build
```

Requires **iOS 18+** (iOS Simulator destination for Previews).
