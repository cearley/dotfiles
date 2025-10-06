# User Memory

## Code Preferences
- Prefer concise, readable code
- Use meaningful variable names
- Follow existing project conventions

## Git Workflow Preferences

### CRITICAL: Git Commit and Push Protocol

**NEVER make git commits without explicit user consent**
- Make code changes locally
- STOP and ask user: "Would you like me to commit these changes?"
- Wait for explicit confirmation (e.g., "yes", "go ahead and commit")
- Only then execute `git commit`

**NEVER push to GitHub without explicit user consent**
- After committing (with permission), STOP again
- Ask user: "Would you like me to push this to GitHub?"
- Wait for explicit confirmation (e.g., "yes, push it", "go ahead")
- Only then execute `git push`

### Correct Workflow Example

1. Make code changes locally
2. Ask: "Would you like me to commit these changes?"
3. User responds: "yes"
4. Execute git commit
5. Ask: "The changes have been committed locally. Would you like me to push to GitHub?"
6. User responds: "yes, push it"
7. Execute git push

### Key Principles

- Two separate permission gates: one for commit, one for push
- Never assume permission from context
- Always explicit confirmation required
- Applies to ALL projects and repositories

## Strategic Analysis Framework
When approaching any task, apply this analytical framework to ensure solutions are thoughtful, robust, and well-aligned with the user's underlying goals. Avoid jumping directly to implementation.

### 1. Deconstruct the Request
- **Clarify Intent**: What is the user's ultimate goal? What problem are they *really* trying to solve?
- **Challenge Assumptions**: Is the user's proposed solution the best one? Are there unstated assumptions in the request?
- **Identify Constraints**: What are the technical, business, or user-facing constraints?
- **Define Success**: What does a successful outcome look like?

### 2. Analyze the Ecosystem
- **System-wide Impact**: How will this change affect other parts of the system?
- **Integration Points**: How does this interact with existing tools, APIs, or workflows?
- **Dependencies**: What new dependencies are introduced? Could this conflict with existing ones?
- **Future-Proofing**: Does this align with the project's long-term direction? Will it be maintainable?

### 3. Propose a Spectrum of Solutions
- **Simple & Safe**: The minimal, low-risk implementation.
- **Recommended Approach**: The balanced solution that best fits the context.
- **Ambitious/Full-Featured**: The "gold standard" solution if time and resources were unlimited.
- **Alternative Paradigms**: Completely different ways to think about the problem.

### 4. Articulate Clear Trade-offs
For each proposed solution, explicitly state the trade-offs:
- **Complexity vs. Maintainability**: How difficult is it to build versus to support long-term?
- **Performance vs. Scalability**: How does it perform now, and how will it scale with growth?
- **Security vs. Usability**: Does it introduce risks, or does it create friction for the user?
- **Flexibility vs. Simplicity**: How adaptable is the solution versus how easy is it to understand?

### 5. Identify Patterns and Anti-Patterns
- **Classify the Pattern**: Is the proposed solution a recognized good pattern, an anti-pattern, or context-dependent?
- **Cite Precedent**: How have other major projects or ecosystems solved similar problems?
- **Anticipate Failure Modes**: What are the most likely ways this solution could fail, break, or be misused?

## Large-Scale Analysis
When a request requires understanding or modifying a large volume of code that exceeds your available context window, use tools or strategies designed for large-scale analysis.

### Triggers for Large-Scale Analysis
- **Codebase-wide questions**: Analyzing or searching across an entire project or many directories.
- **Cross-file comparisons**: Comparing or finding relationships between multiple large files.
- **Architectural review**: Understanding project-wide patterns, dependencies, or high-level structure.
- **Context overflow**: The total size of relevant files exceeds your context capacity (e.g., >100KB).
- **Broad verification**: Verifying if features, patterns, or security measures are implemented across the entire codebase.

### Best Practices for Large-Scale Tools
- **Specify Scope**: Clearly define the files, directories, or patterns to be analyzed.
- **Be Specific**: Ask precise questions to get accurate and relevant results.
- **Leverage Full Context**: Utilize tools that can process entire codebases to avoid fragmented analysis.
- **Use Relative Paths**: When referencing files for analysis, use paths relative to the project root.
