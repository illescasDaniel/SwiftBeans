# Example session lifecycle — verification

Date: 2026-10-25. Diff base: child-context commit `68bae10`.

## Test-first evidence

The new session interface was first implemented as a compilable no-op scaffold, with app/UI
composition adapted to the approved signatures. Running `AppSessionContractTests` compiled and
failed on expected assertions: credentials were not forwarded, the flow was not installed, and
failure/retry authentication never ran. Log: `/tmp/swiftbeans-session-red.log`.
An earlier method-filter attempt selected zero tests and is not counted as red evidence.

## Quality gates

- `swift test`: PASS, 284 functions across four targets (19 + 27 + 224 + 14).
  Log: `/tmp/swiftbeans-session-package.log`.
- macOS example `xcodebuild test`: PASS, 52 test functions / 61 executions, zero failures/skips
  or runtime warnings in the result summary. Log: `/tmp/swiftbeans-session-macos.log`.
- Generic iOS Simulator `xcodebuild build`: PASS.
  Log: `/tmp/swiftbeans-session-ios.log`.
- Structural spec checker: PASS, 16 scenarios, zero hard failures.
- `git diff --check`: PASS.

Xcode commands use `-project Examples/SwiftBeansExample/SwiftBeansExample.xcodeproj`,
`-scheme SwiftBeansExample`, `-derivedDataPath DerivedData/SwiftBeansExample`,
`-skipPackagePluginValidation` and `-skipMacroValidation`, with macOS test and generic iOS
Simulator build destinations. Compiler/cache access required sandbox escalation.
Logs are local verification evidence, not tracked artifacts.

## Scenario coverage

| Spec scenario | Test evidence |
|---|---|
| Launch constructs no child | AppCoordinatorTests: injected factories/build login |
| Current authentication succeeds | AppSessionContractTests: exact credentials/flow; AppSessionTests: login success |
| Authentication fails | AppSessionContractTests: failure/retry (false); AppSessionTests: authentication failure |
| Authentication reports cancellation | AppSessionContractTests: failure/retry (true) |
| A newer login supersedes an older one | AppSessionTests: superseded login; AppSessionConcurrencyTests: reused model and cancellation assertions |
| Reusing the same login model preserves the newest request | AppSessionConcurrencyTests: reused model, three completion states |
| Logout or expiry invalidates pending login | AppSessionConcurrencyTests: pending authentication, both ending actions |
| Ending hides the flow before cleanup finishes | AppSessionConcurrencyTests: ending flow, suspended close and initiating-call completion flag |
| Repeated ending requests do not duplicate cleanup | AppSessionConcurrencyTests: ending flow, four logout/expiry combinations |
| Sign-in cannot enter an active or ending session | AppSessionConcurrencyTests: admission, both states and untouched supplied model |
| Cleanup completion permits a fresh login | AppSessionTests: login success, fresh navigation/repository and shared app repository |
| Logout while signed out is harmless | AppSessionConcurrencyTests: signed out/repeated ending |
| Caller cancellation preserves independently owned authentication | AppSessionConcurrencyTests: cancelled caller, service cancellation flag false |
| Caller cancellation does not abandon cleanup | AppSessionConcurrencyTests: ending flow, cancel initiating caller then release gate |
| Session ownership releases after cleanup | AppSessionTests: outgoing model release chain; AppSessionConcurrencyTests: weak flow and completed attempt model |
| Separate composition preserves observation and injected actions | AppSessionConcurrencyTests: observable session; AppCoordinatorTests: concrete screen callbacks and root composition; direct review of app, coordinator and root wiring |

Production changes are limited to the example. No library API/runtime/generator/plugin changes,
version bump, tag, release, new commit or push were made for this refactor.

Independent read-only grading: all seven criteria PASS, no actionable findings or fix rounds.
See [REVIEW.md](REVIEW.md).
