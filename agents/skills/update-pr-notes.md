---
name: update-pr-notes
description: Update a PR's title and body to reflect the current full diff plus any non-obvious notes or reasoning from the current session. Use when the branch has evolved and the PR description is stale, or the user asks to "update the PR notes", "sync the PR description", "rewrite the PR title/body", or "refresh the PR".
allowed-tools: Bash(gh pr view:*) Bash(gh pr edit:*) Bash(gh pr diff:*) Bash(gh pr list:*) Bash(git log:*) Bash(git diff:*) Bash(git rev-parse:*) Bash(git branch:*) Bash(git status:*)
---

# Update PR Notes

Rewrite a PR's title and body so they describe what's actually in the diff *now*, plus any non-obvious reasoning from the current session that a reviewer wouldn't get from the diff alone.

This is a **sync** action, not compression. The branch has evolved, decisions were made in chat, and the PR text is stale — bring it back in line with reality.

## Inputs

The user may give you:
- A PR number, URL, or `owner/repo#123` reference.
- Nothing — auto-detect the PR from the current branch with `gh pr view --json number,title,body,headRefName,baseRefName,url`.

If there's no PR for the current branch, stop and tell the user. Don't create one.

## Gather

Before composing, collect three things:

1. **Current PR title and body** — `gh pr view <ref> --json number,title,body,url`. Keep the `number` and `url` for the apply step.
2. **Full diff** — `gh pr diff <ref>`. If huge, skim and describe behaviorally; never enumerate files in the body.
3. **Session reasoning** — scan the conversation already in context for things a reviewer would otherwise have to ask about:
   - decisions taken ("considered X, chose Y because Z")
   - scope cuts and follow-ups deferred
   - surprising findings (a default was wrong, an assumption broke)
   - migration, rollout, or risk notes
   - links to incidents, dashboards, or related PRs that came up in chat
   Pick the parts a reviewer would care about — don't dump the transcript.

## Compose

Follow the project's PR-writing rules from `~/dev/vercel/vercel-core/CLAUDE.md` and `~/.claude/CLAUDE.md`. **Default to compression** — the goal is the same intent in less text. A short paragraph or 2–4 bullets is usually enough; reach for headings only when there are structurally distinct sections (Summary + Migration + Test plan).

**Title** — behavioral claim, imperative, ≤70 chars. No file paths. No "WIP" / "draft" prefixes unless the user adds them. If the existing title is already accurate, keep it.

**Body**
- Lead with the change as a behavioral claim ("Remove X — assigned in error, never used"), not the audit trail.
- Frame side-effect fixes as bug fixes directly ("Pro teams were getting standard, fix to elastic"). No "behavior delta" hedging.
- Collapse related code paths into one bullet — upgrade/downgrade are one transition, the diff enumerates the files.
- Surface the design context that makes the change legible — usually a one-sentence contrast with related concepts ("deployments have X, projects have Y, teams don't need either").

**Cut**
- **File paths and file-by-file breakdowns.** Reviewers can read the diff. Describe behavior, not which files changed.
- **Filler phrases.** "This PR …", "In this change we …", "The purpose of this PR is to …" — strip them. Lead with the verb.
- **Restated context the title already covers.**
- **Bulleted lists of obvious mechanical changes** (renamed import, updated type, moved helper) — one line summarizing the cleanup, not a per-file enumeration.
- **Generated boilerplate** unless it carries real signal: AI-tool footers ("🤖 Generated with…"), empty `## Test plan` / `## Notes` sections, stock template headings the author didn't fill in.
- **Hedging and meta-commentary.** "I think", "this might", "open to feedback on…" → drop or fold into a single explicit open question.
- **Duplication across sections.** If summary and description say the same thing, keep one.

**Keep**
- **Why the change exists** — user-visible behavior change, the bug being fixed, or the constraint forcing the work. If there's no "why" at all, add one short line if you can infer it confidently; otherwise flag it.
- **Non-obvious decisions** — anything a reviewer would otherwise have to ask about (chose A over B, intentional scope cut, follow-up deferred). This is where session reasoning lives.
- **Risks, migration steps, or rollout notes** — anything that matters at merge time.
- **Links** to issues, designs, dashboards, prior PRs.
- **Filled-in test plans** with actual items. Drop the heading if the list is empty.

**Folding in session notes** — weave non-obvious reasoning into the relevant bullet. If a piece of context doesn't fit any bullet, add a short `## Notes` (or `## Context`) section at the end. One or two sentences each; don't dump the transcript.

## Apply

Print the proposed title and body to the chat first so the user sees what's about to land, then apply:

```bash
gh pr edit <num> --title "<new title>" --body-file -
```

Pipe the new body via stdin so backticks, quotes, and heredocs survive intact. Use the project HEREDOC pattern:

```bash
gh pr edit <num> --title "<new title>" --body "$(cat <<'EOF'
<new body>
EOF
)"
```

- If the title hasn't changed, omit `--title`.
- If the body hasn't changed, skip the call and tell the user there was nothing to update.
- After applying, surface the PR URL so the user can click through and verify.

## Don't

- Don't invent details that aren't in the diff or the session.
- Don't enumerate files. Behavior, not paths.
- Don't open, close, merge, or comment on the PR — only edit title and body.
- Don't keep AI-tool footers ("🤖 Generated with…") in the rewritten body.
- Don't push commits, amend history, or change the branch — only the PR description.
- Don't change meaning to hit a length target — compression, not editorial rewriting. If the original was already tight and accurate, return it largely unchanged.
