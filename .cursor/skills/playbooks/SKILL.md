---
name: playbooks
description: >-
  Read vendored playbooks for SwiftBeans. Use when making API/architecture
  decisions, writing specs, or when generic Swift advice conflicts with this
  project's SDD setup.
---

# Playbooks Reference Skill

## When to use

- Defining or changing public DI / macro API
- Writing or reviewing a feature spec and test boundaries
- Resolving conflicts between generic Swift advice and this repo’s process

## Read order

1. `memory/activeContext.md` then `memory/progress.md` (always-on `agent-memory.mdc`)
2. `AGENTS.md`
3. `docs/playbooks/SwiftBeans-adaptations.md`
4. `docs/playbooks/spec-driven-development.md`
5. Feature spec: `specs/<feature>/SPEC.md`

## Related skills

- `sdd-feature` — phase-gated feature workflow for this package
- `modernize-tests` — Swift Testing style
- `audit-xcode-security-settings` — hardening build settings when relevant

## Do not

- Follow iOS-app playbook examples (UI, coordinators, simulator XCUITests) — this repo is a Swift package library
- Put full playbook text into Cursor rules (rules stay short; playbooks stay in `docs/playbooks/`)
