#!/usr/bin/env python3
"""Render PhysicsIntern workspace files for a given host.

Usage:
  render.py --host=claude|pi --target=<dir>

Reads source files under src/ (host-agnostic methodology) and host configuration
under hosts/<host>/, and writes rendered files into <target>.

Source files use mustache-style placeholders ({{workspace_doc}}, {{agents_dir}})
that are substituted from the host config. Agent capabilities (file_read, glob,
…) are translated to host-specific tool names via hosts/<host>/host.py.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import shutil
import sys
import tomllib
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ----- frontmatter parsing -----

_frontmatter = load_module(SCRIPT_DIR / "frontmatter.py", "frontmatter")


# ----- placeholder substitution -----

def substitute(text: str, host: dict) -> str:
    """Replace {{key}} placeholders with values from host config."""
    def repl(m: re.Match) -> str:
        key = m.group(1).strip()
        if key in host:
            return str(host[key])
        raise KeyError(f"Unknown placeholder: {{{{{key}}}}}")
    return re.sub(r"\{\{\s*([a-z_]+)\s*\}\}", repl, text)


# ----- frontmatter emission -----

# Characters that, if they appear at the start of a plain scalar, force quoting.
_YAML_RESERVED_STARTERS = set("?:,[]{}#&*!|>'\"%@`")
_YAML_RESERVED_WORDS = {"true", "false", "null", "yes", "no", "on", "off", "~"}
_NUMERIC_RE = re.compile(r"^-?\d+(\.\d+)?([eE][+-]?\d+)?$")


def yaml_scalar(value) -> str:
    """Format a Python value as a YAML scalar, quoting only when required.

    Quotes if the plain-scalar form would be ambiguous: reserved starting
    characters, reserved words (true/false/null/…), numeric-looking strings,
    leading/trailing whitespace, the `: ` key separator, or the ` #` comment
    starter. Uses double quotes unless the value contains `"`, in which case
    single quotes with `''` escaping are used.
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    s = str(value)
    if not s:
        return '""'
    needs_quotes = (
        s[0] in _YAML_RESERVED_STARTERS
        or s[0].isspace()
        or s[-1].isspace()
        or s.lower() in _YAML_RESERVED_WORDS
        or bool(_NUMERIC_RE.match(s))
        or ": " in s
        or " #" in s
    )
    if not needs_quotes:
        return s
    if '"' not in s:
        return f'"{s}"'
    return "'" + s.replace("'", "''") + "'"


def render_tools(capabilities: list[str], host: dict) -> str:
    """Map a list of capabilities to a host-specific tool list string."""
    parts = []
    for cap in capabilities:
        mapped = host["tools_map"].get(cap)
        if mapped is None:
            raise KeyError(f"Capability {cap!r} not in tools_map for {host['name']}")
        parts.append(mapped)
    return ", ".join(parts)


def render_agent_frontmatter(meta: dict, host: dict) -> str:
    """Emit the host-specific YAML frontmatter for an agent."""
    fields: dict[str, Any] = {
        "name": meta["name"],
        "description": meta["description"],
    }

    # Tools from capabilities
    if "capabilities" in meta:
        fields["tools"] = render_tools(meta["capabilities"], host)

    # Output pattern (Pi uses it; Claude omits)
    if "output_pattern" in meta:
        fields["output"] = meta["output_pattern"]

    # Host extras (Pi adds thinking: high)
    for key, value in host.get("agent_extra_fields", {}).items():
        fields[key] = value

    # Emit in host-specified order
    lines = ["---"]
    for key in host["agent_frontmatter_order"]:
        if key in fields:
            lines.append(f"{key}: {yaml_scalar(fields[key])}")
    lines.append("---")
    return "\n".join(lines)


# ----- main rendering -----

def render_agent(src_path: Path, host: dict, target: Path) -> None:
    """Render a single agent file from src/agents/<name>.md to the workspace."""
    meta, body = _frontmatter.read(src_path)
    body = substitute(body, host)
    frontmatter = render_agent_frontmatter(meta, host)

    # Source bodies omit the heading; the host can prepend one via
    # `agent_body_prefix` (with `{{name_cap}}` interpolated).
    prefix_template = host.get("agent_body_prefix", "")
    prefix = prefix_template.replace("{{name_cap}}", meta["name"].capitalize())
    content = f"{frontmatter}\n\n{prefix}{body.lstrip()}"

    out_path = target / host["agents_dir"] / f"{meta['name']}.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content)


def render_agents(host: dict, target: Path) -> int:
    """Render all agents from src/agents/. Returns count."""
    src_dir = ROOT / "src" / "agents"
    count = 0
    for src_path in sorted(src_dir.glob("*.md")):
        render_agent(src_path, host, target)
        count += 1
    return count


# ----- skill rendering -----

def _pi_stub_body(meta: dict, host: dict) -> str:
    """Generate the Pi skills/<name>/SKILL.md stub body from manifest fields."""
    name = meta["name"]
    agent = meta.get("agent")
    agents_used_line = (
        f"Agents used: `{agent}`." if agent else "Agents used: none (runs in main-agent context)."
    )
    output = meta.get("output_pattern")
    if output:
        suffix = " (next available number)" if meta.get("artefact_kind") else ""
        output_block = f"\n\nOutput: `{output}`{suffix}"
        brief = meta.get("brief")
        if brief:
            output_block += f". Brief written to `{brief}` before dispatch"
        output_block += "."
    else:
        output_block = ""
    ctx = {
        "title": name.replace("-", " ").capitalize(),
        "name": name,
        "agents_used_line": agents_used_line,
        "output_block": output_block,
    }
    return substitute(host["skill_stub_template"], ctx)


