---
name: sdd-feature
description: >-
  Run Spec-Driven Development for SwiftBeans library features with explicit human approval gates for design,
  specification, and architecture, followed by tests, implementation, and an independent conformance review.
  Use for public API, macro, generator, plugin, container, or other intentional behavior changes.
---

# SDD feature workflow — SwiftBeans

For every public API or intentional behavior change, follow **design → spec → architecture → tests → implementation → grade**.
The approved spec is the source of truth. SwiftBeans is a Swift Package, so use the system-design track for API,
runtime, macro, generator, and plugin work; do not create UI wireframes or use iOS-app architecture.

Read `AGENTS.md`, `docs/playbooks/SwiftBeans-adaptations.md`, and `docs/playbooks/spec-driven-development.md` first.
The repo's paths, Swift module seams, test conventions, memory rules, and quality commands override generic defaults.

## Mandatory approval gates

Each of Phases 0–2 ends with a reviewable artifact and a stop. Ask for approval in chat and wait for the user's reply
before moving to the next phase. A feature request, implementation request, plan approval, or a todo list is not
approval of a design, spec, or architecture. Do not combine those gated deliverables in one turn.

| User approval | Work authorized next |
|---|---|
| Feature request | Phase 0 only; then wait for design approval |
| `design approved` | Phase 1 only; then wait for spec approval |
| `spec approved` | Phase 2 only; then wait for architecture approval |
| `architecture approved` | Phases 3–5 |

Do not change production behavior before spec approval. If implementation exposes a spec flaw, update the design/spec,
get the affected approval again, then update contracts and tests. Do not patch around the flaw.

## Phase 0 — System design

Create `design/<feature>/DESIGN.md` from [`templates/DESIGN.md`](templates/DESIGN.md). Keep only relevant sections.
For SwiftBeans, describe the affected public API and the seams among `SwiftBeans`, macro declarations/implementations,
generator core, and build plugin as applicable. Include actual type and module names, generated-code flow, dependency
direction, and relevant concurrency/lifetime constraints. Use Mermaid diagrams where they clarify flow or boundaries.

There is no UI track for this package. For a small internal-only change with no meaningful design decisions, state why
Phase 0 is not applicable and ask the user to approve that skip before Phase 1.

If useful, validate Mermaid blocks with:

```bash
python3 .cursor/skills/sdd-feature/scripts/design_preview.py design/<feature>/DESIGN.md --check
```

The check needs Node and network access. If unavailable, report that the diagrams remain unchecked. End the turn with
the design path, open questions, and a request for `design approved` or requested changes.

## Phase 1 — Specification

Before writing the spec body, propose and resolve the design decisions below with the user. Record an answer for each;
use `N/A — <reason>` only when a decision truly does not apply.

| Decision | SwiftBeans concerns |
|---|---|
| Success criteria | Observable package/client outcome, including generated output or diagnostics when relevant |
| Failure handling | Invalid graphs, diagnostics, runtime failures, partial generation, retry or recovery |
| Performance and resource budget | Build-time cost, graph size, generated-code size, runtime cost, or reason not applicable |
| Trust boundary | Package/plugin inputs, source files, configuration, paths, generated output, and validation points |
| Compatibility and rollout | Source/API compatibility, Swift/platform support, generated-code compatibility, migration and rollback |

Create/update `specs/<feature>/SPEC.md` from [`templates/SPEC.md`](templates/SPEC.md). Include Metadata, approved design
decisions, public API and behavioral contracts, acceptance criteria as `### Scenario:` Given/When/Then blocks, and Out
of scope. Every identified failure path must have a scenario. Record approval dates in Metadata after approval.
Optionally run:

```bash
python3 .cursor/skills/sdd-feature/scripts/spec_check.py specs/<feature>/SPEC.md
```

End the turn with the spec path and request `spec approved` or requested changes.

## Phase 2 — Architecture

Write/update `specs/<feature>/ARCHITECTURE.md` with the approved public contracts and implementation seams. Define only
the contracts and module boundaries needed by the feature, including macro declaration/implementation separation,
runtime versus generator/plugin responsibilities, access levels, generated-code contract, and concurrency where
applicable. Keep implementation details out unless they establish a necessary seam. If the proposed code shape differs
from the approved design, explain and update the design/spec for approval first.

End the turn with the architecture path and request `architecture approved` or requested changes.

## Phase 3 — Tests

Map each BDD scenario to one or more Swift Testing tests (`@Test`, `#expect`) and to macro expansion or generated-source
compile tests where needed. Follow `.cursor/skills/modernize-tests/`. Tests should compile before implementation and
fail for the intended reason; use focused fixtures and avoid relying on implementation details. Record scenario-to-test
traceability in the architecture or test plan when the mapping is not obvious.

## Phase 4 — Implementation

Implement until the project's quality gate passes. For package changes, run `swift test`; use the documented Xcode
workflow when it adds necessary macro/plugin or example-app coverage. Confirm any generated-code contract against the
approved design and spec. If behavior needs to differ, return to the relevant approval gate. Update project memory at
the milestones specified in `AGENTS.md` and `.cursor/rules/agent-memory.mdc`.

## Phase 5 — Independent grade

After the quality gate is green, have a fresh read-only reviewer evaluate the completed diff against the approved spec,
design, architecture, project conventions, and tests. Use [`agents/code-grader.md`](agents/code-grader.md). The grader
must not be the implementation author and must not edit files. Fix findings, rerun the quality gate, and repeat the
review for at most two fix rounds. If an unresolved finding points to a spec flaw, return to Phase 1 and get approval.
Report the final scorecard and any remaining findings; the user makes the final call.

## Quality gate

```bash
swift test
```

Prefer the Xcode tools MCP when it provides needed package/plugin or example-app validation. Do not add UI tests or
simulator workflows to this library package.

## Templates and tools

- System design: [`templates/DESIGN.md`](templates/DESIGN.md)
- Feature spec: [`templates/SPEC.md`](templates/SPEC.md)
- Structural spec check: [`scripts/spec_check.py`](scripts/spec_check.py)
- Mermaid preview/check: [`scripts/design_preview.py`](scripts/design_preview.py)
- Independent reviewer: [`agents/code-grader.md`](agents/code-grader.md)

Adapted from [illescasDaniel/sdd-feature-skill](https://github.com/illescasDaniel/sdd-feature-skill), upstream commit
`5443fe57ff5f0fef25d8a76f75dae64953bb9e7b` (2026-10-22), with SwiftBeans-specific paths and package boundaries.
