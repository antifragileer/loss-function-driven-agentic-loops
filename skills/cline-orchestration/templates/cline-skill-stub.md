---
name: <skill-name>
description: <one-paragraph trigger description. State WHAT task shape loads this skill and WHEN to load it.>
version: 0.1.0
author: <author>
---

# <skill title>

A focused skill for **<task class>**. It exists to keep Cline's
inner loop tight on this class of task — minimum files touched,
minimum churn, minimum tokens.

## When to use

Load this skill when **all** of the following hold:

- <trigger condition 1>
- <trigger condition 2>
- <trigger condition 3>

Do **not** use this skill for <out-of-scope task class A> or
<out-of-scope task class B>. For those, the default Cline
behaviour is fine.

## Operating loop

1. **Read the spec first.** Open the spec file (typically
   `README.md`, `prompt.txt`, or the grader script in the
   task directory) before touching any files. The spec /
   grader is the source of truth.
2. **Make the smallest change that satisfies the grader.**
   Edit the existing file in place when the task is to fix
   or extend it. Create a new file only when the task
   explicitly asks for a new file with a specific name.
3. **Verify locally before declaring done.** If the task
   includes a runnable script or grader, run it and confirm
   the output matches the expected behaviour.
4. **Stop.** Do not refactor surrounding code, do not add
   docstrings to unrelated functions, do not introduce
   directories. Out-of-scope changes break graders that
   look for an exact file path or a precise output string.

## Anti-patterns (do not do these)

- **Do not** reformat unrelated files.
- **Do not** move code into helper modules — the grader
  looks for top-level files at specific paths.
- **Do not** add `if __name__ == "__main__"` blocks to
  files that did not already have one.
- **Do not** run destructive shell commands (`rm -rf`,
  `git reset --hard`, etc.). The harness has a
  transcript-level safety check; destructive commands fail
  the cycle outright.
- **Do not** add dependencies. The grader runs in the
  same venv as Cline; a missing import fails the cycle.

## Token discipline

- One read of the spec + one read of the grader + one edit +
  one verification run is the target. Four tool calls per
  task, give or take one.
- Do not re-read files you just wrote.
- Do not list the directory to "see what's there" — the
  wrapper seeds the iteration dir with the task's source
  files.
- Prefer `write_file` over `cat > file <<EOF` shell
  incantations for new files.

## Failure recovery

If the first verification run fails:

1. Read the error or the missing-output message carefully.
2. Make a **targeted** second edit — do not rewrite the
   whole file.
3. Re-run the verification. Stop after two failed attempts
   and report what you saw; do not loop indefinitely.

## Output expectations

- The grader script is the source of truth. Read it.
- The final state of the iteration directory is what
  gets graded. A perfect transcript that didn't write to
  the right path scores 0.
- When done, briefly state which files you changed and
  the verification command you ran. No more than two
  sentences.
