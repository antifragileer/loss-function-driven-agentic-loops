#!/usr/bin/env python3
"""Parse the fake-agent wrapper's output into the LFD shared shape.

The fake-agent wrapper emits a single JSON object on stdout
when invoked. This script reads that object and re-emits it in
the same shape as the other adapters' parsers (8 required
keys), so the loop-driver can be runtime-agnostic.

Output schema (matches the other parsers):
  {
    "tokens": int,                 # always 0 for fake-agent
    "duration_ms": int,            # always 0
    "candidate_text": str,         # the echoed task prompt
    "model": str,                  # "fake"
    "provider": str,               # "stub"
    "finish_reason": str,          # "completed"
    "iterations": int,             # always 1
    "tool_calls": list
  }

Usage: parse_fake_output.py <fake-json path>
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


EMPTY = {
    "tokens": 0,
    "duration_ms": 0,
    "candidate_text": "",
    "model": "fake",
    "provider": "stub",
    "finish_reason": "no_output",
    "iterations": 0,
    "tool_calls": [],
}


def _extract(obj: dict) -> dict:
    return {
        "tokens": int(obj.get("tokens", 0) or 0),
        "duration_ms": int(obj.get("duration_ms", 0) or 0),
        "candidate_text": obj.get("candidate_text", "") or "",
        "model": obj.get("model", "fake") or "fake",
        "provider": obj.get("provider", "stub") or "stub",
        "finish_reason": obj.get("finish_reason", "completed") or "completed",
        "iterations": int(obj.get("iterations", 1) or 1),
        "tool_calls": obj.get("tool_calls", []) or [],
    }


def main(path: str) -> None:
    p = Path(path)
    if not p.exists() or p.stat().st_size == 0:
        print(json.dumps(EMPTY, indent=2))
        return
    try:
        obj = json.loads(p.read_text())
    except json.JSONDecodeError:
        print(json.dumps(EMPTY, indent=2))
        return
    print(json.dumps(_extract(obj), indent=2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: parse_fake_output.py <fake-json>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
