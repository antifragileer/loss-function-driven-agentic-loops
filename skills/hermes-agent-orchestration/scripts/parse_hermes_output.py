#!/usr/bin/env python3
"""Parse Hermes Agent's --output-format json into the LFD shared shape.

Hermes Agent (Nous Research) emits a JSON object to stdout
when invoked with `hermes chat --output-format json`. This
script reads that object and re-emits it in the same shape
as `parse_cline_output.py` / `parse_claude_output.py` /
`parse_codex_output.py` so the loop-driver can be
runtime-agnostic.

Output schema (matches the other parsers):
  {
    "tokens": int,
    "duration_ms": int,
    "candidate_text": str,
    "model": str,
    "provider": str,
    "finish_reason": str,
    "iterations": int,
    "tool_calls": list
  }

Usage: parse_hermes_output.py <hermes-json path>
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


def _coerce_float(x, default=0.0) -> float:
    try:
        return float(x)
    except (TypeError, ValueError):
        return default


def _extract(obj: dict) -> dict:
    usage = obj.get("usage") or {}
    in_t = _coerce_int(usage.get("input_tokens", 0))
    out_t = _coerce_int(usage.get("output_tokens", 0))
    cache_t = _coerce_int(usage.get("cache_read_tokens", 0))
    tokens = in_t + out_t + cache_t

    return {
        "tokens": tokens,
        "duration_ms": _coerce_int(obj.get("duration_ms", 0)),
        "candidate_text": obj.get("result", "") or "",
        "model": obj.get("model", "") or "",
        "provider": obj.get("provider", "") or "",
        "finish_reason": obj.get("finish_reason", "unknown") or "unknown",
        "iterations": _coerce_int(obj.get("turns", 0)),
        # Hermes's single-object --output-format json does
        # not include a tool-call log. Empty list keeps the
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
        print("usage: parse_hermes_output.py <hermes-json>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
