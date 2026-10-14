# SwiftBeans — Agent Instructions

This repository is a **Swift Package** for dependency injection (with macros). It uses **Spec-Driven Development (SDD)**. Follow the Phase Gate Protocol for every public API or behavioral change.

## Scale mindset

Despite an early footprint, **act as if this package will grow large** (runtime, macros, plugins, docs, examples). Prefer clear module seams and tested public contracts over one-off shortcuts.

## Memory bank

Project state lives in `memory/` (git-tracked, so it follows the branch). At session start, read `memory/activeContext.md` then `memory/progress.md`. Update on these triggers only: a task is completed or discovered (`progress.md`); focus changes, a blocker is hit or work concludes (`activeContext.md`); a significant technical decision is made (`decisions.md`, append-only, newest first). Full protocol: the `memory-bank` skill (and always-on `.cursor/rules/agent-memory.mdc`).

**Split with jevmem:** current state stays in `memory/`; dated facts that stay true (decisions with reasons, bug causes, gotchas, preferences) go to the `jevmem` MCP (`memory_write` / `memory_recall`). Never put "next step is X" in jevmem. See the `jev-memory` skill.

How the files work and how to reset them on a new branch: [memory/README.md](memory/README.md).

## Phase Gate Protocol

1. **Phase 1 — Spec:** Read or write the relevant `specs/<feature>/SPEC.md`. Stop and ask for human approval before proceeding.
2. **Phase 2 — Architecture:** Write or update public contracts and module seams (runtime vs macros). Stop and ask for approval.
3. **Phase 3 — Tests:** Write unit / macro tests from the BDD acceptance criteria. Tests must compile; implementations may be stubs.
4. **Phase 4 — Implementation:** Implement until tests pass.

If Phase 4 reveals a flaw in the spec, **rewrite the spec** (Phase 1), then update contracts and tests. Do not patch around a bad spec.

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
