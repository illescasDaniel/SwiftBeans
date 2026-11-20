---
name: memory-1-and-docs-1-adoption
description: Project memory moved to memory-1 (NOW/LATER/MEMORY + notes) and docs to docs-1 (front matter + generated docs/INDEX.md)
type: decision
date: 2026-11-20
status: current
supersedes: 
superseded_by: 
source:
---

SwiftBeans replaced the memory-bank workflow (`memory/{README,activeContext,progress,decisions,archive}.md`, `.cursor/skills/memory-bank/`, `.cursor/rules/agent-memory.mdc`) with the global `memory-1` skill, and indexed `docs/` with the global `docs-1` skill.

**Why:** one-fact dated notes with supersession answer "why is it like this" better than an append-only decisions log, and the checkers catch drift. `.gitattributes` no longer needs the union-merge rule for `memory/decisions.md`.
**Rejected:** moving `specs/` and `design/` into `docs/`: they are SDD artifacts read by `.cursor/skills/sdd-feature` (`spec_check.py`), so their location and format stay.
**How to apply:** current state goes in `memory/NOW.md`; durable facts in `memory/notes/`; jevmem keeps dated cross-project facts but never "next step is X".
