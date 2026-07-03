#!/usr/bin/env python3
"""Parse Claude Code's --output-format json into the LFD shared shape.

Claude Code (v2.x) with `--print --output-format json` emits a
single JSON object to stdout when the task finishes. This
script reads that object and re-emits it in the same shape as
`cline-orchestration/scripts/parse_cline_output.py` so the
loop-driver can be runtime-agnostic.

Output schema:
  {
    "tokens": int,                # input + output
    "duration_ms": int,
    "candidate_text": str,        # == "result"
    "model": str,                 # best-effort from modelUsage keys
    "provider": str,              # "anthropic" (Claude Code is Anthropic-only)
    "finish_reason": str,         # "success" | "error_max_turns" | ...
    "iterations": int,            # num_turns
    "tool_calls": list,           # always [] in v2.x single-object output
    "cost_usd": float             # NEW vs Cline parser
  }

Usage: parse_claude_output.py <claude-json path>
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
    "cost_usd": 0.0,
}


def _extract(obj: dict) -> dict:
    """Extract the shared-shape fields from a Claude Code result object."""
    usage = obj.get("usage") or {}
    in_t = int(usage.get("input_tokens", 0) or 0)
    out_t = int(usage.get("output_tokens", 0) or 0)
    # Claude Code reports cached input separately. Counting it
    # in `tokens` is debatable; include it so the budget signal
    # matches "everything the model saw" — same convention as
    # the Cline parser.
    cache_t = int(usage.get("cache_read_input_tokens", 0) or 0)
    tokens = in_t + out_t + cache_t

    # modelUsage is a {model_name: {…}} dict; we surface the
    # last (and usually only) model name. If multiple models
    # were used (e.g. --fallback-model kicked in), the caller
    # can read the raw JSON to see all of them.
    model_usage = obj.get("modelUsage") or {}
    model = ""
    if model_usage:
        # Prefer a deterministic key order; last is fine.
        model = next(reversed(model_usage.keys()))

    return {
        "tokens": tokens,
        "duration_ms": int(obj.get("duration_ms", 0) or 0),
        "candidate_text": obj.get("result", "") or "",
        "model": model,
        # Claude Code is Anthropic-only. The driver never
        # overrides the provider; if it ever does, surface
        # it here.
        "provider": "anthropic",
        "finish_reason": obj.get("subtype", "unknown") or "unknown",
        "iterations": int(obj.get("num_turns", 0) or 0),
        # v2.x single-object output does not emit a tool-call
        # log; that's only in stream-json. Empty list keeps
        # the schema stable.
        "tool_calls": [],
        "cost_usd": float(obj.get("total_cost_usd", 0.0) or 0.0),
    }


def main(path: str) -> None:
    p = Path(path)
    if not p.exists() or p.stat().st_size == 0:
        print(json.dumps(EMPTY, indent=2))
        return
    try:
        obj = json.loads(p.read_text())
    except json.JSONDecodeError:
        # Treat malformed output as empty — the loop-driver's
        # safety sub-loss will catch it.
        print(json.dumps(EMPTY, indent=2))
        return
    print(json.dumps(_extract(obj), indent=2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: parse_claude_output.py <claude-json>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
