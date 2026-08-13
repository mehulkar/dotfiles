---
name: backtoparent
description: Send a message or final report from a child Pi task back to its parent Herdr pane using the parent pane and workspace IDs supplied at launch. Always identifies the child pane, tab, workspace, and agent, and requests pane cleanup when the task is done.
---

# backtoparent: communicate with the parent task

Use the parent Herdr identity included in the child's initial prompt:

- parent pane ID
- parent workspace ID
- parent agent ID

The text passed to `/backtoparent` is the message to send. If no text was passed,
send a concise summary of the child's result, current status, or blocker.

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

If the input says or clearly implies that the child task is complete and ready
for cleanup, append this instruction to the message sent to the parent:

```text
Cleanup requested: verify the source pane, workspace, and tab identity above, then close this child pane with `herdr pane close <CHILD_PANE_ID>`.
```

Treat phrases such as `done`, `finished`, `complete`, `ready for cleanup`,
`close my pane`, `kill my pane`, and `shut me down` as cleanup requests. Do not
append the cleanup instruction for progress updates, questions, or blockers.

Send the completed message:

```sh
PARENT_PANE_ID='<parent pane id from the initial prompt>'
PARENT_WORKSPACE_ID='<parent workspace id from the initial prompt>'
MESSAGE='<identity-prefixed message or final report>'

# Confirm the pane still exists in the expected workspace. Do not send to a pane
# with the same positional ID in another workspace.
ACTUAL_WORKSPACE_ID="$(herdr pane get "$PARENT_PANE_ID" | jq -r '.result.pane.workspace_id')"
test "$ACTUAL_WORKSPACE_ID" = "$PARENT_WORKSPACE_ID"

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
- Use `herdr agent prompt`; do not write raw terminal input.
- When the task is ready for cleanup, tell the parent to verify and close the
  child pane.
- Do not close the parent pane.
- Do not close the child pane yourself. The parent performs cleanup after it
  receives the result.
