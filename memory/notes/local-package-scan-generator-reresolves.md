---
name: local-package-scan-generator-reresolves
description: Generator re-reads .swiftbeans.yml and re-walks sources every run; SwiftPM rejects prebuild commands built from source
type: decision
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

A `prebuildCommand` was planned so new files in local packages regenerate without a clean build. SwiftPM refuses it: `a prebuild command cannot use executables built from source, including executable target 'SwiftBeansGenerator'` (same with `--build-system swiftbuild`). Kept a `buildCommand`; the plugin writes `SwiftBeansRequest.json` (`GeneratorRequest`: scan root, target sources, config name) and the generator (`SwiftBeansGeneration.generate(request:)`) re-resolves config and files every run, reporting config errors as `config.invalid`. The plugin declares the scan root, config, local package files and their folders as inputs, so adding/removing a file (folder mtime) reruns it. Output stays byte-stable via `GeneratedFileWriter`.

**Why:** verified with an SPM test app (new files, new subfolders, later-created config all regenerate; a no-op rebuild leaves output untouched). Xcode behavior is not testable on Linux; residual edge cases are in the SPEC Known limitations.
**Rejected:** a binary-target generator (artifact bundle per release) for a true prebuild: separate effort.
