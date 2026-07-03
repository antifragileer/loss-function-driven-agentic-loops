#!/usr/bin/env python3
"""Parse OpenCode's --format json output into the LFD shared shape.

OpenCode CLI (opencode.ai) emits a single JSON object to
stdout when invoked with `opencode run --format json`.
This script reads that object and re-emits it in the same
shape as the other adapters' parsers so the loop-driver
can be runtime-agnostic.

Output schema (matches parse_cline_output.py / parse_claude_output.py /
parse_codex_output.py / parse_hermes_output.py):
  {
    "tokens": int,
    "duration_ms": int,
    "candidate_text": str,
    "model": str,
    "provider": str,            # derived from the "provider/model" model string
    "finish_reason": str,
    "iterations": int,
    "tool_calls": list
  }

Usage: parse_opencode_output.py <opencode-json path>
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


EMPTY = {
    "tokens": 0,
    "duration_ms": 0,
    "candidate_text": "",
    "model": "",
    "provider": "",
    "finish_reason": "no_output",
    "iterations": 0,
    "tool_calls": [],
}


def _coerce_int(x, default=0) -> int:
    try:
        return int(x)
    except (TypeError, ValueError):
        return default


def _split_model(model: str) -> tuple[str, str]:
    """Split a 'provider/model' string into (provider, model)."""
    if not model or "/" not in model:
        return ("", model or "")
    provider, _, rest = model.partition("/")
    return (provider, rest)


def _extract(obj: dict) -> dict:
    usage = obj.get("usage") or {}
    in_t = _coerce_int(usage.get("input_tokens", 0))
    out_t = _coerce_int(usage.get("output_tokens", 0))
    cache_t = _coerce_int(usage.get("cache_read_tokens", 0))
    tokens = in_t + out_t + cache_t

    full_model = obj.get("model", "") or ""
    provider, _ = _split_model(full_model)

    return {
        "tokens": tokens,
        "duration_ms": _coerce_int(obj.get("duration_ms", 0)),
        "candidate_text": obj.get("result", "") or "",
        "model": full_model,
        "provider": provider,
        "finish_reason": obj.get("finish_reason", "unknown") or "unknown",
        "iterations": _coerce_int(obj.get("iterations", obj.get("turns", 0))),
        # OpenCode's single-object --format json does not
        # include a tool-call log. Empty list keeps the
        # schema stable; for tool-call tracking, run with
        # the streaming output and write a separate parser.
        "tool_calls": [],
    }


def main(path: str) -> None:
    p = Path(path)
    if not p.exists() or p.stat().st_size == 0:
        print(json.dumps(EMPTY, indent=2))
        return
    try:
        obj = json.loads(p.read_text())
    except json.JSONDecodeError:
        # Malformed output → empty result, loop's safety
        # sub-loss catches it.
        print(json.dumps(EMPTY, indent=2))
        return
    print(json.dumps(_extract(obj), indent=2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: parse_opencode_output.py <opencode-json>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
