---
name: newtask
description: Launch a Pi subagent in its own Herdr pane and return immediately without monitoring it. The child receives the parent pane, workspace, and agent IDs for optional communication. Use when work should run independently in another pane.
---

# newtask — independent Pi subagent

Launch an interactive `pi` agent in its own Herdr pane and immediately return
control to the parent. The invocation may include `--workspace <workspace-id>`
and `--tab <tab-id>` before the task prompt. When both are supplied, create the
child pane in that exact tab. Never monitor the child. Give the child the
parent's identity for optional communication.

Always give the new Herdr pane a concise, descriptive name for its task. This requirement applies to
the pane label itself, not merely the Herdr agent name.

For PR work, instruct the child to register each PR directly with the engineering manager. The manager
will send updates straight to the child pane and retain the PR until GitHub reports it merged or closed.
The parent does not register the PR or relay monitor updates.

## Invocation

```text
/newtask [--workspace <workspace-id>] [--tab <tab-id>] <task prompt>
```

`--tab` requires `--workspace`. If neither is supplied, create the child beside
the parent in the current tab. If only `--workspace` is supplied, create a new
tab in that workspace and use its initial pane.

## Recipe

```sh
# 1. Capture the parent identity before creating the child.
PARENT_PANE_ID="${HERDR_PANE_ID:?newtask must run inside Herdr}"
PARENT_WORKSPACE_ID="${HERDR_WORKSPACE_ID:?newtask must run inside Herdr}"
PARENT_AGENT_ID="${PI_SESSION_ID:?parent Pi agent ID is unavailable}"

# 2. Create a shell pane rooted at vercel-core.
# Do not infer a repo path; the child chooses and enters its own worktree.
if both TARGET_WORKSPACE_ID and TARGET_TAB_ID were supplied; then
  # Verify TARGET_TAB_ID belongs to TARGET_WORKSPACE_ID using these results.
  herdr tab get "$TARGET_TAB_ID"
  herdr pane list --workspace "$TARGET_WORKSPACE_ID"
  # Select panes whose tab_id equals TARGET_TAB_ID. If the tab has exactly one
  # unclaimed shell pane, use it as CHILD_PANE_ID. This is the initial pane from
  # a newly created tab. Otherwise select a target-tab pane as TARGET_PANE_ID:
  herdr pane split "$TARGET_PANE_ID" --direction right \
    --cwd ~/dev/vercel/vercel-core --no-focus
  # Parse pane_id from the JSON response as CHILD_PANE_ID.
elif only TARGET_WORKSPACE_ID was supplied; then
  herdr tab create --workspace "$TARGET_WORKSPACE_ID" \
    --cwd ~/dev/vercel/vercel-core --no-focus
  # Parse the initial pane_id from the JSON response as CHILD_PANE_ID.
else
  herdr pane split "$PARENT_PANE_ID" --direction right \
    --cwd ~/dev/vercel/vercel-core --no-focus
  # Parse pane_id from the JSON response as CHILD_PANE_ID.
fi

# 2b. Capture the child's workspace and tab IDs for registry.
CHILD_TAB_ID="$(herdr pane get "$CHILD_PANE_ID" | jq -r '.result.pane.tab_id')"
CHILD_WORKSPACE_ID="$(herdr pane get "$CHILD_PANE_ID" | jq -r '.result.pane.workspace_id')"

# 3. Start Pi, then explicitly name the Herdr pane. `agent start <name>` names
# the agent and does not satisfy the pane-label requirement.
# The pane must be at its shell prompt before starting Pi.
herdr agent start <name> --kind pi --pane "$CHILD_PANE_ID"
herdr pane rename "$CHILD_PANE_ID" <descriptive-pane-name>

# If Pi fails to start because Herdr's persistent environment retains an older
# Node version, fall back to launching manually, then wait for detection:
#   herdr pane run "$CHILD_PANE_ID" "sh -lc 'fnm use 22 && node -v && exec pi'"
#   herdr agent get "$CHILD_PANE_ID"
#   herdr agent rename "$CHILD_PANE_ID" <name>

# 4. Send a self-contained task, parent identity, and PR monitoring suffix.
CHILD_PROMPT="$(printf '%s\n' \
  'Parent Herdr identity:' \
  "- pane id: $PARENT_PANE_ID" \
  "- workspace id: $PARENT_WORKSPACE_ID" \
  "- agent id: $PARENT_AGENT_ID" \
  '' \
  '<TASK PROMPT>' \
  '' \
  'PR monitoring: whenever you begin managing a GitHub PR, whether you opened it or were told to take it over, register it directly with the engineering manager by running: python3 /Users/mehulkar/dev/vercel/vercel-core/.agents/skills/em/scripts/registry.py manage --url <full-pr-url> --pane "$HERDR_PANE_ID" --tab "$HERDR_TAB_ID" --workspace "$HERDR_WORKSPACE_ID" --agent "$PI_SESSION_ID" --branch <branch> --worktree <worktree-path>. Do this once per PR before waiting on CI. Do not release it; monitoring continues until GitHub reports it merged or closed. Engineering manager updates will arrive directly in this pane.')"
herdr agent prompt "$CHILD_PANE_ID" "$CHILD_PROMPT"

# 5. Return immediately.
```

Tell the user the child pane ID and what was launched, then continue serving the
parent session.

## Rules

- Include `HERDR_PANE_ID`, `HERDR_WORKSPACE_ID`, and `PI_SESSION_ID` in every child's first prompt as the parent pane ID, workspace ID, and agent ID.
- Treat `--workspace` and `--tab` as placement arguments, not as part of the child task prompt.
- Reject `--tab` without `--workspace`, and verify that the specified tab belongs to the specified workspace before creating the child.
- When a target tab is specified, never split the parent pane. Use the target tab's sole unclaimed shell pane when available; otherwise split a pane in the target tab.
- Start children from `~/dev/vercel/vercel-core`. The child chooses its repository and worktree.
- Always set a concise, descriptive pane label with `herdr pane rename` after starting Pi. Naming the agent does not count as naming the pane.
- If starting Pi manually via `pane run`, run `fnm use 22 && node -v` first.
- Give the child a complete, self-contained task prompt and definition of done.
- For PR work, include direct engineering manager registration instructions in the first prompt.
  The child registers its own PR, receives updates directly, and leaves it registered until merged or closed.
- After submitting the task, do not poll, wait, read output, schedule checks, or run background monitoring.
- Only inspect or interact with the child later if the user explicitly asks.
- Do not instruct the child to invoke a completion or parent-reporting skill. The user triggers those manually.
- Target agents by pane ID, not by the ambiguous `pi` label.

## Gotchas

- Pane and tab IDs can renumber when one closes. Re-list within the captured workspace and match stable session or terminal identity before cleanup.
- Splits support only `right` and `down` and are 50/50.

## Quick reference

- `herdr tab get <tab-id>`
- `herdr tab create --workspace <workspace-id> --cwd <path> --no-focus`
- `herdr pane split <pane-id> --direction right|down --cwd <path> --no-focus`
- `herdr pane rename <pane-id> <name>`
- `herdr agent start <name> --kind pi --pane <pane-id>`
- `herdr pane run <pane-id> <command>`
- `herdr agent get <pane-id>`
- `herdr agent rename <pane-id> <name>`
- `herdr agent prompt <pane-id> <text>`
- `herdr pane list --workspace <workspace-id>`
- `herdr pane close <pane-id>`
