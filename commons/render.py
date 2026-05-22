#!/usr/bin/env python3
"""Render PhysicsIntern workspace files for a given host.

Usage:
  render.py --host=claude|pi --target=<dir>

Reads source files under commons/ (host-agnostic methodology) and host configuration
under hosts/<host>/, and writes rendered files into <target>.

Source files use mustache-style placeholders ({{workspace_doc}}, {{agents_dir}})
that are substituted from the host config. Agent capabilities (file_read, glob,
…) are translated to host-specific tool names via hosts/<host>/host.py.

Requires Python 3.11+ (uses stdlib `tomllib`); no third-party packages.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
import tomllib
from pathlib import Path
from typing import Any

COMMONS = Path(__file__).resolve().parent  # this script lives in commons/
HOSTS = COMMONS.parent / "hosts"


# ----- frontmatter parsing -----
#
# Minimal YAML-frontmatter parser. Handles the subset we actually use:
# top-level scalar keys, flow-style lists (`key: [a, b]`), and block-style
# lists. Not handled (intentionally): nested mappings, anchors, multiline
# strings, quoted keys. If we ever need them we'll switch to PyYAML.

def _coerce(value: str) -> Any:
    """Coerce a bare YAML scalar to a Python value."""
    v = value.strip()
    # quoted string
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ('"', "'"):
        return v[1:-1]
    # booleans
    if v == "true":
        return True
    if v == "false":
        return False
    # integer
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    return v


def _parse_flow_list(value: str) -> list[Any]:
    """Parse `[a, b, c]` style lists."""
    inner = value.strip()[1:-1].strip()
    if not inner:
        return []
    return [_coerce(item) for item in inner.split(",")]


def parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Parse `---`-delimited frontmatter. Returns (metadata, body)."""
    if not text.startswith("---\n"):
        return {}, text

    end = text.find("\n---\n", 4)
    if end == -1:
        # Maybe ends with `---` at EOF
        end_eof = text.find("\n---", 4)
        if end_eof == -1 or text[end_eof + 4:].strip():
            raise ValueError("Frontmatter opened with --- but no closing --- found")
        header = text[4:end_eof]
        body = ""
    else:
        header = text[4:end]
        body = text[end + 5:]

    meta: dict[str, Any] = {}
    lines = header.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", line)
        if not m:
            raise ValueError(f"Unparseable frontmatter line: {line!r}")
        key, rest = m.group(1), m.group(2).strip()

        if rest == "":
            # Block-style list follows
            items = []
            j = i + 1
            while j < len(lines) and lines[j].startswith("  - "):
                items.append(_coerce(lines[j][4:]))
                j += 1
            if items:
                meta[key] = items
                i = j
                continue
            # Empty value
            meta[key] = ""
            i += 1
            continue

        if rest.startswith("[") and rest.endswith("]"):
            meta[key] = _parse_flow_list(rest)
        else:
            meta[key] = _coerce(rest)
        i += 1

    return meta, body


def read_frontmatter(path: Path) -> tuple[dict[str, Any], str]:
    """Read and parse a file with frontmatter."""
    return parse_frontmatter(path.read_text())


# ----- placeholder substitution -----

def substitute(text: str, ctx: dict) -> str:
    """Replace {{key}} placeholders with values from ctx.

    Callers can merge dicts to supply extra per-call values, e.g.
    `substitute(template, {**host, "name_cap": "Surveyor"})`.
    """
    def repl(m: re.Match) -> str:
        key = m.group(1).strip()
        if key in ctx:
            return str(ctx[key])
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
    """Map a list of capabilities to a host-specific tool list string.

    Duplicates are removed (preserving first-seen order): some hosts collapse
    multiple capabilities onto one tool (e.g. Codex maps both `file_write` and
    `file_edit` to `apply_patch`).
    """
    seen: dict[str, None] = {}
    for cap in capabilities:
        mapped = host["tools_map"].get(cap)
        if mapped is None:
            raise KeyError(f"Capability {cap!r} not in tools_map for {host['name']}")
        seen.setdefault(mapped, None)
    return ", ".join(seen)


