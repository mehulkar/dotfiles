---
name: review
description: Run a PR code review in a dedicated Pi subagent pane in the "pr reviews" Herdr workspace, report the result to the parent with /backtoparent, then have the parent close the review pane. Use when the user asks to review a PR, such as /skill:review <PR URL, owner/repo#N, or #N>.
---

# review: PR review in a Herdr pane

Run a read-only code review in its own pane in the **pr reviews** Herdr
workspace. The child reports its result with `/backtoparent`. After receiving
the report, the parent relays it to the user and closes the child review pane.

## 1. Capture the parent identity

Before creating anything, capture all parent identifiers:

```sh
PARENT_PANE_ID="${HERDR_PANE_ID:?review must run inside Herdr}"
PARENT_WORKSPACE_ID="${HERDR_WORKSPACE_ID:?review must run inside Herdr}"
PARENT_TAB_ID="${HERDR_TAB_ID:?review must run inside Herdr}"
PARENT_AGENT_ID="${PI_SESSION_ID:?parent Pi agent ID is unavailable}"
```

## 2. Ensure the pr reviews workspace exists

```sh
herdr workspace list
```

Find the workspace whose `label` is `pr reviews` and note its `workspace_id`.
If missing, create it and capture `result.workspace.workspace_id`:

```sh
herdr workspace create --label "pr reviews"
```

## 3. Resolve the review target

The skill arguments identify the PR as a URL, `owner/repo#N`, or `#N`/`N`.
Resolve the repository from context when omitted, then fetch its metadata:

```sh
gh pr view <N> --repo <owner/repo> --json repository,number,title,headRefName
```

For Vercel repositories, use `~/dev/vercel/vercel-core/<repo>` as the child CWD.
Otherwise use the known local repository root or `~/dev/vercel/vercel-core`.

## 4. Launch the child and give it callback instructions

Create the review agent without focusing it:

```sh
herdr agent start review-<N> --workspace <pr-reviews-workspace-id> \
  --cwd <repo-dir> --split right --no-focus -- pi "<REVIEW PROMPT>"
```

Capture `result.agent.pane_id` as `CHILD_PANE_ID`. Then inspect the child pane
to capture its workspace and tab IDs. Do not assume positional IDs:

```sh
herdr pane get "$CHILD_PANE_ID"
```

Capture these values from the response:

- `CHILD_WORKSPACE_ID`
- `CHILD_TAB_ID`

The initial `<REVIEW PROMPT>` must be self-contained and include this content,
adapted to the PR and with every placeholder replaced:

> Review PR `<owner/repo>#<N>`, "<title>". Run `gh pr diff <N> --repo
> <owner/repo>` and `gh pr view <N> --repo <owner/repo> --json ...` to inspect
> it. Do a read-only review covering correctness, error handling, security,
> tests, performance, naming/style, and API or behavior changes. Do not edit
> files. Produce a one-line summary, file-by-file findings tagged `blocker`,
> `major`, or `nit`, and a merge recommendation of approve, request changes, or
> comment.
>
> When finished, you MUST invoke `/backtoparent` with the full review. Your
> callback must also say: `Review complete. Close my review pane.` Include your
> review pane ID `<CHILD_PANE_ID>`, workspace ID `<CHILD_WORKSPACE_ID>`, tab ID
> `<CHILD_TAB_ID>`, and agent ID if available so the parent can safely identify
> and close this pane.
>
> Parent Herdr identity for `/backtoparent`:
> - pane ID: `<PARENT_PANE_ID>`
> - workspace ID: `<PARENT_WORKSPACE_ID>`
> - tab ID: `<PARENT_TAB_ID>`
> - agent ID: `<PARENT_AGENT_ID>`

If the start command cannot include identifiers that are only known after the
pane is created, start Pi first, capture the child identity, and submit the full
prompt with `herdr agent prompt "$CHILD_PANE_ID" "$REVIEW_PROMPT"`.

Return immediately after prompting the child. Do not poll or gather its terminal
output. The `/backtoparent` callback is the completion mechanism.

## 5. Handle the callback and clean up

When the child callback arrives:

1. Relay the review findings to the user.
2. Read the supplied child pane, workspace, and tab IDs.
3. Verify that the pane still belongs to the supplied child workspace and tab:

   ```sh
   herdr pane get "<child-pane-id>"
   ```

4. Close that review pane:

   ```sh
   herdr pane close "<child-pane-id>"
   ```

5. If identifiers changed because another pane or tab closed, list panes only in
   the supplied child workspace and match the stable agent/session identity.
   Never guess from a positional pane ID.

Do not close the parent pane. The phrase `Close my review pane` always means the
child review pane identified in the callback.

## Gotchas

- Pane and tab IDs can renumber when another pane or tab closes. Verify the
  workspace and tab before cleanup.
- Target the review by pane ID. Agent names such as `review-*` can collide.
- Pi remains interactive after finishing. A successful callback does not exit
  it, so the parent must close the child pane.
- If `/backtoparent` cannot reach the exact parent pane in the exact parent
  workspace, the child must report the failure locally and leave the pane open.
