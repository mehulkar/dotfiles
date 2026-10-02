---
name: review
description: Run a PR code review through /newtask in capped "reviews" tabs of the current Herdr workspace. The child reports findings plus token and dollar cost with /backtoparent; the parent includes cost in its summary and cleans up the pane.
---

# review: PR review in a Herdr pane

Invocation:

```text
/review [--panel | --model <provider/model> | --models <model-a,model-b,...>] <PR URL, owner/repo#N, or #N>
```

`--panel` is the standard multi-model review. It means `--models` with the exact model IDs listed one per
line in `/Users/mehulkar/.agents/skills/review/panel-models.txt`. That file is the single source of truth
for the panel; read it at invocation time and never hardcode the models elsewhere. Every other workflow
that wants the standard review (`/prtask`, EM review triage) must use `--panel`.

If `--model` is supplied, remove it from the PR arguments and pass it to `/newtask`; never silently
substitute the default model. If `--models` is supplied, split its comma-separated exact model IDs and
launch one review child per model. This is one `/review` orchestration even though it fans out to several
children. Never invoke `/review` again for that PR just to add another model. Every review child reports
its findings with `/backtoparent`. The invoking agent aggregates callbacks and closes each child pane.

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

## 3. Allocate review panes, then launch with /newtask

Reviews live in capped tabs labeled `reviews`, `reviews (2)`, `reviews (3)`, ... in the parent's current
workspace, with at most 4 panes per tab arranged as a grid. Never create review tabs or split panes by
hand. Allocate one pane per review child with the shared helper, which keeps one fan-out in a single tab
when it fits and opens the next numbered tab on overflow:

```sh
SLOTS="$(python3 /Users/mehulkar/.agents/skills/review/scripts/review-slots.py \
  --workspace "$PARENT_WORKSPACE_ID" --count <number of review children>)"
# {"panes": [{"pane_id": "...", "tab_id": "..."}, ...]}
```

Invoke `/newtask` once per review child, passing one allocated pane each:

```text
/newtask [--model <REVIEW_MODEL>] --workspace <PARENT_WORKSPACE_ID> --tab <SLOT_TAB_ID> --pane <SLOT_PANE_ID> <REVIEW PROMPT>
```

Name each child `review-<owner>-<repo>-<N>-<model-slug>` so concurrent reviewers are distinguishable.
Without a model, use `review-<owner>-<repo>-<N>`. Do not create a new workspace, use `herdr agent start`
directly, or monitor children.

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

Return immediately after launching all selected review children. Their callbacks are the completion
mechanism. For `--models`, collect every callback before producing one aggregate recommendation and cost.

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

Closing the pane terminates the interactive review agent. A review tab closes on its own when its last
pane closes. Do not close the parent pane.

If IDs changed because another pane or tab closed, list panes only in the
supplied child workspace and match the stable agent/session identity. Never
guess from a positional pane ID.

## Rules

- Before creating a tab, call `herdr pane get "$HERDR_PANE_ID"` and refresh stale `HERDR_WORKSPACE_ID` and `HERDR_TAB_ID` values from the result.
- Allocate review panes only with `scripts/review-slots.py`: at most 4 panes per `reviews` tab, overflow
  into `reviews (2)`, `reviews (3)`, and so on.
- Never create or switch to a separate review workspace.
- Always launch reviews through `/newtask` with `--workspace`, `--tab`, and the allocated `--pane`.
- When invoked with `--panel`, `--model`, or `--models`, pass every exact provider/model to `/newtask` and include
  the model in each child name and callback summary.
- Treat one `--panel` or `--models` invocation as the sole `/review` orchestration for that PR; do not
  rerun it.
- Always require the child to report through `/backtoparent`.
- Every completed review callback must include the output of `scripts/session-cost.py`.
- Every user-facing review summary must show token and dollar cost; multi-review summaries must also
  show aggregate cost.
- A completed review must ask the parent to shut down its agent and pane.
- Do not poll, wait for, or read the child pane after launching it.
- Target cleanup by the identity supplied by `/backtoparent`, not by an
  ambiguous `review-*` name.
