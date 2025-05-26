# Maestro: AI-Powered Task Orchestration System

**Maestro** is an intelligent task orchestration system designed to manage and execute complex projects by leveraging a team of specialized AI agents. It parses daily standup notes in Markdown format, decomposes goals into atomic tasks, and intelligently routes these tasks to the most suitable specialist agent for execution.

## Key Features

*   **Markdown-Based Task Management:** Parses tasks directly from `.md` standup files.
*   **Intelligent Agent Routing:** Dynamically assigns tasks to specialist agents based on skill matching and role relevance.
*   **Specialist AI Agent Ecosystem:** Supports a variety of agents, each with unique skills (e.g., Research, Documentation, Swift Development, QA, Tokenomics, etc.).
*   **Extensible Agent Architecture:** Easily add new specialist agents with custom roles, skills, and execution logic.
*   **Automated Task Execution:** Agents can perform actions like research, code generation, documentation writing, and more.
*   **LLM Integration:** Utilizes Large Language Models (Anthropic, Ollama for local Llama 3.2/CodeLlama) for agent reasoning and content generation.
*   **Progress Tracking & Reporting:** Updates the standup file with task statuses (✅, ❌, 🔄), timestamps, generated files, and PR links. Generates detailed execution reports.
*   **Quality & Complexity Awareness:** Tasks can be defined with quality levels (Standard/High/Critical) and complexity (Simple/Medium/Complex) to guide agent execution.
*   **Mock Modes:** Supports mock modes for API services (Anthropic, Ollama) for testing without actual API calls.
*   **Version Control Integration (Planned):** Future support for Git operations like branching, conventional commits, and PR creation via `gh`.

## Generating Your Daily Task File (Standup Preparation)

Before running Maestro to execute tasks, you first need a well-defined Markdown task file. The project includes a framework to help you generate this file by interacting with a Large Language Model (LLM) of your choice (e.g., ChatGPT, Claude, or a local Ollama model via a separate chat interface).

This process simulates a guided standup session with an "AI Standup Manager" to break down your high-level goals into the atomic, structured tasks that Maestro requires.

**Steps:**

1.  **Prime the LLM:** Start a new conversation with your chosen LLM. Provide it with the role prompt defined in [`docs/standup-agent-role-prompt.md`](docs/standup-agent-role-prompt.md). This sets the context for the LLM to act as an expert AI Standup Manager.
2.  **Follow the Framework:** Engage in a dialogue with the LLM, following the principles and questions outlined in the [`docs/standup-agent-framework.md`](docs/standup-agent-framework.md). This includes:
    *   Discussing your accomplishments, current work, and blockers.
    *   Exploring and clarifying your objectives for the day.
    *   Using the **Task Breakdown Methodology** to decompose your goals into smaller, atomic tasks.
3.  **Format Tasks:** Ensure each atomic task is specified according to the template found in [`docs/task-specification-template.md`](docs/task-specification-template.md). This format is crucial for Maestro to correctly parse and execute the tasks.
4.  **Produce the Standup File:** The output of this collaborative session should be a Markdown file named using the convention `YYYY-MM-DD-standup.md` (e.g., `2025-05-28-standup.md`). This file will contain your high-level objectives and the detailed atomic tasks ready for Maestro.

Once you have this `YYYY-MM-DD-standup.md` file, you can then proceed to use Maestro to execute the tasks as described in the "Usage" section below.

## Architecture Overview

Maestro's architecture consists of a central `ManagerAgent` and a suite of `SpecialistAgent` implementations:

1.  **Standup File Parsing:** The `ManagerAgent` reads a Markdown file (e.g., `daily-standup.md`) containing a list of tasks. Each task includes:
    *   Title
    *   Goal
    *   Acceptance Criteria
    *   Complexity (Simple/Medium/Complex)
    *   Quality Level (Standard/High/Critical)
    *   Skills Needed (comma-separated)
    *   Resources
    *   Status (automatically updated)
2.  **Task Decomposition & Prioritization:** (Currently manual in the standup file, future enhancement for more automation)
3.  **Agent Selection:** For each incomplete task, the `ManagerAgent` identifies the most suitable `SpecialistAgent` by:
    *   Scoring skill matches (+10 per matching skill).
    *   Adding a bonus for role keyword matches (+5).
4.  **Task Execution:**
    *   The selected `SpecialistAgent` receives the task details and a specialized prompt.
    *   The agent interacts with an LLM (Anthropic or local Ollama models) to generate a plan or content.
    *   The agent's code then acts on the LLM output (e.g., writes files, performs analysis).
