# /goal: Implement FlashAttention-2 from a Paper

A worked example of the /goal prompt for an algorithm-from-paper
goal. The user says "implement FlashAttention-2 from the paper";
the meta-skill turns it into the block below.

The key difference from the Slack-clone example: the held-out
set comes from the **paper's reference tests** + a public
benchmark (HuggingFace `transformers` attention tests), not
from a web API. Research phase here is reading the paper PDF,
not Slack's API docs.

---

/goal — Implement FlashAttention-2 (Dao et al., 2023) via Cline + LFD

# Operating rules

Read `AGENTS.md` first. Hard rules: do NOT read `verifiers/private/` or `test-tasks/held-out/`; do NOT modify `verifiers/`; the only Cline invocation is via `verifiers/cline-wrapper.sh`; after EACH design-set run, append a one-line entry to `logs/iteration-log.md`; if pass_rate doesn't improve by ≥ 0.05 vs prior cycle, force entropy.

# The 4-piece loss spec

**Target.** A Cline skill (SKILL.md + references) that, when loaded, helps Cline implement FlashAttention-2 (Dao et al., 2023) correctly on a held-out numerical-correctness benchmark. The skill must:
- pass ≥ 9/10 of the held-out numerical-correctness tests (Correctness, weight 1.0, gate)
- the implementation runs on a single H100 GPU (Buildability, 0.7, gate)
- median p50 latency < 80% of the PyTorch reference (Performance, 0.6)
- zero uninitialized memory accesses (Safety, 1.0, gate)
- a fresh agent can load the skill cold and execute it (Legibility, 0.3)
- skill follows Cline's SKILL.md frontmatter contract (Invariants, 1.0, gate)
- skill degrades gracefully on non-H100 GPUs (Drift, 0.2)
- median token spend per task < 10k tokens (Cost, 0.3)

Aggregate target: weighted sum ≥ 0.85. Correctness, Buildability, Safety, and Invariants are gates.

**Constraints.** Wall-clock budget 12 h; token budget 1,500,000; surface: read `$PROJECT_DIR`, invoke Cline via wrapper, read/write `skills/flash-attn-driver/`, append to `logs/`; methodology: deterministic verifiers only — the harness compares CUDA kernel output bit-for-bit against a PyTorch reference. Tolerance: ≤ 1e-5 max abs error.

**Instruments (for every constraint, a CLI command).**
- `verifiers/instruments/time-remaining.sh` — seconds left in the 12h budget
- `verifiers/instruments/tokens-remaining.sh` — tokens left
- `verifiers/instruments/tokens-this-iter.sh` — tokens used last cycle
- `verifiers/instruments/cline-version.sh` — installed Cline version
- `verifiers/instruments/cline-skills-dir.sh` — where Cline scans for skills
- `verifiers/instruments/sub-loss-readout.sh <cycle-N.json>` — per-cycle sub-losses
- `verifiers/instruments/gpu-info.sh` — `nvidia-smi` summary (H100 vs other)
- `verifiers/run-design-set.sh` — runs the 5 design tasks, emits `logs/design-set-score.json`
- `verifiers/cline-wrapper.sh` — the ONLY way to invoke Cline

A constraint without an instrument is a vibe. The agent will violate it because it cannot tell it is violating it.

**Forced entropy.** Each cycle continues from the previous run's entire context. Local maxima is the default state. Force entropy:
1. **Overfit reflection every cycle.** Before invoking Cline, append to `logs/iteration-log.md`: `cycle N: hypothesis="<one line>", expected_failure="<one line>", generalizing_or_memorizing=<g|m>"`. If memorizing, the next change must REMOVE an eval-shaped artifact.
2. **Force entropy on stall.** If the last cycle's weighted sum did not improve by ≥ 0.05 over the prior cycle, you MUST read the last 5 entries of `logs/iteration-log.md`, pick the OPPOSITE of your last change, and apply it. Log it.
3. **Keep an iteration log.** The grader will read `logs/iteration-log.md`.

# Candidate / verifier contract

```
candidate: $PROJECT_DIR/skills/flash-attn-driver/SKILL.md
verifier:  $PROJECT_DIR/verifiers/instruments/sub-loss-readout.sh <cycle-N.json>
inputs:
  candidate: $PROJECT_DIR/skills/flash-attn-driver/SKILL.md
  evidence:   $PROJECT_DIR/verifiers/private/cuda-output.bin
  evidence:   $PROJECT_DIR/verifiers/private/torch-reference.bin
  evidence:   `nvidia-smi` output
  evidence:   `nvcc --version` output
outputs:
  score: 0.0..1.0
  details: { sub_loss, signal, max_abs_error, latency_p50_ms, ... }
  artifacts: [ SKILL.md, cuda-output.bin, torch-reference.bin, gpu-info.txt ]
exit_code: 0 on success, non-zero if verifier itself failed
determinism: deterministic
budget: 600s wall-clock, 10000 tokens
```

# Design-set tasks (5, the development signal)

