
## Hermes host notes

- Use Hermes' file tools for source inspection and edits: `read_file`, `search_files`, `write_file`, and `patch`. Do not use shell commands such as `cat`, `head`, `grep`, `find`, or `sed` when the file tools can do the job.
- Use the `terminal` tool for git, Python runs, package managers, and long-running shell work. Give long computations explicit timeouts.
- Use `delegate_task` for every PhysicsIntern sub-agent dispatch. The main agent remains the coordinator and must not do the sub-agent's substantive work itself.
- A `delegate_task` return is a self-report. After every dispatch, verify the expected artefact by reading the file the sub-agent wrote before integrating or telling the user it succeeded.
- Leaf delegate sub-agents cannot ask the user questions. If they lack context, they must write the best partial artefact and report the gap in `## Flags`.
