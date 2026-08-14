---
name: backtoparent
description: Send a message or final report from a child Pi task back to its parent Herdr pane using the parent pane and workspace IDs supplied at launch. Use when a child needs to communicate with its parent task.
---

# backtoparent — communicate with the parent task

Use the parent Herdr identity included in the child's initial prompt:

- parent pane ID
- parent workspace ID
- parent agent ID

The text passed to `/backtoparent` is the message to send. If no text was passed,
send a concise summary of the child's result, current status, or blocker.
Include the CURRENT herdr pane ID, workspace ID, and agent ID in the message to identify
where it came from.

## Recipe

```sh
PARENT_PANE_ID='<parent pane id from the initial prompt>'
PARENT_WORKSPACE_ID='<parent workspace id from the initial prompt>'
MESSAGE='<message or final report>'

# Confirm the pane still exists in the expected workspace. Do not send to a pane
# with the same positional ID in another workspace.
ACTUAL_WORKSPACE_ID="$(herdr pane get "$PARENT_PANE_ID" | jq -r '.result.pane.workspace_id')"
test "$ACTUAL_WORKSPACE_ID" = "$PARENT_WORKSPACE_ID"

# Submit the message as a new prompt to the parent agent.
herdr agent prompt "$PARENT_PANE_ID" "$MESSAGE"
```

If the pane does not exist or its workspace does not match, do not guess another
target. Report locally that the parent could not be reached.

## Rules

- Use the exact parent pane and workspace IDs from the initial prompt.
- Verify the workspace before sending.
- Send one concise, self-contained message.
- Use `herdr agent prompt`; do not write raw terminal input.
- Do not close either the parent or child pane.
