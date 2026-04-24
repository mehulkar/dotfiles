# Worktrees

Before making any file edits for a code-changing task (implementation, refactor, fix, experiment), ask me whether to use a git worktree. If I say yes, call `EnterWorktree` to create an isolated worktree before editing. If I say no, edit in place.

- Skip the question for read-only/research questions, git inspection, and trivial single-line edits — just edit directly.
- Don't nest — if the session was already started inside a worktree, don't create another and don't ask.
- If I've already told you in this session to use or skip worktrees, don't ask again.
- At the end of a worktree task, ask whether to `ExitWorktree` with `keep` or `remove` rather than auto-removing.

# Git commands

Never prepend `cd <path> &&` to a git command. If you need to target a different directory, use `git -C <path> <subcommand>` instead. The `cd X && git ...` pattern triggers a permission prompt every time, and after `EnterWorktree` the CWD is already the worktree so the `cd` is redundant anyway.

# Pull requests

Keep PR bodies concise. Do not include file paths in the body — they make the description hard to skim and go stale as the branch evolves. Describe the change at the level of behavior and intent, not the file-by-file diff (reviewers can see the diff themselves).
