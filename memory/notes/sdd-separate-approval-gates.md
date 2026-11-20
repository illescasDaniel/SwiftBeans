---
name: sdd-separate-approval-gates
description: SDD needs separate explicit approvals for design, spec and architecture, then tests, implementation, independent grade
type: decision
date: 2026-10-25
status: current
supersedes: 
superseded_by: 
source:
---

Public API and intentional behavior changes require `design/<feature>/DESIGN.md`, then separate explicit approval gates for design, spec and architecture, then scenario-mapped tests, implementation and an independent read-only grade. Small internal-only changes may skip design only with approval. A feature request or plan approval does not approve any artifact.

**Why:** package boundaries, compatibility, failure behavior and acceptance criteria become reviewable before code; grading checks conformance beyond green tests.