5.  **Result Processing & Reporting:**
    *   The `ManagerAgent` receives a `TaskResult` (including status, content, generated files, PR URLs).
    *   The original Markdown standup file is updated with the task's new status emoji, completion timestamp, and any generated artifacts.
    *   Progress is saved, and a final execution report is generated.

## Setup & Installation

Maestro is a Swift Package Manager project.

1.  **Prerequisites:**
    *   macOS
    *   Swift toolchain (Xcode or command-line tools)
    *   (Optional) Ollama installed and running if you wish to use local LLMs. Ensure models like `llama3.2:3b` or `codellama:7b` are pulled.
    *   (Optional) Anthropic API key set as an environment variable (`ANTHROPIC_API_KEY`) for Claude models.
2.  **Clone the Repository:**
    ```bash
    git clone <repository_url>
    cd Maestro
    ```
3.  **Build the Project:**
    ```bash
    swift build
    ```

## Usage

To run Maestro, execute the compiled binary with the path to your standup Markdown file:

```bash
swift run Maestro <path_to_your_standup_file.md>
```

For example:

```bash
swift run Maestro ../daily_tasks/2025-05-27-standup.md
```

Maestro will then:
*   Load incomplete tasks from the specified file.
*   Execute them sequentially using the best-matched specialist agents.
*   Update the standup file in place with task statuses and results.
*   Generate `execution-progress-[timestamp].json` and `execution-report-[timestamp].md` files in the `reports/[run_timestamp]` directory.

### Environment Variables

*   `ANTHROPIC_API_KEY`: Your Anthropic API key. If not provided, AnthropicAPI will run in mock mode.
*   `OLLAMA_API_BASE_URL`: Defaults to `http://localhost:11434`. Override if your Ollama instance is elsewhere.
*   `OLLAMA_DEFAULT_MODEL`: Defaults to `llama3.2:3b`.
*   `OLLAMA_CODE_MODEL`: Defaults to `codellama:7b`.
    *(Note: If Ollama is unavailable or models aren't pulled, OllamaAPI falls back to mock mode).*

## Specialist Agents

Maestro includes the following specialist agents (and can be extended):

*   **`ResearchAgent` (Role: "Market Research Specialist"):** Performs market research, competitive analysis, tool evaluation.
*   **`SwiftDeveloperAgent` (Role: "Swift Developer"):** Focuses on Swift development tasks, particularly for macOS/SwiftUI/MVVM. Can verify code using `xcodebuild`.
*   **`QAReviewAgent` (Role: "QA Review Specialist"):** Handles automated checks, AI code review, and GitHub integration for QA.
*   **`DocumentationAgent` (Role: "Documentation Specialist"):** Creates technical documentation, user guides, API documentation in Markdown.
*   **`StrategyAgent` (Role: "Strategy Specialist"):** Deals with strategic planning and decision-making tasks.
*   **`DevOpsAgent` (Role: "DevOps Specialist"):** Handles DevOps related tasks like environment setup.
*   **`TokenomicsAgent` (Role: "Tokenomics Specialist"):** Designs and analyzes token economic models.
*   **`TechnicalResearchAgent` (Role: "Technical Research Specialist"):** Conducts in-depth technical research, protocol analysis, and feasibility studies.
*   **`InfrastructureAgent` (Role: "Infrastructure Specialist"):** Manages infrastructure planning and evaluation.
*   **`MentorAgent` (Role: "Technical Mentor"):** Provides guidance and knowledge transfer.
*   **`ArchitectureAgent` (Role: "Architecture Specialist"):** Designs system and software architecture.

## Standup File Format

Tasks in the Markdown standup file should follow this general structure under a section like `### Atomic Tasks`:

```markdown
**Task <Number>**: <Task Title>
- **Goal**: <Detailed goal of the task>
- **Acceptance Criteria**: 
  - [ ] Criterion 1
  - [ ] Criterion 2
- **Complexity**: <Simple | Medium | Complex>
- **Quality Level**: <Standard | High | Critical>
- **Skills Needed**: <skill1, skill2, skill3>
- **Resources**: <resource1, link_to_doc, etc.>
- **Testing Requirements**: <Description of testing needed>
- **Documentation Requirements**: <Description of documentation needed>
- **Success Indicators**: <How success is measured>
- **Status**: <Not Started | In Progress | Completed | Failed> (This line is automatically updated)
```
Lines like `- Generated Files:` or `- Pull Request:` will be automatically added by Maestro upon task completion.

## Future Enhancements

*   Parallel task execution where appropriate.
*   More sophisticated task dependency management.
*   Enhanced UI for visualizing agent progress and task status.
*   Deeper integration with version control systems (automated PRs, branch management).
*   Inter-agent communication and collaboration on complex tasks.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.