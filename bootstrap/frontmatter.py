"""Minimal YAML-frontmatter parser for PhysicsIntern source files.

Handles the subset of YAML we actually use:
  - top-level scalar keys (string, int, bool)
  - flow-style lists: `key: [a, b, c]`
  - block-style lists: `key:\n  - a\n  - b`
  - block-style strings on a single line

Not handled (intentionally): nested mappings, anchors, multiline strings,
quoted keys, JSON-style mappings. If we ever need them we'll switch to
PyYAML via uv-inline-script.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any


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


def parse(text: str) -> tuple[dict[str, Any], str]:
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


def read(path: Path) -> tuple[dict[str, Any], str]:
    """Read and parse a file with frontmatter."""
    return parse(path.read_text())
