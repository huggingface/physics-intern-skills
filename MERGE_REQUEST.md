# feat: add Hermes Agent host support

## Summary

Adds Hermes Agent as a supported PhysicsIntern host alongside Claude Code, Pi, and OpenAI Codex CLI.

This PR adds the host-specific glue needed to render and run PhysicsIntern workspaces with Hermes Agent, including workspace context, role prompts, workflow skills, dispatch instructions, init-script support, and documentation.

## Changes

- Add new Hermes host configuration under `hosts/hermes/`
  - `host.toml`
  - `preamble.md`
  - `dispatch_example.md`
- Render Hermes workspaces with:
  - `AGENTS.md` as the project context file
  - `.hermes/agents/*.md` for role prompts
  - `.hermes/skills/*/SKILL.md` for workflow skills
- Add `--host=hermes` support to `commons/render.py`
- Update `init-physics-intern.sh` to:
  - accept `--host=hermes`
  - detect existing Hermes workspaces
  - include Hermes reset warnings
  - print Hermes-specific launch/setup instructions
- Update user documentation in `README.md`
- Update developer documentation in `DOCUMENTATION.md`
- Update repo context in `CLAUDE.md`

## Hermes behavior

Hermes uses:

- `AGENTS.md` for workspace/project context
- `.hermes/skills/<skill>/SKILL.md` for workspace-local PhysicsIntern skills
- `.hermes/agents/<role>.md` for sub-agent role prompts
- `delegate_task` for sub-agent dispatch

Tool capabilities are mapped to Hermes toolsets as follows:

- file read/write/edit/glob/grep -> `file`
- shell -> `terminal`
- web search/fetch -> `web`

## Usage

Create a Hermes workspace:

```bash
bash init-physics-intern.sh --host=hermes /path/to/workspace
cd /path/to/workspace
```

Make the workspace-local skills visible to Hermes:

```bash
hermes config set skills.external_dirs '["/path/to/workspace/.hermes/skills"]'
```

If `skills.external_dirs` already contains other entries, merge this path into the existing list instead of overwriting it.

Then launch Hermes from the workspace:

```bash
hermes
```

Start the workflow:

```text
/start-research
/survey
```

## Validation

Rendered all supported hosts successfully:

```bash
for host in claude pi codex hermes; do
  rm -rf "/tmp/test-physicsintern-$host"
  bash init-physics-intern.sh --host="$host" "/tmp/test-physicsintern-$host"
done
```

Successful renders were verified for:

- `claude`
- `pi`
- `codex`
- `hermes`

The Hermes render produced the expected workspace files, including:

- `AGENTS.md`
- `.hermes/agents/*.md`
- `.hermes/skills/*/SKILL.md`
- `research_log.md`

Also ran:

```bash
git diff --check
```

No whitespace errors were reported.
