#!/usr/bin/env python3
"""Parse Cline's NDJSON output into a single JSON object on stdout.

Verified against Cline v3.0.34 / v3.0.35 across OpenAI-compatible
providers. Earlier Cline versions or different providers may emit a
different event schema — if so, this is the place to extend, not
the wrapper.

Usage: parse_cline_output.py <cline.json path>
"""
import json
import sys
from pathlib import Path


def main(path: str) -> None:
    p = Path(path)
    if not p.exists() or p.stat().st_size == 0:
        out = {
            "tokens": 0,
            "duration_ms": 0,
            "candidate_text": "",
            "model": "",
            "provider": "",
            "finish_reason": "no_output",
            "iterations": 0,
            "tool_calls": [],
        }
        print(json.dumps(out, indent=2))
        return

    tokens = 0
    duration_ms = 0
    candidate_text = ""
    model = ""
    provider = ""
    finish_reason = "unknown"
    iterations = 0
    tool_calls: list[dict] = []

    with p.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            t = obj.get("type")

            if t == "run_result":
                agg = obj.get("aggregateUsage") or obj.get("usage") or {}
                tokens = (
                    int(agg.get("inputTokens", 0) or 0)
                    + int(agg.get("outputTokens", 0) or 0)
                    + int(agg.get("cacheReadTokens", 0) or 0)
                )
                duration_ms = int(obj.get("durationMs", 0) or 0)
                candidate_text = obj.get("text", "") or ""
                finish_reason = obj.get("finishReason", "unknown")
                iterations = int(obj.get("iterations", 0) or 0)
                m = obj.get("model") or {}
                model = m.get("id", "")
                provider = m.get("provider", "")

            if t == "agent_event":
                ev = obj.get("event", {})
                if isinstance(ev, dict) and ev.get("type") == "tool_call":
                    tool_calls.append(
                        {
                            "name": ev.get("name", ""),
                            "args": ev.get("args", {}),
                        }
                    )

    out = {
        "tokens": tokens,
        "duration_ms": duration_ms,
        "candidate_text": candidate_text,
        "model": model,
        "provider": provider,
        "finish_reason": finish_reason,
        "iterations": iterations,
        "tool_calls": tool_calls,
    }
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: parse_cline_output.py <cline.json>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
