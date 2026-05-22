"""Pi host configuration.

The renderer reads this dict to know how to map capabilities to tool names,
where to write rendered files, and how to shape host-specific frontmatter.
"""

HOST = {
    "name": "pi",
    "workspace_doc": "AGENTS.md",
    "agents_dir": ".pi/agents",
    "skills_dir": "skills",  # Pi keeps skills/ at workspace top level
    "prompts_dir": "prompts",  # Pi prompts/ for slash-command workflow expansion
    "tools_map": {
        "file_read": "read",
        "file_write": "write",
        "file_edit": "edit",
        "shell": "bash",
        # Pi's "glob" capability is the pair (ls, find). Joined to "ls, find".
        "glob": "ls, find",
        "grep": "grep",
        "web_search": "web_search",
        "web_fetch": "fetch_content",
    },
    "agent_frontmatter_order": ["name", "description", "thinking", "tools", "output"],
    "agent_extra_fields": {
        "thinking": "high",
    },
    # File-backed values: each is loaded from hosts/<host>/<filename> at render
    # time. Missing files yield an empty string.
    "file_backed": {
        "preamble": "preamble.md",
        "dispatch_example": "dispatch_example.md",
        "skill_stub_template": "skill_stub.md.tmpl",
    },
}
