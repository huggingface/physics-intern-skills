Dispatch a sub-agent role (see `.opencode/agents/<name>.md`, each `mode: subagent`) with the **`task`** tool — give it the role name and a self-contained prompt. Example for a `/derive` on a fresh artefact:

```
task(
  subagent_type="deriver",
  description="derive D-007",
  prompt="Read derivations/.briefs/D-007-brief.md. Follow your role definition. Write derivations/D-007.md with the structured ## Summary / ## Result / ## Flags at the top."
)
```

Substitute the actual artefact ID. For skills without a brief (`/review`, `/critique`, `/survey`, `/finalize`, `/research-plan`), pass the small context inline in the `prompt` string instead. The manual alternative is to `@<name>`-mention the role in a message (e.g. `@deriver …`).

> **Caveat (verify on your OpenCode version).** Dispatching *custom* sub-agents via `task`/`@mention` has been version-dependent — older builds hardcoded `subagent_type` to the built-ins (`explore`/`general`/`mary`) and ignored custom roles (see opencode issue #29616). If your OpenCode cannot dispatch these roles, run the step in the main-agent context instead (read the role file at `.opencode/agents/<name>.md` and follow it inline) — the methodology still holds, only the context isolation is lost.
