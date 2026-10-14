# Examples

## SwiftBeansExample

Path: `Examples/SwiftBeansExample/`

Multiplatform SwiftUI app (iOS + macOS) wired for local development:

- Local package: `Packages/SwiftBeans/` — symlinks to this repo’s `Package.swift` / `Sources` / `Plugins` / `Tests`
- Remote package: [HTTIES](https://github.com/illescasDaniel/HTTIES) (JSON HTTP client)
- Build tool plugin: `SwiftBeansPlugin`
- Shared scheme: `SwiftBeansExample` (My Mac + iOS Simulator)
- Unit tests: `SwiftBeansExampleTests`
- Coordinator navigation + MVVM over JSONPlaceholder posts:

```text
MyApp
  └─ AppRootView(coordinator)
       └─ NavigationStack
            ├─ ItemListView (posts)
            ├─ ItemDetailView
            └─ FeaturesDemoView  ← why @Bean exists (HTTIES)

@Configuration AppConfiguration
  @Bean httpDataRequestHandler() → FakeJSONPlaceholderDataHandler
       └─ swap to URLSession.shared for live API
  @Bean httpClient(handler:) → HTTPClientImpl (HTTIES)

@Service(boundTo: ItemRepository.self) JSONPlaceholderItemRepository
@Service FetchItemsUseCase
@Service(scope: .transient) view models
```

**SwiftUI Previews:** open only the example `.xcodeproj`, scheme `SwiftBeansExample`, My Mac or iPhone Simulator.

### Build / test (CLI)

```bash
xcodebuild \
  -project Examples/SwiftBeansExample/SwiftBeansExample.xcodeproj \
  -scheme SwiftBeansExample \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData/SwiftBeansExample \
  build

xcodebuild test \
  -project Examples/SwiftBeansExample/SwiftBeansExample.xcodeproj \
  -scheme SwiftBeansExample \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData/SwiftBeansExample
```

Requires **macOS 15+** / **iOS 18+**. HTTIES resolves from GitHub via SwiftPM (no local clone needed).
