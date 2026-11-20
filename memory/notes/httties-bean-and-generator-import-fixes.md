---
name: httties-bean-and-generator-import-fixes
description: Example wires HTTIES via @Bean with a fake handler by default; accessor naming strips any/some; generated file imports scanned modules
type: decision
date: 2026-10-14
status: current
supersedes: 
superseded_by: 
source:
---

`httpDataRequestHandler` returns `FakeJSONPlaceholderDataHandler` by default (swap to `URLSession.shared` for the live API) and `httpClient` returns `HTTPClientImpl`. Returning `any HTTPClient` had broken codegen (`var any HTTPClient`) and the generated file lacked `import HTTIES` under member-import visibility, so `Naming.accessorName` strips `any`/`some` and the generator emits non-skipped imports from scanned sources.

**Why:** `@Bean` exists for types you do not own; the fake handler keeps CI and Previews offline.
