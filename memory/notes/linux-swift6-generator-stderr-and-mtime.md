---
name: linux-swift6-generator-stderr-and-mtime
description: Linux: Swift 6 rejects fputs(_, stderr); GeneratedFileWriterTests compare mtime with 1 s tolerance
type: gotcha
date: 2026-10-15
status: current
supersedes: 
superseded_by: 
source:
---

Generator stderr output uses `FileHandle`. `GeneratedFileWriterTests` compares mtimes with a 1 second tolerance because filesystem timestamp granularity differs on Linux.
