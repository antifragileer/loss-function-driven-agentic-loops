#!/usr/bin/env bash
# sub-loss-readout.sh — print per-cycle sub-losses as JSON.
# Wraps the per-cycle sub-loss scorer (verifiers/compute_sub_losses.py).
#
# Usage: sub-loss-readout.sh <cycle-N.json>
set -euo pipefail

CYCLE_JSON="${1:?usage: sub-loss-readout.sh <cycle-N.json>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/../compute_sub_losses.py" "$CYCLE_JSON"
