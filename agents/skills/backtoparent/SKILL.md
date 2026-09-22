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

A PM-launched research child may end its completed report with the exact cleanup request supplied in
its initial prompt. It must remain idle for follow-up questions and must not close its own pane.

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

Before sending, use the shared `safe-herdr-message` helper. It verifies the
parent workspace and waits for the Pi input area to be clear, so a callback
cannot garble a draft the parent is typing.

Send the completed message:

```sh
PARENT_PANE_ID='<parent pane id from the initial prompt>'
PARENT_WORKSPACE_ID='<parent workspace id from the initial prompt>'
MESSAGE='<identity-prefixed message or final report>'

python3 /Users/mehulkar/dev/vercel/vercel-core/.agents/skills/safe-herdr-message/scripts/send.py \
  --pane "$PARENT_PANE_ID" \
  --workspace "$PARENT_WORKSPACE_ID" \
  --message "$MESSAGE"

# A nonzero exit means the parent pane disappeared, changed workspace, or
# remained active for two minutes. Do not bypass the helper with raw input.
```

If the parent pane does not exist or its workspace does not match, do not guess
another target. Report locally that the parent could not be reached.

## Rules

- Put the child's current pane, tab, workspace, and agent IDs at the beginning of every message.
- Use the exact parent pane and workspace IDs from the initial prompt.
- Use the shared safe-herdr-message helper; it verifies the parent workspace and waits for clear input.
- Send one concise, self-contained message.
- Send PR ownership started/ended callbacks immediately with full canonical URLs. They are control-plane metadata, not progress updates.
- Use `herdr agent prompt`; do not write raw terminal input.
- Never request or suggest pane cleanup unless the initial PM research prompt explicitly supplied the
  cleanup-request handshake. In that case, include the exact requested line and remain idle for follow-ups.
  Pane lifecycle is always controlled by the parent.
- Do not close the parent pane or child pane.
- Always wait for the parent pane's input to be clear before sending. Do not
  skip this step even if the message is urgent.
