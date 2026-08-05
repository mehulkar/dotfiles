---
name: review
description: Run a PR code review in a dedicated pi subagent pane in the "pr reviews" herdr workspace (created if missing), then gather the results and report them back. Use when the user asks to review a PR — e.g. /skill:review <PR url, owner/repo#N, or #N>.
---

# review — PR review in a herdr "pr reviews" pane

Run a code review as a pi subagent in its own pane inside the **"pr reviews"**
herdr workspace, then collect the review and report it back here. The review
pane stays open in that workspace so the user can follow up.

## 1. Ensure the "pr reviews" workspace exists

```sh
herdr workspace list
```
Find the workspace whose `label` is `pr reviews` and note its `workspace_id`.
If it's missing, create it and capture the id from the result:

```sh
herdr workspace create --label "pr reviews"   # → result.workspace.workspace_id
```

## 2. Determine the review target + repo

The `/skill:review` args (passed as `User: <args>`) identify the PR — a URL,
`owner/repo#N`, or `#N`/`N` (resolve the repo from context). Get the repo so the
subagent can fetch the diff:

```sh
gh pr view <N> --repo <owner/repo> --json repository,number,title,headRefName
```

Set the subagent's `--cwd` to that repo's local checkout (for Vercel repos:
`~/dev/vercel/vercel-core/<repo>`, e.g. `api` or `front`). If unsure, use the
repo root and let the subagent `cd`.

## 3. Launch the review subagent in a new pane

```sh
herdr agent start review-<N> --workspace <pr-reviews-id> \
  --cwd <repo-dir> --split right --no-focus -- pi "<REVIEW PROMPT>"
```
Capture `pane_id` from `result.agent.pane_id`. Target by it from here on — the
name `review-*` collides once you run more than one review.

`<REVIEW PROMPT>` (adapt to the PR):

> Review PR `<owner/repo>#<N>` — "<title>". Run `gh pr diff <N> --repo
> <owner/repo>` and `gh pr view <N> --repo <owner/repo> --json ...` to get the
> changes. Do a read-only code review covering: correctness/bugs, error
> handling, security, tests (missing/weak), perf, naming/style, and
> API/contract/behavior changes. Output a structured review: a one-line summary,
> then file-by-file findings tagged `blocker` / `major` / `nit`, then a merge
> recommendation (approve / request changes / comment). Don't edit files.

## 4. Wait for completion (non-blocking — don't block this session)

Peek at status; repeat until `agent_status` == `idle`:

```sh
herdr agent get <pane_id>     # → result.agent.agent_status
```

`idle` means the subagent finished its turn (pi is interactive and won't exit).
Before declaring done, `pane read` and check the last line isn't a clarifying
question to you — if it is, answer it (`herdr agent send <pane_id> "<reply>"`
then `herdr pane send-keys <pane_id> Enter`) and keep waiting.

## 5. Gather + report back

```sh
herdr pane read <pane_id> --source recent --lines 200 --format text
```
The review is in the recent tail (the top is pi's static TUI chrome). Relay the
findings to the user (verbatim or summarized). Report the `pane_id` and the
"pr reviews" workspace so they can open it:
`herdr workspace focus <pr-reviews-id>`.

Leave the pane open — it lives in the dedicated "pr reviews" workspace, so it
won't clutter the main one. Close it with `herdr pane close <pane_id>` if not
needed.

## Gotchas

- **pane_ids renumber when a pane/tab closes.** If you close anything between
  start and read, re-list (`herdr pane list --workspace <id>`) and re-derive the
  id by matching the session path or `terminal_id` — not the positional id.
- `herdr agent send` writes literal text, no Enter — follow with
  `herdr pane send-keys <pane_id> Enter`.
- pi is interactive — it does not exit when done; `idle` = done (or waiting for
  input). Close the pane yourself if you want it gone.
- Target by `pane_id`; agent names get ambiguous across reviews.
- Splits are 50/50, `right`/`down` only (no left/reorder).
