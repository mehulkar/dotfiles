# AGENTS.md

This repo is Mehul Kar's personal dotfiles. Alongside the usual shell/vim/git
configuration, it also vendors personal AI agent instructions and settings
(primarily for Claude Code).

## Layout

- `setup.sh` — installer. Symlinks `essentials/*` into `$HOME` as dotfiles,
  wires up Claude Code config, installs brew deps, applies macOS defaults, etc.
- `essentials/` — files symlinked into `$HOME` (aliases, env, path, vimrc,
  tmux.conf, gitconfig-defaults, startup, etc.).
- `helpful/` — configs that live outside `$HOME` or need different placement:
  - `claude-CLAUDE.md` → symlinked to `~/.claude/CLAUDE.md` (global Claude Code
    instructions that apply to every project).
  - `claude-settings.json` → symlinked to `~/.claude/settings.json`.
  - `starship.toml`, `git-completion.bash`, `git-prompt`, `ps1`.
- `gitconfig.sample` — starter `~/.gitconfig`. `setup.sh` seeds it on first
  run and prompts before overwriting.
- `.claude/` — per-repo Claude Code settings for working *in this repo*
  (not the global instructions — those are in `helpful/claude-CLAUDE.md`).

## Notes for agents working in this repo

- Edits to `helpful/claude-CLAUDE.md` change the global Claude Code behavior on
  this machine once `setup.sh` has run (it's symlinked to `~/.claude/CLAUDE.md`).
  Treat changes there as affecting every future session, not just this repo.
- `essentials/*` files are symlinked without the leading dot — `aliases`
  becomes `~/.aliases`, `vimrc` becomes `~/.vimrc`, etc. Name new files
  accordingly.
- Secrets go in `~/.secret` (sourced by `~/.zshrc` if present) and are
  intentionally not tracked here.