def _emit_yaml(fields: list[tuple[str, object]]) -> str:
    """Emit `---`-delimited YAML frontmatter from an ordered list of (key, value)."""
    lines = ["---"]
    for key, value in fields:
        lines.append(f"{key}: {yaml_scalar(value)}")
    lines.append("---")
    return "\n".join(lines)


def render_skill(src_path: Path, host: dict, target: Path) -> None:
    """Render a single skill from src/skills/<name>.md to host-specific paths."""
    meta, body = _frontmatter.read(src_path)
    body = substitute(body, host)
    name = meta["name"]

    if host["name"] == "claude":
        fields: list[tuple[str, object]] = [
            ("name", name),
            ("description", meta["description"]),
        ]
        args_hint = meta.get("arguments_hint", "")
        if args_hint:
            # Claude uses `argument-hint:` (singular, hyphenated)
            fields.append(("argument-hint", args_hint))
        out_path = target / host["skills_dir"] / name / "SKILL.md"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(f"{_emit_yaml(fields)}\n\n{body.lstrip()}")
        return

    if host["name"] == "pi":
        # Pi emits two files: a stub under skills/ and the full workflow under prompts/.

        # 1. Stub: skills/<name>/SKILL.md
        stub_fields = [("name", name), ("description", meta["description"])]
        stub_path = target / host["skills_dir"] / name / "SKILL.md"
        stub_path.parent.mkdir(parents=True, exist_ok=True)
        stub_path.write_text(f"{_emit_yaml(stub_fields)}\n\n{_pi_stub_body(meta, host)}")

        # 2. Prompt: prompts/<name>.md
        prompt_fields: list[tuple[str, object]] = [("description", meta["description"])]
        args_hint = meta.get("arguments_hint", "")
        if args_hint:
            prompt_fields.append(("args", args_hint))
        prompt_fields.append(("section", "PhysicsIntern Workflows"))
        # Pi convention: every workflow is invocable as a top-level slash command
        # by default. A skill can opt out with `top_level_cli: false` in its
        # manifest (e.g. /autoresearch — driven from the main-agent context
        # rather than offered as a fresh command).
        if meta.get("top_level_cli", True):
            prompt_fields.append(("topLevelCli", True))

        prompt_body = host.get("preamble", "").lstrip() + "\n" + body.lstrip()
        prompt_path = target / host["prompts_dir"] / f"{name}.md"
        prompt_path.parent.mkdir(parents=True, exist_ok=True)
        prompt_path.write_text(f"{_emit_yaml(prompt_fields)}\n\n{prompt_body}")
        return

    raise ValueError(f"Unknown host: {host['name']}")


def render_skills(host: dict, target: Path) -> int:
    """Render all skills from src/skills/. Returns count."""
    src_dir = ROOT / "src" / "skills"
    count = 0
    for src_path in sorted(src_dir.glob("*.md")):
        render_skill(src_path, host, target)
        count += 1
    return count


def render_workspace_doc(host: dict, target: Path) -> None:
    """Render src/workspace-doc.md to <target>/<workspace_doc>."""
    src = (ROOT / "src" / "workspace-doc.md").read_text()
    rendered = substitute(src, host)
    (target / host["workspace_doc"]).write_text(rendered)


def render_research_log(host: dict, target: Path) -> None:
    """Render src/research_log.md to <target>/research_log.md."""
    src = (ROOT / "src" / "research_log.md").read_text()
    rendered = substitute(src, host)
    (target / "research_log.md").write_text(rendered)


def render_gitignore(host: dict, target: Path) -> None:
    """Render src/gitignore + optional hosts/<host>/gitignore.extra to <target>/.gitignore."""
    src = (ROOT / "src" / "gitignore").read_text()
    extra_path = ROOT / "hosts" / host["name"] / "gitignore.extra"
    if extra_path.exists():
        src += extra_path.read_text()
    (target / ".gitignore").write_text(src)


def render_host_extras(host: dict, target: Path) -> None:
    """Copy host-specific extras (settings.json, package.json, etc.) into target.

    Looks for files under hosts/<host>/extras/<relative-path>. Each is copied
    to <target>/<relative-path>, preserving subdirectory structure.
    """
    extras_dir = ROOT / "hosts" / host["name"] / "extras"
    if not extras_dir.exists():
        return
    for src in extras_dir.rglob("*"):
        if src.is_file():
            rel = src.relative_to(extras_dir)
            dst = target / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)


def load_host(host_name: str) -> dict:
    """Load the host config dict and enrich with file-backed values."""
    with (ROOT / "hosts" / host_name / "host.toml").open("rb") as f:
        host = tomllib.load(f)
    for key, filename in host.pop("file_backed", {}).items():
        path = ROOT / "hosts" / host_name / filename
        host[key] = path.read_text() if path.exists() else ""
    return host


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, choices=["claude", "pi"])
    parser.add_argument("--target", required=True, type=Path)
    args = parser.parse_args()

    host = load_host(args.host)
    target = args.target.resolve()
    target.mkdir(parents=True, exist_ok=True)

    n_agents = render_agents(host, target)
    n_skills = render_skills(host, target)
    render_workspace_doc(host, target)
    render_research_log(host, target)
    render_gitignore(host, target)
    render_host_extras(host, target)

    print(
        f"Rendered host={args.host}: {n_agents} agents + {n_skills} skills "
        f"+ workspace doc + research_log + .gitignore → {target}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
