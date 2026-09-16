---
name: review
description: Run a PR code review through /newtask in the shared "reviews" tab of the current Herdr workspace. The child reports findings plus token and dollar cost with /backtoparent; the parent includes cost in its summary and cleans up the pane.
---

# review: PR review in a Herdr pane

Launch every review with `/newtask`. The review child reports its findings with
`/backtoparent`. The parent then relays the findings and shuts down the child
agent by closing its Herdr pane.

## 1. Capture and refresh the parent identity

`HERDR_WORKSPACE_ID` and `HERDR_TAB_ID` can be stale if this pane was moved.
Treat the current pane as authoritative: inspect it, compare its workspace and
tab IDs with the environment, and replace the variables when they differ.

```sh
PARENT_PANE_ID="${HERDR_PANE_ID:?review must run inside Herdr}"
PARENT_AGENT_ID="${PI_SESSION_ID:?parent Pi agent ID is unavailable}"
PARENT_PANE_JSON="$(herdr pane get "$PARENT_PANE_ID")"
CURRENT_WORKSPACE_ID="$(jq -r '.result.pane.workspace_id' <<<"$PARENT_PANE_JSON")"
CURRENT_TAB_ID="$(jq -r '.result.pane.tab_id' <<<"$PARENT_PANE_JSON")"

if [[ "${HERDR_WORKSPACE_ID:-}" != "$CURRENT_WORKSPACE_ID" ]]; then
  export HERDR_WORKSPACE_ID="$CURRENT_WORKSPACE_ID"
fi
if [[ "${HERDR_TAB_ID:-}" != "$CURRENT_TAB_ID" ]]; then
  export HERDR_TAB_ID="$CURRENT_TAB_ID"
fi

PARENT_WORKSPACE_ID="$CURRENT_WORKSPACE_ID"
PARENT_TAB_ID="$CURRENT_TAB_ID"
```

Use only these refreshed `PARENT_WORKSPACE_ID` and `PARENT_TAB_ID` values for
tab creation, `/newtask`, and the child callback prompt.

## 2. Resolve the PR

The arguments identify the PR as a URL, `owner/repo#N`, or `#N`/`N`. Resolve
an omitted repository from context, then fetch metadata:

```sh
gh pr view <N> --repo <owner/repo> --json repository,number,title,headRefName
```

## 3. Reuse or create the reviews tab, then launch with /newtask

All reviews live in a single tab labeled `reviews` in the parent's current
workspace. Look it up first; create it only if missing.

```sh
REVIEWS_TAB_ID="$(
  herdr tab list --workspace "$PARENT_WORKSPACE_ID" \
    | jq -r '.result.tabs[] | select(.label == \"reviews\") | .tab_id' \
    | head -n 1
)"
if [[ -z "$REVIEWS_TAB_ID" ]]; then
  REVIEWS_TAB_ID="$(
    herdr tab create \
      --workspace "$PARENT_WORKSPACE_ID" \
      --label "reviews" \
      --cwd ~/dev/vercel/vercel-core \
      --no-focus \
    | jq -r '.result.tab.tab_id'
  )"
fi
```

Invoke `/newtask` with the parent workspace and `REVIEWS_TAB_ID`. If the tab
was just created, `/newtask` uses its initial pane; otherwise it splits a pane
inside the tab. Name the child agent `review-<owner>-<repo>-<N>` so multiple
reviews in the shared tab are easy to tell apart. Do not create a new
workspace, use `herdr agent start` directly, or monitor the child.

```text
/newtask --workspace <PARENT_WORKSPACE_ID> --tab <REVIEWS_TAB_ID> <REVIEW PROMPT>
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
> When the review is finished, first run:
>
> ```sh
> python3 /Users/mehulkar/.agents/skills/review/scripts/session-cost.py
> ```
>
> Invoke `/backtoparent` with the full review and the helper's complete `Review cost:` line. Put the
> cost line after the merge recommendation. Explicitly say the task is complete and ready for cleanup,
> and instruct the parent to shut down this review agent and close its Herdr pane. `/backtoparent` will
> prefix your current pane, tab, workspace, and agent IDs so the parent can identify the correct child
> safely. Never estimate tokens or dollars from the footer; the helper's session JSONL totals are
> authoritative.
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

1. Read the child pane, tab, workspace, and agent IDs from the identity block at the beginning of the
   message. Resolve the child's session path and recompute its final cost after the callback:

   ```sh
   CHILD_SESSION_FILE="$(herdr agent get "<child-pane-id>" | jq -r '.result.agent.agent_session.value')"
   python3 /Users/mehulkar/.agents/skills/review/scripts/session-cost.py "$CHILD_SESSION_FILE"
   ```

2. Relay the review findings to the user with the recomputed `Review cost:` line. This post-callback
   value supersedes the cost line embedded by the child.
   - For one review, show that review's token total, token-category breakdown, and dollar cost.
   - When summarizing multiple reviewer callbacks, show each review's cost and a final aggregate row
     summing all four token categories, total tokens, and dollars. Do not omit cached tokens.
   - If session resolution fails, use the callback's cost line. If both are unavailable, report
     `cost unavailable` rather than estimating it.
3. Verify the pane still belongs to the supplied workspace and tab:

   ```sh
   herdr pane get "<child-pane-id>"
   ```

4. Shut down the review agent and pane:

   ```sh
   herdr pane close "<child-pane-id>"
   ```

Closing the pane terminates the interactive review agent. The shared `reviews`
tab stays open for future reviews; it is only removed if the user closes it
manually. Do not close the parent pane.

If IDs changed because another pane or tab closed, list panes only in the
supplied child workspace and match the stable agent/session identity. Never
guess from a positional pane ID.

## Rules

- Before creating a tab, call `herdr pane get "$HERDR_PANE_ID"` and refresh stale `HERDR_WORKSPACE_ID` and `HERDR_TAB_ID` values from the result.
- Reuse the existing `reviews` tab when present; only create it once.
- Never create or switch to a separate review workspace.
- Always launch reviews through `/newtask` with both `--workspace` and `--tab`.
- Always require the child to report through `/backtoparent`.
- Every completed review callback must include the output of `scripts/session-cost.py`.
- Every user-facing review summary must show token and dollar cost; multi-review summaries must also
  show aggregate cost.
- A completed review must ask the parent to shut down its agent and pane.
- Do not poll, wait for, or read the child pane after launching it.
- Target cleanup by the identity supplied by `/backtoparent`, not by an
  ambiguous `review-*` name.
