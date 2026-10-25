# SwiftBeans — Agent Instructions

This repository is a **Swift Package** for dependency injection (with macros). It uses **Spec-Driven Development (SDD)**. Follow the Phase Gate Protocol for every public API or behavioral change.

## Scale mindset

Despite an early footprint, **act as if this package will grow large** (runtime, macros, plugins, docs, examples). Prefer clear module seams and tested public contracts over one-off shortcuts.

## Memory bank

Project state lives in `memory/` (git-tracked, so it follows the branch). At session start, read `memory/activeContext.md` then `memory/progress.md`. Update on these triggers only: a task is completed or discovered (`progress.md`); focus changes, a blocker is hit or work concludes (`activeContext.md`); a significant technical decision is made (`decisions.md`, append-only, newest first). Full protocol: the `memory-bank` skill (and always-on `.cursor/rules/agent-memory.mdc`).

**Split with jevmem:** current state stays in `memory/`; dated facts that stay true (decisions with reasons, bug causes, gotchas, preferences) go to the `jevmem` MCP (`memory_write` / `memory_recall`). Never put "next step is X" in jevmem. See the `jev-memory` skill.

How the files work and how to reset them on a new branch: [memory/README.md](memory/README.md).

## Phase Gate Protocol

Follow `.cursor/skills/sdd-feature/SKILL.md` for public API or intentional behavior changes. The phases are **design → spec → architecture → tests → implementation → independent grade**.

1. **Phase 0 — Design:** Write `design/<feature>/DESIGN.md` for API, runtime, macro, generator, and plugin changes. For a small internal-only change where design adds no value, explain why and get approval to skip this phase.
2. **Phase 1 — Spec:** Write/update `specs/<feature>/SPEC.md`, including agreed design decisions and Given/When/Then criteria. Stop for explicit approval.
3. **Phase 2 — Architecture:** Write/update public contracts and module seams (runtime vs macros vs generator/plugin). Stop for explicit approval.
4. **Phase 3 — Tests:** Map scenarios to Swift Testing and macro/generator compile tests. Tests must compile and fail for the intended reason before implementation.
5. **Phase 4 — Implementation:** Implement until `swift test` and the documented feature-specific quality checks pass.
6. **Phase 5 — Grade:** Have an independent, read-only reviewer compare the completed diff with the approved spec and project conventions. Resolve findings and report the final scorecard.

Each Phase 0–2 is a separate approval gate. A feature request or approval of a plan is not approval of the design, spec, or architecture. Do not proceed past a gate until the user explicitly approves its artifact in chat.

If implementation or review reveals a flaw in the spec, **rewrite the spec** (Phase 1), get approval, then update architecture and tests. Do not patch around a bad spec.

## Code style

- Use **tabs** for indentation in Swift and all project source files — not spaces.

## Reference playbooks

| Doc | Purpose |
|-----|---------|
| `docs/playbooks/SwiftBeans-adaptations.md` | Package-specific overrides (read first) |
| `docs/playbooks/spec-driven-development.md` | SDD philosophy and phase gates |

## MCP tools

| Server | Config | Use for |
|--------|--------|---------|
| `codenav-swift` | `.mcp.json` / `.cursor/mcp.json` | Symbol navigation (references, callers, hover) via SourceKit index |
| `xcode-tools` | `.mcp.json` / `.cursor/mcp.json` (also often global) | Build and run package tests from Xcode |
| `jevmem` | `.mcp.json` / `.cursor/mcp.json` | Long-term semantic memory (`memory_write` / `memory_recall`) |

Enable servers in Cursor Settings → MCP. There is **no** `ios-simulator` MCP in this repo (library package, no UI tests).

`jevmem` needs a one-time settings file (`uvx jevmem config init`, or a local Jev-compatible model — see [jev-mem installation](https://github.com/illescasDaniel/jev-mem/blob/main/docs/installation.md)). Optional: `uvx --from jevmem jevmem warmup` while online to fetch the local embedding model.

## Build output and code navigation index

Prefer keeping build products and the Xcode index under repo-local `DerivedData/` (gitignored):

```bash
xcodebuild build \
  -scheme SwiftBeans \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData/SwiftBeans
```

`codenav-swift` (sourcekit-lsp) reads that index through `buildServer.json` (gitignored, machine-specific). After opening the package in Xcode (or generating a workspace under `.swiftpm`), regenerate:

```bash
xcode-build-server config \
  -workspace .swiftpm/xcode/package.xcworkspace \
  -scheme SwiftBeans \
  --build_root "$PWD/DerivedData/SwiftBeans"
```

If codenav results disagree with grep, or after big refactors: `rm -rf DerivedData`, rebuild with `-derivedDataPath`, retry.

## Skills

Codex discovers the project skills through `.agents/skills/`, whose skill folders
are symlinked to `.cursor/skills/`. Claude uses `.claude/skills` pointing to the
same source. Edit skills in `.cursor/skills/`; when adding a new skill, add its
matching relative symlink under `.agents/skills/`.

Project workflows:

- `.cursor/skills/memory-bank/` — git-tracked markdown session memory ([illescasDaniel/memory-bank](https://github.com/illescasDaniel/memory-bank))
- `.cursor/skills/jev-memory/` — when/how to use jevmem MCP ([illescasDaniel/jev-mem](https://github.com/illescasDaniel/jev-mem))
- `.cursor/skills/sdd-feature/` — SDD workflow for library/macro features
- `.cursor/skills/playbooks/` — when to read playbooks vs adaptations
- `.cursor/skills/apply-worktree/` — merge an isolated agent worktree (`/apply-worktree`)
- `.cursor/skills/delete-worktree/` — remove a finished agent worktree (`/delete-worktree`)
- `.cursor/skills/save-changes/` — update memory, commit, and push (`/save-changes`)
- `.cursor/skills/modernize-tests/` — Swift Testing patterns
- `.cursor/skills/audit-xcode-security-settings/` — security-oriented build settings when relevant
