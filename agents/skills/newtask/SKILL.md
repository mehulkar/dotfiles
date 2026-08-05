---
name: newtask
description: Launch a pi subagent in its own herdr pane and immediately forget about it — fire-and-forget version of /subtask. Use when the user wants work kicked off in a separate pane with no monitoring, polling, or pane cleanup from the current session.
---

# newtask — fire-and-forget pi subagent in a herdr pane

Launch a regular interactive `pi` agent (full TUI, not `pi -p`) in its own herdr
pane, then **stop**. The current session does not watch, poll, read, or close
the pane — the user manages the subagent directly.

## Recipe

```sh
# Start from the vercel-core workspace root.
# Do not infer a repo/task path or start an agent inside a repo; agents decide their own worktree.
# `agent start` inherits Herdr's persistent Node environment, so run fnm use 22
# and verify Node before starting Pi.
herdr agent start <name> [--workspace ID] [--split right|down] \
  --cwd ~/dev/vercel/vercel-core [--no-focus] -- \
  sh -lc 'fnm use 22 && node -v && exec pi "<TASK PROMPT>"'
```

That's it. Report the pane_id and a one-line summary of what was launched, then
drop the subject entirely.

## Rules

- **Always start agents from `~/dev/vercel/vercel-core`.** Do not infer the task's
  repository or pass a repo/worktree path through `--cwd`; the agent chooses and
  enters its own worktree.
- **Before starting Pi through `agent start`, run `fnm use 22 && node -v`.**
  Herdr's persistent server can retain an older Node version; start Pi through
  `sh -lc 'fnm use 22 && node -v && exec pi …'`.
- **Fire and forget.** After `agent start` returns, do NOT:
  - poll with `agent get` / `agent wait`
  - read the pane with `pane read` / `agent read`
  - send input with `agent send`
  - close the pane with `pane close`
  - report on its progress later in the session, even if asked "how's it going"
    — instead point the user at the pane and offer to check only if they
    explicitly ask you to (which converts it into a /subtask-style follow).
- **Write a complete, self-contained task prompt.** The subagent gets no
  follow-ups from this session, so the prompt must carry all context: repo,
  branch/PR, conventions to follow (worktree pattern, pr-create skill, AGENTS.md),
  and the definition of done.
- **Quote the task prompt** (it's a positional pi message).

## When to prefer /subtask instead

Use /subtask when the launching session needs the result back (research answers,
relaying a summary, closing the pane when done). Use /newtask when the user says
they'll manage it themselves or that no monitoring is needed.
