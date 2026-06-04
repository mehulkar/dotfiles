---
name: wip
description: List my currently open pull requests on GitHub. Use when the user asks "what's my WIP", "what are my open PRs", "list my PRs", "show my open PRs", or wants a current snapshot of their authored work-in-flight. Accepts optional filter args (org, repo, keyword) to narrow the search.
argument-hint: [filter]
allowed-tools: Bash(gh search:*) Bash(gh auth status:*) Bash(gh api:*)
---

# WIP — My Open PRs

List the user's open pull requests on GitHub, optionally narrowed by `$ARGUMENTS`.

The user must have `gh` CLI installed and authenticated. If `gh auth status` fails, tell them to run `gh auth login`. Resolve the current GitHub username from `gh api user --jq .login` — do not hardcode it.

## Inputs

`$ARGUMENTS` may be empty, or contain one or more filters. Interpret them in this order:

- **`org:<name>`** or a bare org name → pass to `--owner <name>` (repeatable for multiple orgs).
- **`repo:<owner>/<name>`** or a bare `owner/name` token → pass to `--repo <owner>/<name>`.
- **Anything else** → treat as a free-text keyword and append to the search query.

If no filter is given, search across all orgs/repos the user has access to. Do **not** default to any specific org.

## Instructions

Build the search incrementally:

```
gh search prs --author "@me" --state open --json repository,number,title,url,updatedAt,isDraft --limit 100 [--owner <org> ...] [--repo <owner>/<name> ...] [<keyword>]
```

Notes:
- Use `--author "@me"` so the command works for any logged-in user.
- Use the `--owner` / `--repo` flags rather than `org:` / `repo:` in the query string, and do not pass `--archived false`. Both `org:` and `--archived false` cause `gh` to return an empty array when combined with `--json`.
- Keywords go in the positional query, not as flags.

## Output format

- Group by status: **Ready for review** first, then **Drafts**.
- Within each group, sort by `updatedAt` descending (most recently updated first).
- Each bullet: `[repo#number](url) — title`
- Omit a group if it would be empty.
- If there are zero results, say so plainly — don't print empty headers.

## Notes

- Do not paginate or filter further unless the user asks.
- Do not include closed/merged PRs. The query already excludes them.
- Do not editorialize or add status emoji — just the list.
