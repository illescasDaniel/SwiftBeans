# <Feature name> — system design

- **Spec:** `specs/<feature>/SPEC.md`, written after this design is approved
- **Design approved:** <YYYY-MM-DD> (chat)

This template is for SwiftBeans package work. Keep only relevant sections; remove irrelevant sections instead of leaving
placeholders. Use real target, type, and macro names. A design describes responsibilities and dependencies, not every
implementation detail.

## Summary

<What changes for package clients, and why.>

## Public surface and generated-code flow

<Show how a client declaration/configuration flows through the plugin, generator, macros, and runtime as applicable.>

```mermaid
flowchart LR
    Client[Client declarations] --> Plugin[SwiftBeansPlugin]
    Plugin --> Generator[SwiftBeansGenerator]
    Generator --> Generated[Generated accessors]
    Generated --> Runtime[SwiftBeans runtime]
```

## Module seams

Show only the modules touched. Colour additions, changes, and removals; unchanged parts use the default style.

```mermaid
flowchart LR
    classDef added fill:#dcfce7,stroke:#15803d,color:#14532d
    classDef changed fill:#fef9c3,stroke:#a16207,color:#713f12
    classDef removed fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d,stroke-dasharray:5 3

    Client[SwiftBeans client] --> Plugin[SwiftBeansPlugin]
    Plugin --> Generator[SwiftBeansGenerator]:::changed
    Generator --> MacroImpl[SwiftBeansMacros implementation]
    MacroImpl --> MacroAPI[SwiftBeansMacros declarations]
    Generated[Generated code] --> Runtime[SwiftBeans runtime]
```

## Contracts and invariants

- **Public declarations:** <types, macros, functions, properties, access levels, and source compatibility>
- **Generated code:** <observable shape and compile-time assumptions>
- **Resolution/lifetime:** <registration, lookup, scopes, ownership, and teardown if relevant>
- **Concurrency:** <isolation, Sendable requirements, locking, and execution context if relevant>
- **Diagnostics/errors:** <trigger, severity, source location, and client-facing message if relevant>

## Main flow and failure paths

<Use a sequence diagram when control or data flow needs clarification. Label each failure branch F1, F2, … in order;
each branch must have a matching SPEC scenario.>

```mermaid
sequenceDiagram
    participant P as SwiftBeansPlugin
    participant G as SwiftBeansGenerator
    participant V as GraphValidator
    participant O as Generated output
    P->>G: scan sources and configuration
    G->>V: validate dependency graph
    alt F1: graph is invalid
        V-->>G: diagnostics
        G-->>P: fail generation with source locations
    else valid graph
        V-->>G: validated graph
        G->>O: emit generated accessors
    end
```

## Open questions

- <Questions the reviewer should decide at the design gate.>
