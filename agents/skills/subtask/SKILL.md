---
name: subtask
description: Run a subtask as a pi subagent in its own herdr pane. Use when the user wants work done in a separate herdr pane ("subagent in another pane", "pi in a pane") while the main session stays available.
---

# subtask — pi subagent in a herdr pane

Launch a regular interactive `pi` agent (full TUI, not `pi -p`) in its own herdr
pane, let it run a self-contained task, read the answer, close the pane.

## Recipe

```sh
# 1. Start from the vercel-core workspace root (captures pane_id in result.agent.pane_id).
# Do not infer a repo/task path or start an agent inside a repo; agents decide their own worktree.
# `agent start` inherits Herdr's persistent Node environment, so run fnm use 22
# and verify Node before starting Pi.
herdr agent start <name> [--workspace ID] [--split right|down] \
  --cwd ~/dev/vercel/vercel-core [--no-focus] -- \
  sh -lc 'fnm use 22 && node -v && exec pi "<TASK PROMPT>"'

# 2. check status (non-blocking) — repeat until agent_status == idle
herdr agent get <pane_id>

# 3. read the answer (it's in the recent tail; the top is pi's static TUI chrome)
herdr pane read <pane_id> --source recent --lines 120 --format text

# 4. close it
herdr pane close <pane_id>
```

To send follow-up input (e.g. answer a clarifying question), `agent send` does
not press Enter, so follow with `send-keys`:

```sh
herdr agent send <pane_id> "<reply>"
herdr pane send-keys <pane_id> Enter
```

## Placing pi into a specific pane

`agent start` creates its own pane and you can't pick which pane it splits from.
For precise placement, split explicitly then run pi in that pane — `pane run`
launches interactive pi and herdr auto-detects it as a `pi` agent:

```sh
herdr pane split <target-pane-id> --direction right|down --no-focus   # → new pane_id
herdr pane run <new-pane-id> "pi --session <id>   # or: pi \"<prompt>\""
```

This is also how you resume a session into a chosen pane: `pi --session <id>`.

## Rules

- **Always start agents from `~/dev/vercel/vercel-core`.** Do not infer the task's repository or pass a repo/worktree path through `--cwd`; the agent chooses and enters its own worktree.
- **Before starting Pi through `agent start`, run `fnm use 22 && node -v`.** Herdr's persistent server can retain an older Node version; start Pi through `sh -lc 'fnm use 22 && node -v && exec pi …'`.
- **pi is interactive — it does not exit when done.** "Done with this turn" =
  `agent_status: idle`. Always close the pane yourself with `herdr pane close`.
- **`idle` can mean "waiting for input", not "finished".** `pane read` and check
  the last line before closing; if it's a question, reply (see above).
- **Don't block the main session.** `herdr agent wait --status idle` holds your
  turn. Peek with `agent get` / `pane read` instead; reserve `agent wait` for a
  background shell.
- **Target by `pane_id`, not the agent name.** The name `pi` is ambiguous once
  >1 pi agent exists (`agent_target_ambiguous`). `pane_id` works for all
  `agent get/read/send` and `pane read/send-keys/close` targets.

## Gotchas

- **pane_ids and tab_ids renumber (compact) when a pane or tab closes.** A
  `pane_id`/`tab_id` you cached before a close may now belong to a different
  pane (or no pane). After any close, re-list (`herdr pane list --workspace ID`
  / `herdr tab list --workspace ID`) and re-derive the id — match on the session
  path or `terminal_id`, which are stable, not on the positional id.
- `agent send` writes literal text, no Enter — always follow with
  `pane send-keys <pane_id> Enter`.
- Splits are 50/50 only; there's no width option, and `pane split` supports only
  `right`/`down` (no `left`/`up`, no reorder). To get a leftmost "command
  center" pane, it must be the first pane in a fresh tab.
- Quote the task prompt (it's a positional pi message).

## quick reference

- `agent start <name> [--workspace ID] [--tab ID] [--split right|down] [--cwd PATH] [--focus|--no-focus] -- <argv...>`
- `agent get <target>` → `agent_status`: working|idle|blocked|unknown
- `agent read <target> [--source recent] [--lines N] [--format text]`
- `agent send <target> <text>` (no Enter) · `agent wait <target> --status <s> [--timeout MS]` (blocks)
- `pane read <pane_id> [--source recent] [--lines N] [--format text]`
- `pane split <pane_id> --direction right|down [--cwd PATH] [--focus|--no-focus]` (50/50)
- `pane run <pane_id> <command>` — type command + Enter in the pane's shell (launches pi, auto-detected)
- `pane send-keys <pane_id> <key>…` (e.g. `Enter`) · `pane close <pane_id>`
- `pane list --workspace ID` / `tab list --workspace ID` / `workspace list`
- `<target>` accepts terminal ids, unique agent names, detected labels, pane ids
