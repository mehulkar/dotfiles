#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="$HOME/dotfiles-bak/$(date +%Y%m%d-%H%M%S)"

# Brew packages required by essentials (aliases, env, gitconfig, etc.)
BREW_DEPS="bat eza gh jq fzf highlight vim fnm starship"
CASK_DEPS="ghostty"

# --- Pretty output helpers --------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_CYAN=''; C_GREEN=''; C_YELLOW=''
fi

_short() { printf '%s' "${1/#$HOME/~}"; }

section() { printf '\n%s==>%s %s%s%s\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }
ok()      { printf '    %s✓%s %s%s%s\n'  "$C_GREEN"  "$C_RESET" "$C_DIM" "$1" "$C_RESET"; }
act()     { printf '    %s→%s %s\n'      "$C_GREEN"  "$C_RESET" "$1"; }
warn()    { printf '    %s!%s %s\n'      "$C_YELLOW" "$C_RESET" "$1"; }
info()    { printf '    %s\n' "$1"; }

function install_deps() {
  section "Homebrew packages"
  if ! command -v brew &>/dev/null; then
    act "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
  fi
  act "brew: $BREW_DEPS"
  brew install $BREW_DEPS
  for cask in $CASK_DEPS; do
    if brew list --cask "$cask" &>/dev/null; then
      ok "cask $cask (already installed)"
      continue
    fi
    if ! brew install --cask "$cask"; then
      warn "cask $cask install failed; trying --adopt"
      brew install --cask --adopt "$cask" || warn "cask $cask adopt failed; leaving as-is"
    fi
  done
}

function start_fresh() {
  mkdir -p "$BACKUP_DIR"
  section "Backups"
  info "$(_short "$BACKUP_DIR")"
}

function make_symlink() {
  local source="$1"
  local target="$2"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    ok "$(_short "$target") (linked)"
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    warn "backed up $(_short "$target")"
    mv "$target" "$BACKUP_DIR/"
  fi
  act "link $(_short "$target") → $(_short "$source")"
  ln -s "$source" "$target"
}

function copy_essentials() {
  section "Essentials (dotfile symlinks)"
  for file in essentials/*; do
    local source="$SCRIPT_DIR/$file"
    local target="$HOME/.$(basename "$file")"
    make_symlink "$source" "$target"
    if [[ "$file" == *.sh ]]; then
      chmod +x "$source"
    fi
  done
}

function install_vim_plugins() {
  section "Vim"
  if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
    act "installing Vundle + plugins"
    git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
    vim +PluginInstall +qall
  else
    ok "Vundle (installed)"
  fi
}

function default_shell() {
  section "Default shell"
  if [ $SHELL != '/bin/zsh' ]; then
    act "switching default shell to zsh"
    chsh -s $(which zsh)
  else
    ok "zsh (default)"
  fi
}

function zshenv_stuff() {
  section "zshenv"
  # ~/.zshenv is loaded for every zsh invocation, including non-interactive
  # shells (scripts, Claude Code's Bash, etc.). Sourcing ~/.env here means
  # fnm, PNPM_HOME, BUN_INSTALL, etc. are available everywhere without
  # relying on ~/.zshrc being read.
  touch ~/.zshenv
  local env_line='[ -f "$HOME/.env" ] && source "$HOME/.env"'

  if ! grep -qF -- "$env_line" ~/.zshenv; then
    act "adding .env source line to ~/.zshenv"
    echo "$env_line" >> ~/.zshenv
  else
    ok "~/.zshenv sources ~/.env"
  fi
}

function zshrc_stuff() {
  section "zsh"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    act "installing oh-my-zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" || true
  else
    ok "oh-my-zsh (installed)"
  fi

  touch ~/.zshrc
  local startup_line="if [ -f $HOME/.startup ]; then; source $HOME/.startup; fi"
  local secret_line="if [ -f $HOME/.secret ]; then; source $HOME/.secret; fi"

  if ! grep -qF -- "$startup_line" ~/.zshrc; then
    act "adding .startup source line to ~/.zshrc"
    echo "$startup_line" >> ~/.zshrc
  else
    ok "~/.zshrc sources ~/.startup"
  fi
  if ! grep -qF -- "$secret_line" ~/.zshrc; then
    act "adding .secret source line to ~/.zshrc"
    echo "$secret_line" >> ~/.zshrc
  else
    ok "~/.zshrc sources ~/.secret"
  fi
}

# Copy sample gitconfig as a starting point. If one already exists and differs
# from the sample, prompt before overwriting (and back up the original).
function gitconfig_stuff() {
  section "gitconfig"
  local source="$SCRIPT_DIR/gitconfig.sample"
  local target="$HOME/.gitconfig"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    act "seeding ~/.gitconfig from sample"
    cp "$source" "$target"
    return
  fi

  if cmp -s "$source" "$target"; then
    ok "~/.gitconfig (matches sample)"
    return
  fi

  warn "~/.gitconfig differs from sample:"
  diff -u "$target" "$source" || true
  read -r -p "    Overwrite ~/.gitconfig with the sample? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS])
      act "backing up existing ~/.gitconfig"
      mv "$target" "$BACKUP_DIR/"
      cp "$source" "$target"
      ;;
    *)
      ok "~/.gitconfig (left alone)"
      ;;
  esac
}

function terminal_theme() {
  section "Terminal theme"
  if [ -d ~/tmp/monokai.terminal ]; then
    ok "monokai.terminal (cloned)"
    return
  fi
  act "installing monokai.terminal theme"
  mkdir -p ~/tmp && git clone git@github.com:stephenway/monokai.terminal.git ~/tmp/monokai.terminal
  open ~/tmp/monokai.terminal/Monokai.terminal
  info "Open Terminal settings and set Monokai.terminal as the default in Profiles"
}

function starship_stuff() {
  section "Starship"
  mkdir -p "$HOME/.config"
  make_symlink "$SCRIPT_DIR/helpful/starship.toml" "$HOME/.config/starship.toml"
}

function claude_stuff() {
  section "Claude / Agents"
  mkdir -p "$HOME/.claude"
  mkdir -p "$HOME/.claude/commands"
  mkdir -p "$HOME/.agents"
  mkdir -p "$HOME/.agents/skills"
  make_symlink "$SCRIPT_DIR/helpful/claude-settings.json" "$HOME/.claude/settings.json"
  make_symlink "$SCRIPT_DIR/helpful/AGENTS.md" "$HOME/AGENTS.md"
  make_symlink "$SCRIPT_DIR/helpful/AGENTS.md" "$HOME/.agents/AGENTS.md"
  make_symlink "$SCRIPT_DIR/helpful/AGENTS.md" "$HOME/.claude/CLAUDE.md"

  # TODO: this isn't quite right, because commands and skills are different things
  for file in "$SCRIPT_DIR"/agents/commands/*; do
    [ -e "$file" ] || continue
    make_symlink "$file" "$HOME/.agents/skills/$(basename "$file")"
    make_symlink "$file" "$HOME/.claude/commands/$(basename "$file")"
  done
}

function ghostty_stuff() {
  section "Ghostty"
  local dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
  mkdir -p "$dir"
  make_symlink "$SCRIPT_DIR/helpful/ghostty-config" "$dir/config"
}

# macOS system preferences captured from this machine via `defaults read`.
# Only values that differ from Apple's ship defaults are written here.
# Skipped on non-Darwin hosts.
function macos_defaults() {
  section "macOS defaults"
  if [ "$(uname)" != "Darwin" ]; then
    info "not macOS; skipping"
    return
  fi

  read -r -p "    Apply macOS system preferences? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) ok "skipped"; return ;;
  esac

  # Close System Settings so it doesn't overwrite values on quit
  osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

  # --- Global (NSGlobalDomain) ---
  # Auto-switch light/dark appearance with sunrise/sunset
  defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true
  # Fast key repeat (15 = delay before repeat, 2 = repeat rate; lower is faster)
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain KeyRepeat -int 2

  # --- Dock ---
  defaults write com.apple.dock tilesize -int 72
  defaults write com.apple.dock show-recents -bool false
  # Hot corner: bottom-right -> Quick Note (14). 1 = disabled.
  defaults write com.apple.dock wvous-br-corner -int 14
  defaults write com.apple.dock wvous-br-modifier -int 0

  # --- Finder ---
  # Default view: columns (clmv). Alternatives: icnv, Nlsv, glyv.
  defaults write com.apple.finder FXPreferredViewStyle -string "clmv"
  # New Finder windows open to the Desktop (PfDe). PfHm = home, PfLo = recents.
  defaults write com.apple.finder NewWindowTarget -string "PfDe"

  # --- Screenshots ---
  defaults write com.apple.screencapture disable-sound -bool true

  # --- Menu bar clock ---
  # Hide the date (day-of-week + time only)
  defaults write com.apple.menuextra.clock ShowDate -int 0
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
  defaults write com.apple.menuextra.clock ShowAMPM -bool true

  # --- Trackpad (built-in + Bluetooth) ---
  for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
    defaults write "$domain" Clicking -bool true
    defaults write "$domain" TrackpadRightClick -bool true
    defaults write "$domain" TrackpadThreeFingerDrag -bool true
    # Disable three-finger tap (look up); two-finger double-tap handles lookup
    defaults write "$domain" TrackpadThreeFingerTapGesture -int 0
    defaults write "$domain" TrackpadTwoFingerDoubleTapGesture -bool true
  done
  # Enable tap-to-click at the login screen and for new users
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  # Force Touch
  defaults write NSGlobalDomain com.apple.trackpad.forceClick -bool true

  act "restarting Dock, Finder, SystemUIServer"
  for app in Dock Finder SystemUIServer; do
    killall "$app" 2>/dev/null || true
  done
  info "some changes require a logout/restart to fully apply"
}

install_deps
start_fresh
copy_essentials
starship_stuff
claude_stuff
ghostty_stuff
install_vim_plugins
default_shell
zshenv_stuff
zshrc_stuff
gitconfig_stuff
terminal_theme
macos_defaults

section "Done — manual follow-ups"
info "Setup SSH Keys:    https://help.github.com/articles/adding-a-new-ssh-key-to-the-ssh-agent"
info "Optional installs: pnpm (npm i -g pnpm), bun (curl -fsSL https://bun.sh/install | bash)"
info "Default terminal:  open Ghostty → Ghostty menu → Services → Make Ghostty the default terminal"