def toml_basic_string(s: str) -> str:
    """Format a string as a TOML basic (double-quoted) string."""
    escaped = (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def render_agent_frontmatter(meta: dict, host: dict) -> str:
    """Emit the host-specific YAML frontmatter for an agent."""
    fields: dict[str, Any] = {
        "name": meta["name"],
        "description": meta["description"],
    }

    # Tools from capabilities
    if "capabilities" in meta:
        fields["tools"] = render_tools(meta["capabilities"], host)

    # Output pattern (Pi uses it; Claude omits). Skip falsy values so agents
    # like the reviewer — which compute their output path at runtime — don't
    # emit `output: false`, which Pi would otherwise treat as the literal path
    # `<workspace>/false`.
    if meta.get("output_pattern"):
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

def _render_agent_yaml_md(meta: dict, body: str, host: dict, target: Path) -> None:
    """Render an agent as YAML frontmatter + markdown body (Claude / Pi)."""
    frontmatter = render_agent_frontmatter(meta, host)
    # Source bodies omit the heading; the host can prepend one via
    # `agent_body_prefix` (with `{{name_cap}}` interpolated).
    prefix_template = host.get("agent_body_prefix", "")
    prefix = substitute(prefix_template, {**host, "name_cap": meta["name"].capitalize()})
    content = f"{frontmatter}\n\n{prefix}{body.lstrip()}"

    out_path = target / host["agents_dir"] / f"{meta['name']}.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content)


def _render_agent_toml(meta: dict, body: str, host: dict, target: Path) -> None:
    """Render an agent as a TOML role file (Codex).

    Codex roles carry the prose role description in a `developer_instructions`
    multi-line literal. There is no per-role tools allowlist — permissions are
    sandbox-scoped at the workspace level.
    """
    if '"""' in body:
        raise ValueError(
            f"Agent body for {meta['name']!r} contains triple-quote — "
            "cannot embed in TOML multi-line basic string"
        )
    lines = [
        f"name = {toml_basic_string(meta['name'])}",
        f"description = {toml_basic_string(meta['description'])}",
        "",
        'developer_instructions = """',
        body.strip(),
        '"""',
        "",
    ]
    out_path = target / host["agents_dir"] / f"{meta['name']}.toml"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines))


def render_agent(src_path: Path, host: dict, target: Path) -> None:
    """Render a single agent file from commons/agents/<name>.md to the workspace."""
    meta, body = read_frontmatter(src_path)
    body = substitute(body, host)

    fmt = host.get("agent_format", "yaml_md")
    if fmt == "yaml_md":
        _render_agent_yaml_md(meta, body, host, target)
    elif fmt == "toml":
        _render_agent_toml(meta, body, host, target)
    else:
        raise ValueError(f"Unknown agent_format: {fmt!r}")
    return meta


def render_agents(host: dict, target: Path) -> list[dict]:
    """Render all agents from commons/agents/. Returns each agent's manifest."""
    src_dir = COMMONS / "agents"
    metas: list[dict] = []
    for src_path in sorted(src_dir.glob("*.md")):
        metas.append(render_agent(src_path, host, target))
    return metas


def register_codex_agent_roles(metas: list[dict], target: Path) -> None:
    """Append `[agent_roles.<name>]` blocks to .codex/config.toml.

    Codex discovers user-defined roles via the `agent_roles` table in the
    project config; each block points at a per-role TOML file. The base
    config.toml ships in `hosts/codex/extras/`; we append the registrations
    here after agents have been rendered.
    """
    cfg_path = target / ".codex" / "config.toml"
    blocks = ["", "# Sub-agent role registrations (appended by the PhysicsIntern renderer)."]
    for meta in metas:
        name = meta["name"]
        blocks.append("")
        blocks.append(f"[agent_roles.{name}]")
        blocks.append(f"name = {toml_basic_string(name)}")
        blocks.append(f"description = {toml_basic_string(meta['description'])}")
        blocks.append(f'config_file = ".codex/agents/{name}.toml"')
    with cfg_path.open("a") as f:
        f.write("\n".join(blocks) + "\n")


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


def _render_skill_claude(meta: dict, body: str, host: dict, target: Path) -> None:
    """Render a skill into Claude's single-file layout: skills/<name>/SKILL.md."""
    fields: list[tuple[str, object]] = [
        ("name", meta["name"]),
        ("description", meta["description"]),
    ]
    args_hint = meta.get("arguments_hint", "")
    if args_hint:
        # Claude uses `argument-hint:` (singular, hyphenated)
        fields.append(("argument-hint", args_hint))
    out_path = target / host["skills_dir"] / meta["name"] / "SKILL.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(f"{_emit_yaml(fields)}\n\n{body.lstrip()}")


