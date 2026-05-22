Call the `subagent` tool from `pi-subagents`. Example for a `/derive` on a fresh artefact:

```json
{
  "tasks": [
    {
      "agent": "deriver",
      "task": "Read derivations/.briefs/D-007-brief.md. Per .pi/agents/deriver.md, perform the work and write derivations/D-007.md with the structured ## Summary / ## Result / ## Flags at the top.",
      "output": "derivations/D-007.md"
    }
  ],
  "concurrency": 1,
  "failFast": false
}
```

Substitute the actual artefact ID and agent name. For skills without a brief (`/review`, `/critique`, `/survey`, `/finalize`, `/research-plan`), put the small context inline in the `task` string instead.
