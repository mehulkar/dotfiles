---
name: backtoparent
description: Send a message or final report from a child Pi task back to its parent Herdr pane using the parent pane and workspace IDs supplied at launch. Always identifies the child pane, tab, workspace, and agent.
---

# backtoparent: communicate with the parent task

Use the parent Herdr identity included in the child's initial prompt:

- parent pane ID
- parent workspace ID
- parent agent ID

The text passed to `/backtoparent` is the message to send. If no text was passed,
send a concise summary of the child's result, current status, or blocker.

PR ownership callbacks are control-plane messages for orchestrators. Send one immediately whenever
this child starts managing a PR, whether it opened the PR or was assigned an existing one:

```text
PR ownership started: https://github.com/OWNER/REPO/pull/123
```

If it stops owning an unmerged PR, send:

```text
PR ownership ended: https://github.com/OWNER/REPO/pull/123
```

Use full canonical PR URLs. These callbacks remain required even when ordinary progress/blocker
reporting is disabled.

## Recipe

Capture the child's current identity:

```sh
CHILD_PANE_ID="${HERDR_PANE_ID:?backtoparent must run inside Herdr}"
CHILD_TAB_ID="${HERDR_TAB_ID:?child tab ID is unavailable}"
CHILD_WORKSPACE_ID="${HERDR_WORKSPACE_ID:?child workspace ID is unavailable}"
CHILD_AGENT_ID="${PI_SESSION_ID:?child Pi agent ID is unavailable}"
```

Build every message with this identity block at the very beginning, before the
report text:

```text
Source Herdr identity:
- pane id: <CHILD_PANE_ID>
- tab id: <CHILD_TAB_ID>
- workspace id: <CHILD_WORKSPACE_ID>
- agent id: <CHILD_AGENT_ID>

<message or final report>
```

Before sending, wait until the parent pane's input area is clear. If the user
is typing in the parent pane, sending a prompt would garble both inputs. Poll
the visible terminal content and check the input region (between the two
horizontal rule lines above the status bar):

```sh
wait_for_clear_input() {
  local pane_id="$1"
  local max_wait=120
  local waited=0
  while [ "$waited" -lt "$max_wait" ]; do
    local draft
    draft="$(herdr agent read "$pane_id" --source visible --format text 2>/dev/null \
      | python3 -c "
import sys
lines = list(sys.stdin)
rules = [i for i,l in enumerate(lines) if l.strip() and set(l.strip()) == {'\u2500'}]
if len(rules) >= 2:
    between = lines[rules[-2]+1:rules[-1]]
    text = ''.join(between).strip()
    print(text)
" 2>/dev/null)"
    if [ -z "$draft" ]; then
      return 0
    fi
    sleep 3
    waited=$((waited + 3))
  done
  # Timeout: send anyway rather than losing the message entirely.
  return 0
}
```

Send the completed message:

```sh
PARENT_PANE_ID='<parent pane id from the initial prompt>'
PARENT_WORKSPACE_ID='<parent workspace id from the initial prompt>'
MESSAGE='<identity-prefixed message or final report>'

# Confirm the pane still exists in the expected workspace. Do not send to a pane
# with the same positional ID in another workspace.
ACTUAL_WORKSPACE_ID="$(herdr pane get "$PARENT_PANE_ID" | jq -r '.result.pane.workspace_id')"
test "$ACTUAL_WORKSPACE_ID" = "$PARENT_WORKSPACE_ID"

wait_for_clear_input "$PARENT_PANE_ID"
herdr agent prompt "$PARENT_PANE_ID" "$MESSAGE"
```

If the parent pane does not exist or its workspace does not match, do not guess
another target. Report locally that the parent could not be reached.

## Rules

- Put the child's current pane, tab, workspace, and agent IDs at the beginning of
  every message.
- Use the exact parent pane and workspace IDs from the initial prompt.
- Verify the parent workspace before sending.
- Send one concise, self-contained message.
- Send PR ownership started/ended callbacks immediately with full canonical URLs. They are
  control-plane metadata, not progress updates.
- Use `herdr agent prompt`; do not write raw terminal input.
- Never request or suggest pane cleanup, even when reporting that the task is
  complete. Pane lifecycle is controlled separately from this skill.
- Do not close the parent pane or child pane.
- Always wait for the parent pane's input to be clear before sending. Do not
  skip this step even if the message is urgent.
