# Spec-Driven Development — SwiftBeans

Spec-Driven Development moves important behavior decisions ahead of implementation. The approved specification is the
source of truth; architecture, tests, and code must trace back to it. When implementation exposes a flaw in the spec,
revise and re-approve the spec rather than patching around it.

This playbook is adapted from [illescasDaniel/sdd-feature-skill](https://github.com/illescasDaniel/sdd-feature-skill),
upstream commit `5443fe57ff5f0fef25d8a76f75dae64953bb9e7b` (2026-10-22). The detailed agent workflow and templates live
in `.cursor/skills/sdd-feature/`; `AGENTS.md` defines the repository's mandatory gates.

## Lifecycle

1. **Design:** Define the package-level change and module seams in `design/<feature>/DESIGN.md`. For API or behavior
   changes, identify success, failure, performance, trust-boundary, and compatibility questions early. SwiftBeans has
   no UI track. A small internal-only change may skip design only after the user approves the skip.
2. **Spec:** Record agreed decisions and public behavior in `specs/<feature>/SPEC.md`. Acceptance criteria use
   Given/When/Then scenarios, including failure and boundary cases. Keep explicit out-of-scope items.
3. **Architecture:** Define public contracts, access levels, and responsibilities across runtime, macro declarations,
   macro implementations, generator, and plugin targets where they apply.
4. **Tests:** Map each scenario to Swift Testing and, when applicable, macro expansion or generated-code compile tests.
   Tests should compile before implementation and fail for the expected reason.
5. **Implementation:** Implement the approved design and contracts; run `swift test` plus relevant Xcode/plugin/example
   checks.
6. **Grade:** Have an independent read-only reviewer trace scenarios through tests and implementation and check the
   diff against the approved design, architecture, and project conventions.

Design, Spec, and Architecture are separate explicit approval gates in chat. A request to implement a feature or an
approval of a plan does not approve any of those artifacts. If code or review finds a spec flaw, return to the Spec
gate; if a change impacts the approved design or architecture, get that artifact re-approved too.

## What a useful spec contains

- Metadata linking the related design and architecture, and recording approvals
- Design decisions: success criteria, failure handling, performance/resource budget, trust boundary, compatibility and
  rollout (answer each or give a reasoned `N/A`)
- Public API and behavioral contracts, including lifetimes/scopes, concurrency, generated code, errors, and diagnostics
  where relevant
- Acceptance criteria that state observable outcomes, including invalid input, failure, and boundary behavior
- Out-of-scope behavior to keep adjacent work from entering implementation implicitly

## Traceability and quality

The design diagrams identify the main system flow and the components or targets touched. Label failure branches and map
each to a spec scenario. During grading, check the contract independently of whether tests happen to pass: each scenario
must have a meaningful assertion and a corresponding implementation path. A green test that asserts the wrong or weaker
outcome does not prove conformance.

For this package, the quality gate is `swift test`. Use Xcode validation when it adds coverage for Swift macros, build
plugins, or the example app. Do not apply app-specific UI tests, simulator exploration, or UI architecture to this
library.