def _render_skill_pi(meta: dict, body: str, host: dict, target: Path) -> None:
    """Render a skill into Pi's two-file layout: a stub under skills/ and the
    full workflow under prompts/."""
    name = meta["name"]

    # 1. Stub: skills/<name>/SKILL.md — thin discovery pointer.
    stub_fields = [("name", name), ("description", meta["description"])]
    stub_path = target / host["skills_dir"] / name / "SKILL.md"
    stub_path.parent.mkdir(parents=True, exist_ok=True)
    stub_path.write_text(f"{_emit_yaml(stub_fields)}\n\n{_pi_stub_body(meta, host)}")

    # 2. Prompt: prompts/<name>.md — the actual workflow body.
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


def render_skill(src_path: Path, host: dict, target: Path) -> None:
    """Render a single skill from commons/skills/<name>.md, dispatching by host."""
    meta, body = read_frontmatter(src_path)
    body = substitute(body, host)

    if host["name"] in ("claude", "codex"):
        # Codex skills use the same single-file SKILL.md layout as Claude
        # (frontmatter `name:` + `description:`, markdown body). The only
        # difference is the discovery root, controlled by `skills_dir` in
        # host.toml (.claude/skills/ vs .agents/skills/).
        _render_skill_claude(meta, body, host, target)
    elif host["name"] == "pi":
        _render_skill_pi(meta, body, host, target)
    else:
        raise ValueError(f"Unknown host: {host['name']}")


def render_skills(host: dict, target: Path) -> int:
    """Render all skills from commons/skills/. Returns count."""
    src_dir = COMMONS / "skills"
    count = 0
    for src_path in sorted(src_dir.glob("*.md")):
        render_skill(src_path, host, target)
        count += 1
    return count


def render_commons_file(src_name: str, dst_name: str, host: dict, target: Path) -> None:
    """Substitute placeholders in commons/<src_name> and write to <target>/<dst_name>."""
    src = (COMMONS / src_name).read_text()
    rendered = substitute(src, host)
    (target / dst_name).write_text(rendered)


def render_gitignore(host: dict, target: Path) -> None:
    """Render commons/gitignore + optional hosts/<host>/gitignore.extra to <target>/.gitignore."""
    src = (COMMONS / "gitignore").read_text()
    extra_path = HOSTS / host["name"] / "gitignore.extra"
    if extra_path.exists():
        src += extra_path.read_text()
    (target / ".gitignore").write_text(src)


def render_host_extras(host: dict, target: Path) -> None:
    """Copy host-specific extras (settings.json, package.json, etc.) into target.

    Looks for files under hosts/<host>/extras/<relative-path>. Each is copied
    to <target>/<relative-path>, preserving subdirectory structure.
    """
    extras_dir = HOSTS / host["name"] / "extras"
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
    with (HOSTS / host_name / "host.toml").open("rb") as f:
        host = tomllib.load(f)
    for key, filename in host.pop("file_backed", {}).items():
        path = HOSTS / host_name / filename
        host[key] = path.read_text() if path.exists() else ""
    return host


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, choices=["claude", "pi", "codex"])
    parser.add_argument("--target", required=True, type=Path)
    args = parser.parse_args()

    host = load_host(args.host)
    target = args.target.resolve()
    target.mkdir(parents=True, exist_ok=True)

    agent_metas = render_agents(host, target)
    n_skills = render_skills(host, target)
    render_commons_file("workspace-doc.md", host["workspace_doc"], host, target)
    render_commons_file("research_log.md", "research_log.md", host, target)
    render_gitignore(host, target)
    render_host_extras(host, target)

    # Codex needs its sub-agent roles registered in .codex/config.toml after
    # the extras have been copied (the base config.toml ships in extras/).
    if host["name"] == "codex":
        register_codex_agent_roles(agent_metas, target)

    print(
        f"Rendered host={args.host}: {len(agent_metas)} agents + {n_skills} skills "
        f"+ workspace doc + research_log + .gitignore + host extras → {target}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
