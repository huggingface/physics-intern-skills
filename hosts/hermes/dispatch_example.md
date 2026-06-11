Use Hermes' `delegate_task` tool. For example, for `/derive D-007`, first write `derivations/.briefs/D-007-brief.md`, then dispatch a leaf sub-agent with a compact goal, the role file path, the brief path, and the required output path:

```
delegate_task(
  goal="Perform the PhysicsIntern deriver task for D-007 and write derivations/D-007.md.",
  context="You are a PhysicsIntern deriver sub-agent. First read and follow the role prompt at .hermes/agents/deriver.md. Then read derivations/.briefs/D-007-brief.md. Write exactly one artefact at derivations/D-007.md and return the same ## Summary / ## Result / ## Flags block that appears at the top of that file.",
  toolsets=["file", "terminal"]
)
```

Use the analogous role file and output path for `surveyor`, `planner`, `computer`, `reviewer`, `critic`, and `finalizer`; include `web` in `toolsets` for survey/literature tasks and `terminal` for computation tasks. After the delegate returns, read the expected artefact file yourself and only then run the integration loop.
