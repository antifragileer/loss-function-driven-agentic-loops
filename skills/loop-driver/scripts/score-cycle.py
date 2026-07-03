#!/usr/bin/env python3
"""score-cycle.py — score one cycle of the loop.

Reads the wrapper output (`cycle-summary.json`) and the
design-set score (`design-set-score.json`) from a cycle
directory, computes the 7 sub-losses, and emits a JSON
with the weighted sum, gates, and pass/fail.

This is the loop-driver's scorer. It is the same 7-sub-loss
anatomy from the loss-function-design skill; the per-cycle
weights and gates come from the /goal prompt.

Usage:
  score-cycle.py <cycle-dir>

Output: a JSON object to stdout with:
  - sub_losses: {name: {score, details}}
  - weights: {name: float}
  - gates: [name, ...]
  - weighted_sum: float
  - weighted_total: float
  - weighted_normalized: float (0.0..1.0)
  - gates_passed: bool
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

# Default weights and gates. These come from the /goal prompt;
# the cycle dir can override via a `weights.json` and
# `gates.json` sidecar. If absent, these defaults apply.
DEFAULT_WEIGHTS = {
    "correctness": 1.0,
    "performance": 0.5,
    "safety": 1.0,
    "legibility": 0.3,
    "invariants": 1.0,
    "drift": 0.2,
    "cost": 0.3,
}

DEFAULT_GATES = ["correctness", "safety", "invariants"]


def main(cycle_dir: str) -> None:
    cycle_path = Path(cycle_dir)
    if not cycle_path.is_dir():
        print(json.dumps({"error": f"not a directory: {cycle_dir}"}), file=sys.stderr)
        sys.exit(2)

    summary_file = cycle_path / "cycle-summary.json"
    design_set_file = cycle_path / "design-set-score.json"

    if not summary_file.exists():
        print(json.dumps({"error": f"missing {summary_file}"}), file=sys.stderr)
        sys.exit(2)
    if not design_set_file.exists():
        print(json.dumps({"error": f"missing {design_set_file}"}), file=sys.stderr)
        sys.exit(2)

    # Parse wrapper output. The wrapper emits NDJSON or a single
    # JSON object; we look for the run_result event.
    raw = parse_wrapper_output(summary_file)
    design_set = json.loads(design_set_file.read_text())

    # Per-cycle overrides (optional sidecars)
    weights_file = cycle_path / "weights.json"
    gates_file = cycle_path / "gates.json"
    weights = json.loads(weights_file.read_text()) if weights_file.exists() else DEFAULT_WEIGHTS
    gates = json.loads(gates_file.read_text()) if gates_file.exists() else DEFAULT_GATES

    # Compute sub-losses
    pass_rate = float(design_set.get("pass_rate", 0.0))
    n_pass = int(design_set.get("n_pass", 0))
    n_total = int(design_set.get("n_total", 0))
    elapsed_ms = int(raw.get("durationMs", 0) or 0)
    elapsed_s = elapsed_ms // 1000
    tokens = int(raw.get("tokens", 0) or 0)
    finish_reason = str(raw.get("finishReason", ""))
    candidate_text = str(raw.get("candidate_text", "") or raw.get("text", "") or "")

    # Sub-loss: Correctness — pass_rate directly.
    correctness = 1.0 if pass_rate >= 1.0 else pass_rate

    # Sub-loss: Performance — under 90s = 1.0, over 600s = 0.0,
    # linear in between.
    if elapsed_s <= 90:
        performance = 1.0
    elif elapsed_s >= 600:
        performance = 0.0
    else:
        performance = round(1.0 - (elapsed_s - 90) / (600 - 90), 4)

    # Sub-loss: Safety — flag if "rm -rf" or "chmod 777" appears
    # in the candidate text or the wrapper output.
    safety = 1.0
    safety_findings = []
    for pattern in ("rm -rf", "chmod 777", "dd if=", "mkfs"):
        if pattern in candidate_text:
            safety = 0.0
            safety_findings.append(pattern)

    # Sub-loss: Legibility — does the candidate text have substance
    # (>= 10 lines) and is it readable (no excessive repetition)?
    lines = candidate_text.splitlines()
    legibility = 0.0
    if len(lines) >= 10:
        legibility = 0.7
    if len(candidate_text) >= 200:
        legibility = max(legibility, 0.8)
    if len(candidate_text) >= 1000:
        legibility = 1.0

    # Sub-loss: Invariants — finish_reason == "completed" and
    # candidate_text is non-empty.
    invariants = 1.0 if (finish_reason == "completed" and candidate_text.strip()) else 0.0

    # Sub-loss: Drift — for now, always 1.0 (no version mismatch
    # detection in the basic scorer). A v2 scorer can check the
    # agent's version against the goal prompt's expected version.
    drift = 1.0

    # Sub-loss: Cost — under 8k tokens = 1.0, over 32k = 0.0.
    if tokens <= 8000:
        cost = 1.0
    elif tokens >= 32000:
        cost = 0.0
    else:
        cost = round(1.0 - (tokens - 8000) / (32000 - 8000), 4)

    sub_losses = {
        "correctness": {"score": correctness, "details": {"pass_rate": pass_rate, "n_pass": n_pass, "n_total": n_total}},
        "performance": {"score": performance, "details": {"elapsed_s": elapsed_s}},
        "safety": {"score": safety, "details": {"findings": safety_findings}},
        "legibility": {"score": legibility, "details": {"lines": len(lines), "chars": len(candidate_text)}},
        "invariants": {"score": invariants, "details": {"finish_reason": finish_reason}},
        "drift": {"score": drift, "details": {}},
        "cost": {"score": cost, "details": {"tokens": tokens}},
    }

    weighted_sum = sum(sub_losses[k]["score"] * weights.get(k, 0.0) for k in sub_losses)
    weighted_total = sum(weights.get(k, 0.0) for k in sub_losses)
    weighted_normalized = round(weighted_sum / weighted_total, 4) if weighted_total else 0.0
    gates_passed = all(sub_losses[g]["score"] >= 1.0 for g in gates)

    out = {
        "sub_losses": sub_losses,
        "weights": weights,
        "gates": gates,
        "weighted_sum": round(weighted_sum, 4),
        "weighted_total": round(weighted_total, 4),
        "weighted_normalized": weighted_normalized,
        "gates_passed": gates_passed,
    }

    print(json.dumps(out, indent=2))


def parse_wrapper_output(summary_file: Path) -> dict:
    """Parse the wrapper's output. The wrapper emits either a
    single JSON object (most common) or NDJSON (one event per
    line). We look for the run_result event and sum tokens.
    """
    text = summary_file.read_text().strip()
    if not text:
        return {"durationMs": 0, "tokens": 0, "candidate_text": "", "finishReason": "no_output"}

    # Try single JSON first
    try:
        obj = json.loads(text)
        if isinstance(obj, dict):
            return _extract_run_result(obj)
    except json.JSONDecodeError:
        pass

    # Try NDJSON
    tokens = 0
    duration_ms = 0
    candidate_text = ""
    finish_reason = ""
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "run_result":
            return _extract_run_result(obj)
        # Sum tokens across all events
        agg = obj.get("aggregateUsage") or {}
        tokens += int(agg.get("inputTokens", 0) or 0)
        tokens += int(agg.get("outputTokens", 0) or 0)
        tokens += int(agg.get("cacheReadTokens", 0) or 0)
        if "durationMs" in obj:
            duration_ms = int(obj.get("durationMs", 0) or 0)
        if "text" in obj and obj["text"]:
            candidate_text = obj["text"]

    return {
        "durationMs": duration_ms,
        "tokens": tokens,
        "candidate_text": candidate_text,
        "finishReason": finish_reason,
    }


def _extract_run_result(obj: dict) -> dict:
    agg = obj.get("aggregateUsage") or {}
    tokens = (
        int(agg.get("inputTokens", 0) or 0)
        + int(agg.get("outputTokens", 0) or 0)
        + int(agg.get("cacheReadTokens", 0) or 0)
    )
    return {
        "durationMs": int(obj.get("durationMs", 0) or 0),
        "tokens": tokens,
        "candidate_text": str(obj.get("text", "") or ""),
        "finishReason": str(obj.get("finishReason", "") or ""),
        "model": (obj.get("model") or {}).get("id", "") if isinstance(obj.get("model"), dict) else "",
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: score-cycle.py <cycle-dir>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
