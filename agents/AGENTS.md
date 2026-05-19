# Worktrees

Before making any file edits for a code-changing task (implementation, refactor, fix, experiment),
ask me whether to use a git worktree. If I say yes, call `EnterWorktree` to create an isolated
worktree before editing. If I say no, edit in place.

- Skip the question for read-only/research questions, git inspection, and trivial single-line edits
  — just edit directly.
- Don't nest — if the session was already started inside a worktree, don't create another and don't
  ask.
- If I've already told you in this session to use or skip worktrees, don't ask again.
- At the end of a worktree task, ask whether to `ExitWorktree` with `keep` or `remove` rather than
  auto-removing.

# Git commands

Never prepend `cd <path> &&` to a git command. If you need to target a different directory, use `git
-C <path> <subcommand>` instead. The `cd X && git ...` pattern triggers a permission prompt every
time, and after `EnterWorktree` the CWD is already the worktree so the `cd` is redundant anyway.

# Pull requests

Keep PR bodies concise. Do not include file paths in the body — they make the description hard to
skim and go stale as the branch evolves. Describe the change at the level of behavior and intent,
not the file-by-file diff (reviewers can see the diff themselves).

- Lead with the change as a behavioral claim, not the audit trail. Open with "Remove X — assigned in
  error, never used" rather than "X is written in three places but never read at runtime." Mechanics
  belong below the headline, if anywhere.
- Frame side-effect fixes as bug fixes. If a refactor incidentally corrects a wrong default or
  unlocks intended behavior, name it directly ("Pro teams were getting standard, fix to elastic").
  Don't hedge with phrasing like "behavior delta" or "matches the original (un-realised) intent."
- Collapse related code paths into one bullet when they describe one concept. Upgrade and downgrade
  are one transition; the diff already enumerates the files.
- Do not include a Validation section that just talks about running or adding tests and lint.
- Don't escape backticks in heredoc-quoted PR bodies. When passing a body via `gh pr create --body
  "$(cat <<'EOF' ... EOF)"`, the quoted `<<'EOF'` heredoc disables shell interpretation, so a
  backslash before a backtick is preserved literally and reaches GitHub as `\` — markdown renders
  the backslash and the code styling is lost. Write `` `foo` ``, not `` \`foo\` ``. Same applies to
  `$`, `"`, and other shell metacharacters; the quoted heredoc handles them.
- Do not use capital letters in the PR title. especially if there is a "[prefix]", do not make the
  next character after that a capital letter.
