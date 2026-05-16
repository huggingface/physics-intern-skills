# Next steps

Open methodology items. Closed items live in git history, not here.

## Substantive review quality on harder problems

`/review` performed strongly on the QEC run (independent re-implementation, separate density-matrix path). Whether this holds on problems where the *natural* review path is harder than the original computation — i.e. the reviewer can't just re-derive from scratch in a different way — is unknown.

What to look for in upcoming runs:
- Reviews that confirm without independently re-doing the work (rubber-stamping).
- Reviews that re-use the same method as the original artefact (insufficient adversarial coverage).
- Cases where the reviewer flags an issue but the main agent doesn't seek a second opinion before acting.

If this fails on a harder problem, candidate counters: stricter prompt-level adversarial framing in `reviewer.md`; mandatory second-opinion `/review` on any `/derive` or `/compute` underlying an Established Result; or a method-diversity check in `/critique`.

## Deferred (tracked, not active)

- **`/upgrade-physics-intern-workspace`** — propagate methodology changes to existing workspaces. Manual patching is the only path today; not blocking.
- **MCP integrations** — `mcp-arxiv`, `mcp-papers`, `mcp-mathematica`, tensor-algebra backends. None ship.
- **Pi adapter** — only Claude Code is supported today.
