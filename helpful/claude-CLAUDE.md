# Worktrees

Start any code-changing task (implementation, refactor, fix, experiment) by calling `EnterWorktree` to create an isolated git worktree before making edits. This is the durable instruction that the `EnterWorktree` tool's description requires.

- Skip for read-only/research questions, git inspection, and trivial single-line edits where I explicitly opt out ("just edit it here", "no worktree").
- Don't nest — if the session was already started inside a worktree, don't create another.
- At the end of the task, ask whether to `ExitWorktree` with `keep` or `remove` rather than auto-removing.
