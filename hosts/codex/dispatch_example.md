Call `spawn_agent` with the role name as `agent_type` and the brief reference as `message` (the role is one of the auto-discovered `.codex/agents/*.toml` files); keep `fork_context` false so the worker starts from a clean context. The call returns an agent id. Example for a `/derive` on a fresh artefact:

```json
{
  "agent_type": "deriver",
  "message": "Read derivations/.briefs/D-007-brief.md. Per your role definition in .codex/agents/deriver.toml, perform the work and write derivations/D-007.md with the structured ## Summary / ## Result / ## Flags at the top.",
  "fork_context": false
}
```

Then block on the returned id with `wait_agent` — `{"targets": ["<agent-id>"], "timeout_ms": 600000}` — to wait until the worker finishes and return its last message. Substitute the actual artefact ID and agent name. For skills without a brief (`/review`, `/critique`, `/survey`, `/finalize`, `/research-plan`), put the small context inline in `message` instead.

`spawn_agent` and `wait_agent` are Codex's multi-agent tools (enabled by default in current Codex). The exact parameter names above (`agent_type`, `message`, `fork_context`, `targets`, `timeout_ms`) can drift between Codex versions — if dispatch breaks after an upgrade, check this file first for tool-name/parameter drift.
