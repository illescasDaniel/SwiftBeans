# <Feature name>

## Metadata

- **Feature:** <What package clients gain>
- **System design:** [design/<feature>/DESIGN.md](../../design/<feature>/DESIGN.md)
- **Design approved:** <YYYY-MM-DD> (chat)
- **Design decisions approved:** <YYYY-MM-DD> (chat)
- **Spec approved:** <YYYY-MM-DD> (chat)
- **Related:** <related specs or contracts>

## Design decisions

### Success criteria

- <Observable package/client outcome and measurable threshold.>

### Failure handling

- <What can fail, diagnostics or runtime result, and recovery behavior.>

### Performance and resource budget

- <Build-time/runtime cost, graph or output limits, or `N/A — <reason>`.>

### Trust boundary

- <Untrusted inputs and where they are validated.>

### Compatibility and rollout

- <Source/API and generated-code compatibility, Swift/platform support, migration, rollout, or `N/A — <reason>`.>

## Public API and contracts

- <Declarations, signatures, access levels, defaults, and availability.>
- <Generated-code shape and source compatibility.>
- <Resolution, scope, lifetime, concurrency, errors, and diagnostics as applicable.>

## Acceptance criteria

### Scenario: <happy path>

**Given** <context> **When** <action> **Then** <observable result>.

### Scenario: <failure or boundary> (F1)

**Given** <context> **When** <failure or invalid input occurs> **Then** <diagnostic/result and resulting state>.

## Out of scope

- <Adjacent behavior that is intentionally not part of this change.>
