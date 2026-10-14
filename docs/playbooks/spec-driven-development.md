# The Spec-Driven Development (SDD) Playbook: iOS & AI Agents

## Chapter 1: The Philosophy of SDD

Spec-Driven Development (SDD) shifts the hardest part of software engineering—decision making—to the very beginning of the lifecycle. Instead of discovering edge cases, routing errors, and missing states while writing code, you discover them while writing text.

For human developers, SDD prevents scope creep, eliminates undocumented tribal knowledge, and stops the decay of business rules. For AI agents, SDD acts as a strict containment field. Large Language Models (LLMs) are incredibly fast at generating code, but they are eager to hallucinate requirements. By gating an AI behind a specification, you force it to become a deterministic executor of your exact intent.

The SDD lifecycle operates as a strict, unidirectional funnel:

1. **The Specification (Text):** Human-readable business rules, routing, and state logic.
2. **The Contract (Interfaces):** Swift Protocols and struct definitions.
3. **The Verification (Tests):** Translating the text spec directly into automated tests.
4. **The Implementation (Code):** The actual UI and business logic to satisfy the tests.

If step 4 reveals a flaw in step 1, you do not patch the code. You rewrite step 1, which updates step 2 and 3, maintaining the single source of truth.

---

## Chapter 2: The Source of Truth (`SPEC.md`)

The heart of SDD is the `SPEC.md` file, stored directly in your codebase alongside the code it describes. This is the ultimate authority for both developers and AI agents. Project management tools (Jira, Linear) track the *work*; the repository tracks the *truth*.

### The Anatomy of a Perfect Spec

Every feature or major flow requires a specification containing these exact sections:

* **Metadata & Dependencies:** Links to the Jira Epic, the Figma design files, and any required internal APIs or SDKs.
* **Triggers & Routing:** Exactly how a user enters this flow and the conditions that allow them to leave it.
* **Visual & UI Rules:** High-level animation notes or layout behaviors not easily captured in Figma.
* **Acceptance Criteria (BDD):** The Given/When/Then scenarios. This is the most critical section. It forces product managers to think in state machines and provides the exact blueprint for automated tests.
* **Out of Scope (Anti-Goals):** A strict list of what is *not* being built. This is the single most effective tool for preventing AI agents from hallucinating extra features and reducing token consumption.

**Example BDD Structure:**

> **Scenario:** Offline Mode Graceful Degradation
> **Given** the user is viewing the Profile Screen
> **When** the device loses network connectivity
> **Then** the "Edit Profile" button becomes disabled
> **And** an offline indicator appears in the navigation bar

---

## Chapter 3: The Contract Layer (Clean Architecture)

Once the spec is finalized, no implementation code is written. The next phase is translating the text into an architectural contract. In iOS, this usually takes the form of Clean Architecture combined with MVVM.

The contract consists solely of interfaces. This allows the AI (or a human teammate) to validate the shape of the data without getting bogged down in how the data is fetched or rendered.

1. **Domain Interfaces:** Define the `UseCases` and the `Repository` protocols. These represent the business rules outlined in the BDD scenarios. They do not know about SwiftUI or iOS frameworks.
2. **Data Interfaces:** Define the concrete types that will implement the Domain protocols (e.g., `CoreDataUserRepository`, `NetworkAuthService`).
3. **Presentation Interfaces:** Define the inputs and outputs of the ViewModel. The ViewModel is the bridge between the Domain and the UI.

By forcing an AI to pause and present this contract for your approval, you prevent it from generating hundreds of lines of useless, tightly-coupled implementation code.

---

## Chapter 4: The Testing Boundary

In SDD, tests are not an afterthought used to achieve code coverage; they are the executable version of the `SPEC.md`. You write the tests against the Contract Layer before writing the Implementation Layer.

iOS development requires a strict boundary between unit logic and UI interaction:

### Unit Tests (Swift Testing)

Apple's modern Swift Testing framework (`@Test`, `@Suite`, `#expect`) is utilized exclusively for testing the Domain and Presentation layers. Every Given/When/Then scenario in the `SPEC.md` becomes a `@Test` function. Because you are testing the ViewModel and Use Cases—not the UI—these tests run in milliseconds.

### UI Tests (XCTest)

The traditional `XCTest` framework is reserved solely for UI automation. UI tests validate that the SwiftUI views correctly bind to the ViewModel and that the operating system responds as expected (e.g., rendering system permission dialogs).

---

## Chapter 5: AI Agent Orchestration

To apply SDD with AI, you must explicitly program the agent's behavior. Left to its own devices, an LLM will skip the spec, invent an architecture, and write untestable code. You control the AI via an `AGENTS.md` (or `.cursorrules`) file at the root of your repository.

### Defining the Agent Workflow

Your `AGENTS.md` must enforce the **Phase Gate Protocol**:

1. **Phase 1 (Spec):** The agent reads or writes the `SPEC.md`. It must ask for human approval before proceeding.
2. **Phase 2 (Architecture):** The agent writes the protocols and interfaces. It stops and asks for approval.
3. **Phase 3 (Tests):** The agent writes the unit tests based on the BDD criteria.
4. **Phase 4 (Implementation):** The agent writes the SwiftUI views and business logic to turn the tests green.

### Integrating the iOS Simulator MCP

AI agents cannot genuinely "see" SwiftUI code functioning in the real world. To validate UI tests, you equip the agent with the **Model Context Protocol (MCP)**, specifically an iOS Simulator server.

1. **Exploratory Phase:** The agent uses MCP tools to read the simulator's accessibility tree, identifying exact X/Y coordinates and UI elements.
2. **Interaction:** The agent sends tap, swipe, and type commands to navigate the flow manually.
3. **Codification:** Only after manually verifying the flow via the accessibility tree does the agent generate the `XCUITest` code. This prevents the AI from hallucinating UI element identifiers.

---

## Chapter 6: The Daily Team Workflow

Implementing SDD requires a shift in how a team treats pull requests, tickets, and documentation.

**The Lifecycle of a Feature:**

1. **Ideation (Jira):** A product manager opens a ticket detailing a new requirement.
2. **Drafting (Git):** A developer (or AI) creates a new branch and updates the relevant `SPEC.md`.
3. **The Spec PR:** A Pull Request is opened containing *only* the Markdown changes. Product, Design, and Engineering debate the BDD scenarios here.
4. **Execution (Code):** Once the Spec PR is merged (or approved), the architecture, tests, and code are written.
5. **The Code PR:** The implementation PR is opened. The reviewer's primary job is no longer to decipher what the code *should* do; they simply verify that the code mathematically satisfies the `SPEC.md`.

By permanently decoupling the "What" (Specification) from the "How" (Implementation), SDD ensures your repository remains a pristine, self-documenting system that scales flawlessly with both human teams and autonomous AI agents.
