#!/usr/bin/env python3
"""Parse Codex's NDJSON (--json) output into the LFD shared shape.

Codex CLI emits NDJSON events to stdout when invoked with
`codex exec --json`. This script reads the transcript and
re-emits a single shared-shape JSON object equivalent to
the Cline / Claude Code parser output.

Output schema (matches parse_cline_output.py / parse_claude_output.py):
  {
    "tokens": int,
    "duration_ms": int,
    "candidate_text": str,
    "model": str,
    "provider": str,            # "openai" — Codex is OpenAI-only
    "finish_reason": str,
    "iterations": int,
    "tool_calls": list[dict]
  }

Usage: parse_codex_output.py <codex-ndjson path>
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


def _extract(path: Path) -> dict:
    tokens = 0
    duration_ms = 0
    candidate_text = ""
    finish_reason = "unknown"
    iterations = 0
    model = ""
    tool_calls: list[dict] = []

    if not path.exists() or path.stat().st_size == 0:
        return {**EMPTY, "provider": "openai"}

    last_agent_message = ""
    last_reasoning_summary = ""

    for raw in path.read_text().splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            ev = json.loads(raw)
        except json.JSONDecodeError:
            continue

        ev_type = ev.get("type", "")

        # Per-turn summaries
        if ev_type == "turn.completed":
            usage = ev.get("usage") or {}
            tokens += _coerce_int(usage.get("input_tokens", 0))
            tokens += _coerce_int(usage.get("output_tokens", 0))
            tokens += _coerce_int(usage.get("cached_input_tokens", 0))
            iterations += 1
            # Capture last turn's model
            m = ev.get("model")
            if isinstance(m, str) and m:
                model = m
            # Stop reason lives on the turn summary
            sr = ev.get("stop_reason") or ev.get("finish_reason")
            if sr:
                finish_reason = sr

        # Per-item lifecycle
        elif ev_type == "item.completed":
            item = ev.get("item") or {}
            item_type = item.get("type", "")
            if item_type == "agent_message":
                last_agent_message = item.get("text", "") or last_agent_message
            elif item_type == "reasoning":
                last_reasoning_summary = item.get("text", "") or last_reasoning_summary
            elif item_type == "command_execution":
                tool_calls.append({
                    "name": "command_execution",
                    "args": {
                        "command": item.get("command", ""),
                    },
                })
            elif item_type == "file_change":
                tool_calls.append({
                    "name": "file_change",
                    "args": {
                        "path": item.get("path", ""),
                        "kind": item.get("kind", ""),
                    },
                })

        # Top-level error
        elif ev_type == "error":
            finish_reason = "error"
            err = ev.get("message") or ev.get("error") or ""
            if isinstance(err, str):
                candidate_text = (candidate_text + "\n" + err).strip() if candidate_text else err

        # Some Codex versions emit duration on the last
        # event as `duration_ms` or `total_duration_ms`.
        if "duration_ms" in ev and isinstance(ev["duration_ms"], (int, float)):
            duration_ms = max(duration_ms, _coerce_int(ev["duration_ms"]))
        if "total_duration_ms" in ev and isinstance(ev["total_duration_ms"], (int, float)):
            duration_ms = max(duration_ms, _coerce_int(ev["total_duration_ms"]))

    candidate_text = last_agent_message or last_reasoning_summary

    return {
        "tokens": tokens,
        "duration_ms": duration_ms,
        "candidate_text": candidate_text,
        "model": model,
        "provider": "openai",
        "finish_reason": finish_reason or "unknown",
        "iterations": iterations,
        "tool_calls": tool_calls,
    }


def main(path: str) -> None:
    print(json.dumps(_extract(Path(path)), indent=2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: parse_codex_output.py <codex-ndjson>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