1. `test-tasks/design/01-tile-shape/` — given a (B, H, M, N, D) tuple, compute the tile shape (Br, Bc) per the paper's heuristic (B=64, D ≤ 64 → Br=Bc=64; D > 64 → Br=64, Bc=32).
2. `test-tasks/design/02-online-softmax/` — implement the online softmax recurrence: maintain running (m, l) statistics across tiles.
3. `test-tasks/design/03-block-mask/` — implement the causal block mask construction: a (Br, Bc) bool tensor that's true iff the (i, j) block is entirely within the causal mask.
4. `test-tasks/design/04-rescale/` — implement the running rescale of the output accumulator when a new (m, l) is computed (the divide-and-multiply trick).
5. `test-tasks/design/05-kernel-launch/` — implement the CUDA kernel launch grid: grid=(ceil(M/Br), B, H), block=(Br, 1, 1).

# Held-out tasks (10, the test set — DO NOT READ)

`test-tasks/held-out/h01` ... `h10`. Generated from the FlashAttention-2 reference tests and the HuggingFace `transformers` attention test suite. The grader at `verifiers/private/grader.sh` runs the agent's candidate skill against these. **Reading these voids the held-out score.**

# Harness layout

```
PROJECT_DIR/
├── AGENTS.md                          # the loop driver rules
├── GOAL.md                            # this file
├── README.md                          # project description
├── verifiers/
│   ├── cline-wrapper.sh
│   ├── compute_sub_losses.py
│   ├── run-design-set.sh
│   ├── instruments/
│   │   ├── time-remaining.sh
│   │   ├── tokens-remaining.sh
│   │   ├── tokens-this-iter.sh
│   │   ├── cline-version.sh
│   │   ├── cline-skills-dir.sh
│   │   ├── gpu-info.sh
│   │   └── sub-loss-readout.sh
│   ├── private/                       # HELD-OUT — agent must NOT read
│   │   └── grader.sh
│   └── reference/                     # the PyTorch reference implementation
│       └── reference.py
├── test-tasks/
│   ├── design/{01..05}/<task>.cu      # 5 design tasks (CUDA stubs)
│   ├── design/{01..05}/prompt.txt
│   ├── design/{01..05}/grade.sh
│   └── held-out/{h01..h10}/...        # 10 held-out tasks (off-limits)
├── skills/flash-attn-driver/          # the agent's candidate skill
└── logs/                              # the loop's running trace
```

# Stop conditions

1. pass_rate == 1.0 for 2 consecutive cycles AND last 2 overfit-reflections say "generalizing" — submit.
2. Wall-clock or token budget exhausted — submit best.
3. 3 consecutive cycles with no improvement AND forced entropy applied — submit best.

# First action

1. Read `GOAL.md` (this file), `AGENTS.md`, `README.md`, `verifiers/cline-wrapper.sh`, `verifiers/run-design-set.sh`, and every script in `verifiers/instruments/`.
2. Read each design task's `prompt.txt` and the starting file at the top of each design task dir. (5 tasks.)
3. Establish baseline: with no candidate skill installed, run `PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh` and record the result. Append cycle 0 to `logs/iteration-log.md`.
4. Begin cycle 1. Write a candidate `skills/flash-attn-driver/SKILL.md` (and references if needed).
5. Install the skill at `~/.cline/skills/flash-attn-driver/SKILL.md` (use `verifiers/instruments/cline-skills-dir.sh` to confirm the path).
6. Run `PROJECT_DIR=$(pwd) ./verifiers/run-design-set.sh` to score.
7. Compare to baseline. If improved, save `logs/best-cycle.json`. If not, force entropy.
8. Iterate. After each cycle, append to `logs/iteration-log.md`. Apply forced entropy on stall.
9. Stop when one of the stop conditions above is met.
10. On stop, leave `skills/flash-attn-driver/SKILL.md` + references + `logs/iteration-log.md` + `logs/best-cycle.json`. Verify the skill is also installed at `~/.cline/skills/flash-attn-driver/SKILL.md`.

# Practical hints

- The paper is at https://arxiv.org/abs/2307.08691. Read sections 3 (algorithm) and 4 (parallelism) before writing the skill.
- The reference PyTorch implementation is in `verifiers/reference/reference.py`. The harness compares bit-for-bit (tolerance 1e-5).
- A single H100 is the build target. Other GPUs may work but are not graded.
- Cline v3.0.34+ (or another supported agent-adapter from the bundle) with whatever model the user has authenticated. Do not switch the model.
- Wall-clock per design set is ~120-300 s. With 12 h budget, you can do ~150-300 cycles. Don't waste them.
- The 3-cheats pattern from the @elvissun article applies: don't reward-hack the design set (e.g., hardcoding the (B, H, M, N, D) tuples of the design tasks). The held-out grader generates fresh tuples.
- Tasks are math-heavy. The skill should help Cline understand the online-softmax recurrence (the running m, l update), the causal block mask (a (Br, Bc) bool tensor), and the rescale trick. Reference: the paper's Algorithm 1.

DONE
