---
name: review
description: Run a PR code review through /newtask in a new tab in the current Herdr workspace. The child reports with /backtoparent and asks the parent to shut down its review agent and pane. Use when the user asks to review a PR, such as /skill:review <PR URL, owner/repo#N, or #N>.
---

# review: PR review in a Herdr pane

Launch every review with `/newtask`. The review child reports its findings with
`/backtoparent`. The parent then relays the findings and shuts down the child
agent by closing its Herdr pane.

## 1. Capture the parent identity

```sh
PARENT_PANE_ID="${HERDR_PANE_ID:?review must run inside Herdr}"
PARENT_WORKSPACE_ID="${HERDR_WORKSPACE_ID:?review must run inside Herdr}"
PARENT_TAB_ID="${HERDR_TAB_ID:?review must run inside Herdr}"
PARENT_AGENT_ID="${PI_SESSION_ID:?parent Pi agent ID is unavailable}"
```

## 2. Resolve the PR

The arguments identify the PR as a URL, `owner/repo#N`, or `#N`/`N`. Resolve
an omitted repository from context, then fetch metadata:

```sh
gh pr view <N> --repo <owner/repo> --json repository,number,title,headRefName
```

## 3. Create a review tab and launch with /newtask

Create a new tab in the parent's current workspace without focusing it:

```sh
herdr tab create \
  --workspace "$PARENT_WORKSPACE_ID" \
  --label "review <owner/repo>#<N>" \
  --cwd ~/dev/vercel/vercel-core \
  --no-focus
```

Capture `result.tab.tab_id` as `REVIEW_TAB_ID`. Invoke `/newtask` with both the
parent workspace and new tab so it uses that tab's initial pane. Do not create a
new workspace, use `herdr agent start` directly, or monitor the child.

```text
/newtask --workspace <PARENT_WORKSPACE_ID> --tab <REVIEW_TAB_ID> <REVIEW PROMPT>
```

Use this self-contained review prompt with every placeholder replaced:

> Review PR `<owner/repo>#<N>`, "<title>". Run `gh pr diff <N> --repo
> <owner/repo>` and `gh pr view <N> --repo <owner/repo> --json ...` to inspect
> it. Do a read-only review covering correctness, error handling, security,
> tests, performance, naming/style, and API or behavior changes. Do not edit
> files. Produce a one-line summary, file-by-file findings tagged `blocker`,
> `major`, or `nit`, and a merge recommendation of approve, request changes, or
> comment.
>
> When the review is finished, invoke `/backtoparent` with the full review and
> explicitly say the task is complete and ready for cleanup. Instruct the parent
> to shut down this review agent and close its Herdr pane. `/backtoparent` will
> prefix your current pane, tab, workspace, and agent IDs so the parent can
> identify the correct child safely.
>
> Parent Herdr identity for `/backtoparent`:
> - pane ID: `<PARENT_PANE_ID>`
> - workspace ID: `<PARENT_WORKSPACE_ID>`
> - tab ID: `<PARENT_TAB_ID>`
> - agent ID: `<PARENT_AGENT_ID>`

Return immediately after `/newtask` launches the child. The callback is the
completion mechanism.

## 4. Handle /backtoparent and clean up

When the callback arrives:

1. Relay the review findings to the user.
2. Read the child pane, tab, workspace, and agent IDs from the identity block at
   the beginning of the message.
3. Verify the pane still belongs to the supplied workspace and tab:

   ```sh
   herdr pane get "<child-pane-id>"
   ```

4. Shut down the review agent and pane:

   ```sh
   herdr pane close "<child-pane-id>"
   ```

Closing the pane terminates the interactive review agent. Do not close the
parent pane.

If IDs changed because another pane or tab closed, list panes only in the
supplied child workspace and match the stable agent/session identity. Never
guess from a positional pane ID.

## Rules

- Always create a new tab in the parent's current Herdr workspace.
- Never create or switch to a separate review workspace.
- Always launch reviews through `/newtask` with both `--workspace` and `--tab`.
- Always require the child to report through `/backtoparent`.
- A completed review must ask the parent to shut down its agent and pane.
- Do not poll, wait for, or read the child pane after launching it.
- Target cleanup by the identity supplied by `/backtoparent`, not by an
  ambiguous `review-*` name.
