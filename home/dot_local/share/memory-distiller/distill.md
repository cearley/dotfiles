# Memory distillation instructions

Distil the supplied Claude Code transcript into durable, high-signal observations.

- Use the basic-memory tools only with an explicit `project=` argument.
- Write only the project's machine-owned `Distilled Sessions` note. Never write curated notes;
  never edit, move, or delete them, including `Chezmoi Session Notes` and `Chezmoi Current Status`.
- Prefix each observation with a fitting `[category]` such as `[decision]`, `[fact]`, `[problem]`,
  `[solution]`, `[requirement]`, or `[gotcha]`.
- Link related concepts with `[[wikilinks]]` when the target is clear and useful.
- Preserve decisions, constraints, verified results, failures, follow-up work, and non-obvious
  techniques. Omit routine command output, transient chatter, and unsupported inference.
- Be concise, concrete, and evidence-based. Do not invent facts or claim a change was verified
  unless the transcript provides that evidence.
