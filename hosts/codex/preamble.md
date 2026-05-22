
## 0. Tool discipline (read first)

Tool names are literal. Use only tools visible in the current tool set.

- File reads happen via `shell_command` (`cat`, `head`, `tail`) — there is no native `read_file` tool.
- File writes and edits happen via `apply_patch` — there is no separate `write_file` or `edit_file`.
- Search: `shell_command` (`grep`, `rg`, `find`, `ls`) — no native `glob` / `grep` tools.
- Web: `web_search` (hosted) for queries; specific URLs go through `shell_command` (`curl`) — no native `web_fetch`.
- Sub-agent dispatch: `spawn_agent` (from `multi_agents_v2`) to launch a worker, then `wait_agent` to block until it returns. Do not use `spawn_agents_on_csv` — that is the CSV fan-out variant and is the wrong shape for one-brief-at-a-time dispatch.
- If a tool returns `Tool not found`, do not retry the same invalid call — map to the canonical visible tool, or record the capability as blocked and continue with a written artefact.
