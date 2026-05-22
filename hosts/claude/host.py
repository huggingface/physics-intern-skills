"""Claude Code host configuration.

The renderer reads this dict to know how to map capabilities to tool names,
where to write rendered files, and how to shape host-specific frontmatter.
"""

HOST = {
    "name": "claude",
    "workspace_doc": "CLAUDE.md",
    "agents_dir": ".claude/agents",
    "skills_dir": ".claude/skills",
    "tools_map": {
        "file_read": "Read",
        "file_write": "Write",
        "file_edit": "Edit",
        "shell": "Bash",
        "glob": "Glob",
        "grep": "Grep",
        "web_search": "WebSearch",
        "web_fetch": "WebFetch",
    },
    # Agent frontmatter: which manifest fields to emit, in order, and how.
    # Claude needs: name, description, tools.
    # Capabilities are joined with ", " using tools_map.
    "agent_frontmatter_order": ["name", "description", "tools"],
    "agent_extra_fields": {},  # no extras for Claude
    # File-backed values: each is loaded from hosts/<host>/<filename> at render
    # time. Missing files yield an empty string — Claude has no preamble.md.
    "file_backed": {
        "preamble": "preamble.md",
        "dispatch_example": "dispatch_example.md",
    },
}
