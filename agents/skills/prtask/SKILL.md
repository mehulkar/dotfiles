---
name: prtask
description: Launch a Pi child through /newtask for work that must create and own a pull request. Adds engineering-manager registration, PR monitoring, merge cleanup, and child completion instructions. Use instead of /newtask for PR-producing implementation tasks.
---

# prtask: PR-producing child task

`/prtask` is the PR-specific wrapper around `/newtask`. Use it only when the child is expected to create
or take ownership of a PR. Use `/newtask` for research, monitoring, status gathering, and other work that
does not create a PR.

## Invocation

```text
/prtask [--model <provider/model>] [--workspace <workspace-id>] [--tab <tab-id>] <task prompt>
```

Parse `--model`, `--workspace`, and `--tab` exactly as `/newtask` does. Load and follow `/newtask` for
pane creation and launch mechanics. Pass the same launch arguments through, but replace `<task prompt>`
with the augmented PR prompt below.

## Augmented PR prompt

The caller's prompt must already contain the desired outcome, scope, non-goals, repository, definition
of done, validation, and relevant issue context. Append this block verbatim:

```text
PR ownership and lifecycle (mandatory):
- This task must create or take ownership of a PR and own it through merge or closure.
- Follow repository worktree instructions. Never work directly in a main checkout when a worktree is required.
- Open the PR as draft unless the caller explicitly requires otherwise.
- Immediately after opening or taking ownership of the PR, register it with the engineering manager:
  python3 /Users/mehulkar/dev/vercel/vercel-core/.agents/skills/em/scripts/registry.py manage --url <full-pr-url> --pane "$HERDR_PANE_ID" --tab "$HERDR_TAB_ID" --workspace "$HERDR_WORKSPACE_ID" --agent "$PI_SESSION_ID" --branch <branch> --worktree <worktree-path>
- Never monitor the PR yourself. Do not use polling loops, `gh pr checks --watch`, sleeps, scheduled prompts, `/pr-monitor`, or monitoring subagents. Engineering-manager notifications arrive directly in this pane. Respond to actionable notifications, then return to idle. Any instruction to monitor CI means this workflow only.
- Never merge the PR.
- Never reply to a human comment automatically.
- Leave the PR registered until GitHub reports it merged or closed.
- When the engineering manager reports that the PR merged, immediately invoke `/child-is-done` and follow that skill completely. Production monitoring is not required unless the caller explicitly requested it.
```

If the caller supplied an AI-review workflow, PR-body format, reviewer requirement, or other PR-specific
instruction, preserve it before this lifecycle block.

## Rules

- Always launch the child through `/newtask`; do not duplicate Herdr pane mechanics here.
- Always include the parent identity supplied by `/newtask`.
- Never use `/prtask` for read-only research or monitoring.
- One child owns each PR from creation/takeover through merge or closure.
- Every PR must be registered directly by its owning child.
- Return immediately after `/newtask` launches. Do not poll or inspect the child unless explicitly asked.
