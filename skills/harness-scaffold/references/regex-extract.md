# Regex Extraction — Reference

The scaffold parses the /goal prompt with five regexes. This file
documents each one, the failure mode, and the fallback.

## 1. Runtime extraction

```python
m = re.search(r"inner loop is the `(\w+)` CLI", prompt)
return m.group(1) if m else "cline"
```

Matches the `meta-loss-function-development` template line:

> The inner loop is the `<AGENT>` CLI.

Captures the agent name. Defaults to `cline` if absent.

**Failure mode:** the user rephrased "inner loop" or used a
different article. The fallback is `cline`. Override with
`--runtime {codex|aider|cline}` on the command line.

## 2. Design task extraction

```python
m = re.search(r"Design-set tasks.*?\n\n(.*?)(?=\n\n#|\Z)", prompt, re.S)
```

Pulls the entire `Design-set tasks` block (between the section
header and the next `#` heading or end-of-file). Then per line:

```python
m2 = re.match(r"^\d+\.\s+(.+)$", line)
```

Captures the rest of the line. Then:

```python
if "`" in desc:
    em = max(desc.rfind(" — "), desc.rfind(" - "))
    if em > 0:
        desc = desc[em + 3:].strip()
    else:
        m3 = re.match(r"^`[^`]+`\s*(.*)$", desc)
        if m3:
            desc = m3.group(1).strip()
desc = desc.strip("`'\"")
```

The /goal template uses the format:

```
1. `test-tasks/design/01-send-message/` — implement a function that ...
```

The regex splits on the em-dash (or hyphen fallback) after the
closing backtick. The leading `` `...` `` (the path) is dropped
and only the description remains.

**Failure mode 1:** no em-dash. Falls back to "drop the first
backticked segment, take the rest." If the rest is empty, the
task gets a generic `task-NN` slug.

**Failure mode 2:** em-dash inside the description (e.g., a
bibliography citation). The `rfind` picks the *last* em-dash,
so most cases work. If the description itself contains a
backtick-after-em-dash, the path-stripping drops the wrong
chunk. **Mitigation:** avoid backticks in task descriptions.

## 3. Held-out task extraction

```python
m = re.search(r"Held-out tasks.*?\n\n(.*?)(?=\n\n#|\Z)", prompt, re.S)
```

Same block-extraction pattern as design tasks. Then:

```python
# Strip backticks
clean = re.sub(r"`", "", block)
# Find the range marker
range_match = re.search(
    r"(h\d{2})[^a-zA-Z0-9]{1,8}(?:…|\.{2,}|—|–|through|to| - )[^a-zA-Z0-9]{1,8}(h\d{2})",
    clean, re.I,
)
```

The /goal template writes:

```
`h01` ... `h10`.
```

After backtick stripping, that's `h01 ... h10`. The regex
matches `h01`, separator (` ... `), `h10`, and expands to
`h01..h10` (10 tasks).

**Failure mode 1:** the user wrote `h01` through `h10` without
the ellipsis. The regex has a `through|to| - ` alternative that
catches this.

**Failure mode 2:** the user wrote `h1` (one digit) instead of
`h01` (two digits). The regex requires `\d{2}`. The fallback is
a full-word search for `h\d{2}` patterns; if that finds any, it
uses them; otherwise defaults to `h01..h10`.

**Failure mode 3:** the user wrote `h01` ... `h05` (5 held-out
tasks, not 10). The regex correctly expands to `h01..h05` (5
tasks). This is the desired behavior.

## 4. Project name extraction

```python
m = re.search(r"^#\s*/goal:?\s*(.+?)$", prompt, re.M)
return slugify(m.group(1)) if m else "project"
```

Matches the first `# /goal: <TITLE>` line. Slugifies the title
for the project name.

**Failure mode:** the user wrote `/goal` (slash-goal) without
the `#` prefix. The regex still matches. If the prompt starts
with `/goal:` on a single line, the regex still catches it via
the optional `#\s*` prefix.

## 5. Cycle budget extraction

The scaffold doesn't currently parse the budget — it emits
sensible defaults (8h wall-clock, 1M tokens) into the README.
This is a known gap. The loop driver uses
`verifiers/instruments/time-remaining.sh` and
`verifiers/instruments/tokens-remaining.sh` to enforce the
budget at runtime; the budget value comes from the loop
driver's own config, not the prompt.

## Why regex and not AST parsing?

The /goal prompt is a Markdown file written by an LLM. AST
parsing (e.g., `markdown-it-py`) gives a tree, but the prompt's
internal structure is loose: section headers come and go, lists
have inconsistent formatting, backticks appear and disappear.
Regex is forgiving and survives minor reformatting. The trade-off
is that a *radically* different prompt format will fail to parse
and the scaffold will fall back to defaults.

If the meta-skill changes the template format, update the regex
in `scripts/scaffold.py` (functions `extract_design_tasks` and
`extract_held_out_tasks`) and add a test case to the smoke
test.

## Test the regex without running the full scaffold

```python
import re
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location(
    "scaffold", "scripts/scaffold.py"
)
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

prompt = Path("GOAL.md").read_text()
print(mod.extract_runtime(prompt))       # 'cline'
print(mod.extract_design_tasks(prompt))   # ['implement a function that ...', ...]
print(mod.extract_held_out_tasks(prompt)) # ['h01', 'h02', ..., 'h10']
```

Run this from `$PROJECT_DIR` after the scaffold has been used
at least once.
