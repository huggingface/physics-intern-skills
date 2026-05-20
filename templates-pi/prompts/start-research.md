---
description: One-time bootstrap from problem.md — extract a one-line summary and substitute the {{PROBLEM_ONELINER}} placeholders in AGENTS.md and research_log.md.
section: PhysicsIntern Workflows
---

## Tool discipline (read first)

Tool names are literal and lowercase. Use only tools visible in the current tool set.

- File I/O: `read`, `write`, `edit`. Search: `grep`, `find`, `ls`. Shell: `bash`.
- Do not call `WebSearch`, `WebFetch`, `Task`, or any non-existent alias.

## What this skill does

The workspace was bootstrapped by `init-physics-intern.sh` and the user has (hopefully) edited `problem.md`. Your job is the small, one-time prep step that turns the skeleton into a ready-to-go workspace.

This skill runs in the **main-agent context** — it does **not** dispatch a `subagent`. The work is purely mechanical (file reads, substitutions, one commit).

## Steps

1. **Read `problem.md`.** Confirm the user has filled it in: the `### Problem setup` and `### Main question` sections must not still contain the placeholder text (`<describe the system…>` / `<state the question…>`). If either placeholder is still present, stop and tell the user:

   > `problem.md` still has placeholder text in `### Problem setup` and/or `### Main question`. Please fill these in and re-run `/start-research`.

2. **Extract a one-liner** (≤100 chars) summarising the main question. Prefer the `### Main question` content; fall back to the first non-empty, non-header paragraph if that section is terse or unhelpful. Strip leading `#`, trailing punctuation, and trailing whitespace. Keep it dense — this is the workspace header you (the main agent) will see at the top of `AGENTS.md` every session.

3. **Substitute `{{PROBLEM_ONELINER}}`** with the one-liner in:
   - `./AGENTS.md`
   - `./research_log.md`

   Both files were copied from templates with the placeholder intact. If the placeholder is already absent from both files, `/start-research` has already run — tell the user and exit without changes.

4. **Commit** the substitution:

   ```
   start-research: fill workspace header from problem.md
   ```

5. **Report** to the user:

   > Workspace header set: "<one-liner>".
   >
   > Suggested next step: `/survey` to begin landscape orientation.
   > (Or `/research-plan` directly if the landscape is already familiar, or `/autoresearch` to drive the whole pipeline autonomously.)

## When invoked from /autoresearch

If you were invoked from `/autoresearch` (it will say so in `$@` or via context), do steps 1–4 the same way, but return a structured reply instead of the human-facing report:

```
## Summary
Workspace header set from problem.md.

## Result
- one-liner: "<the one-liner>"
- files updated: AGENTS.md, research_log.md
- commit: <hash>
```

The autoresearch loop will then continue with `/survey`.

## Notes

- If `problem.md` does not exist at all, stop and tell the user to run `init-physics-intern.sh` first.
- This skill is idempotent in spirit (re-running after success is a no-op with a message) but not destructive: it never rewrites a header that has already been substituted.
