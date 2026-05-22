Call `spawn_agent` (Codex `multi_agents_v2`) with the role name as `agent_type`, a slug as `task_name`, and the brief reference as `message`. Block on the reply with `wait_agent`. Example for a `/derive` on a fresh artefact:

```json
{
  "agent_type": "deriver",
  "task_name": "derive_d007",
  "message": "Read derivations/.briefs/D-007-brief.md. Per your role definition in .codex/agents/deriver.toml, perform the work and write derivations/D-007.md with the structured ## Summary / ## Result / ## Flags at the top.",
  "fork_turns": "none"
}
```

Then call `wait_agent` with `{"task_name": "derive_d007"}` to block until the worker finishes and return its `last_task_message`. Substitute the actual artefact ID and agent name. For skills without a brief (`/review`, `/critique`, `/survey`, `/finalize`, `/research-plan`), put the small context inline in `message` instead.

`spawn_agent` and `wait_agent` live in Codex's `multi_agents_v2` namespace, which is under active OpenAI development; if dispatch breaks after a Codex upgrade, check this file first for tool-name drift.
