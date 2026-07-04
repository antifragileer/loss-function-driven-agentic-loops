# LFD System Verification Report (real-agent)

**Generated:** 2026-07-04T00:29:33Z
**Bundle version:** 2.1.0
**Repo:** `/Users/oxenated/fleet/loss-function-development-skills`
**Profile:** `/var/folders/36/4qcyx1yx7936hgvr4lxvv1h80000gp/T/lfd-verify-real-XXXXXX.nIPWMMmMo0`
**Runtime:** `cline` (model: `kimi-for-coding`, provider: `openai-compatible`)
**Wall-clock budget:** 300s
**Elapsed:** 216s (remaining: 83s)

## Overall: **PASS**

| Metric | Value |
|---|---|
| Design-set pass rate | 1.0 (5 pass / 0 fail) |
| Total tokens | 74691 |
| Total Cline duration | 23353ms |
| Tasks run | 5 |
| Design-set exit | 0 |

## What this verifier proves

This run drove the LFD system with a real coding agent
(`cline`) instead of the deterministic fake agent used
by the baseline `run-verification.sh`. It proves:

1. The `cline-wrapper.sh` correctly invokes the
   agent binary, captures NDJSON output, parses it via
   `parse_cline_output.py`, and emits the contract-shaped
   cycle summary.
2. The agent can read each design task's `prompt.txt`,
   locate the bundle files referenced in the prompts,
   and produce correct candidate text.
3. The per-task graders correctly evaluate the agent's
   output (the agent's claim is checked against the
   filesystem, not taken on faith).
4. The per-cycle state files (logs/.loop_start_ts,
   logs/cycle-1/, etc.) survive a real agent's
   per-cycle directory creation without breaking the
   next cycle.

A failure in this run indicates a real bug: a prompt
that's under-specified, a path the agent can't find, a
grader that misreads the agent's output, or a contract
mismatch between the wrapper and the parser.

## How to invoke

```bash
cd examples/lfd-system-verifier
./run-verification-real.sh                       # Cline, 5 min budget
./run-verification-real.sh "" "" claude-code     # Claude Code, 5 min
./run-verification-real.sh "" "" opencode        # OpenCode, 5 min
LFD_REAL_BUDGET=900 ./run-verification-real.sh   # 15 min budget
```

## Differences from the fake-agent baseline

| | run-verification.sh (fake) | run-verification-real.sh (real) |
|---|---|---|
| Inner agent | deterministic stub | cline (kimi-for-coding) |
| Wall-clock | ~10s | ~216s |
| Tokens | 0 | 74691 |
| Determinism | bit-exact | varies by run |
| Held-out grader | yes | no (held-out is for the deterministic baseline) |
| Method test | yes (3 cycles) | no (cycle-of-cycles is too expensive for real agents) |
| Purpose | CI / fast gate | prove the system is usable with a real agent |

Both must pass for the LFD system to be considered
fully verified. `run-verification.sh` proves the
*tools* work; `run-verification-real.sh` proves the
*integration* works.
