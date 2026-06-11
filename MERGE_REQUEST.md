# feat: add Hermes Agent host

## Summary

- Add Hermes Agent as a supported PhysicsIntern host alongside Claude Code, Pi, and OpenAI Codex CLI.
- Render Hermes workspaces with `AGENTS.md`, `.hermes/agents/*.md`, and `.hermes/skills/*/SKILL.md`.
- Add Hermes-specific host glue under `hosts/hermes/`:
  - `host.toml`
  - `preamble.md`
  - `dispatch_example.md`
- Update `commons/render.py` so `--host=hermes` is accepted and Hermes uses the single-file `SKILL.md` skill layout.
- Update `init-physics-intern.sh` to validate, detect, reset, render, and print launch instructions for Hermes workspaces.
- Update README/developer documentation to describe Hermes setup, skill installation, dispatch behavior, and host architecture.

## Hermes conventions added

- Workspace context file: `AGENTS.md`
- Workspace-local skills: `.hermes/skills/<skill>/SKILL.md`
- Role prompts: `.hermes/agents/<role>.md`
- Sub-agent dispatch: Hermes `delegate_task`
- Toolset mapping:
  - file read/write/edit/glob/grep capabilities -> `file`
  - shell capability -> `terminal`
  - web search/fetch capabilities -> `web`

## User-facing setup

Create a Hermes workspace:

```bash
bash init-physics-intern.sh --host=hermes /path/to/workspace
cd /path/to/workspace
```

Make the workspace-local PhysicsIntern skills visible to Hermes:

```bash
hermes config set skills.external_dirs '["/path/to/workspace/.hermes/skills"]'
```

If `skills.external_dirs` already has entries, merge `/path/to/workspace/.hermes/skills` into the existing list instead of overwriting it.

Then start a fresh Hermes session in the workspace:

```bash
hermes
```

And begin the workflow:

```text
/start-research
/survey
```

## Validation performed

Rendered all supported hosts successfully:

```bash
for host in claude pi codex hermes; do
  rm -rf "/tmp/test-physicsintern-$host"
  bash init-physics-intern.sh --host="$host" "/tmp/test-physicsintern-$host"
done
```

Observed successful renders for:

- `claude`
- `pi`
- `codex`
- `hermes`

Hermes render produced the expected files, including:

- `/tmp/test-physicsintern-hermes/AGENTS.md`
- `/tmp/test-physicsintern-hermes/.hermes/agents/*.md`
- `/tmp/test-physicsintern-hermes/.hermes/skills/*/SKILL.md`
- `/tmp/test-physicsintern-hermes/research_log.md`

Also ran:

```bash
git diff --check
```

No whitespace errors were reported before committing.

## Commit and branch

Branch:

```text
add-hermes-host
```

Commit:

```text
a76cd7e feat: add Hermes Agent host
```

Remote repository:

```text
git@github.com:gabrieldlm/physics-intern-skills.git
```

Pull request URL:

```text
https://github.com/gabrieldlm/physics-intern-skills/pull/new/add-hermes-host
```
