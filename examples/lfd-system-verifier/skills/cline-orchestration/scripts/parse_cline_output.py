#!/usr/bin/env python3
"""Parse a Cline NDJSON transcript into the shared evaluation shape."""
from __future__ import annotations

import json
import sys
from pathlib import Path

REQUIRED_KEYS = [
    "tokens",
    "duration_ms",
    "candidate_text",
    "model",
    "provider",
    "finish_reason",
    "iterations",
    "tool_calls",
]


def parse_transcript(path: str) -> dict:
    """Extract the shared shape from a Cline NDJSON transcript."""
    result = {k: "" for k in REQUIRED_KEYS}
    result["tokens"] = 0
    result["duration_ms"] = 0
    result["iterations"] = 0
    result["tool_calls"] = []

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            rec_type = record.get("type")

            if rec_type == "run_result":
                usage = record.get("aggregateUsage") or {}
                result["tokens"] = sum(
                    int(usage.get(k, 0) or 0)
                    for k in ("inputTokens", "outputTokens", "cacheReadTokens")
                )
                result["duration_ms"] = int(record.get("durationMs", 0) or 0)
                result["candidate_text"] = record.get("text", "")

                model = record.get("model") or {}
                if isinstance(model, dict):
                    result["model"] = model.get("id", "")
                    result["provider"] = model.get("provider", "")

                result["finish_reason"] = record.get("finishReason", "")
                result["iterations"] = int(record.get("iterations", 0) or 0)

            elif rec_type == "agent_event":
                event = record.get("event") or {}
                if event.get("type") == "tool_call":
                    result["tool_calls"].append(
                        {
                            "name": event.get("name"),
                            "args": event.get("args"),
                        }
                    )

            elif rec_type == "hook_event":
                if record.get("hookEventName") == "tool_call":
                    result["tool_calls"].append(
                        {
                            "name": record.get("toolName"),
                            "args": record.get("input"),
                        }
                    )

    return result


def main() -> int:
    if len(sys.argv) < 2:
        print(f"usage: {Path(sys.argv[0]).name} <transcript.ndjson>", file=sys.stderr)
        return 1

    result = parse_transcript(sys.argv[1])
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
