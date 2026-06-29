Use the `Task` tool with `subagent_type` set to the agent name (see `.opencode/agents/<name>.md`). Example for a `/derive` on a fresh artefact:

```
Task(
  description="derive D-007",
  subagent_type="deriver",
  prompt="Read derivations/.briefs/D-007-brief.md. Follow your role definition. Write derivations/D-007.md with the structured ## Summary / ## Result / ## Flags at the top."
)
```

Substitute the actual artefact ID. For skills without a brief (`/review`, `/critique`, `/survey`, `/finalize`, `/research-plan`), pass the small context inline in the `prompt` string instead.
