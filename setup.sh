#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="$HOME/dotfiles-bak/$(date +%Y%m%d-%H%M%S)"

# Brew packages required by essentials (aliases, env, gitconfig, etc.)
BREW_DEPS="bat eza gh jq fzf highlight vim fnm starship"
CASK_DEPS="ghostty"

function install_deps() {
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
  fi
  echo "Installing brew deps: $BREW_DEPS"
  brew install $BREW_DEPS
  echo "Installing cask deps: $CASK_DEPS"
  brew install --cask $CASK_DEPS
}

function start_fresh() {
  mkdir -p "$BACKUP_DIR"
  echo "Backups will go to $BACKUP_DIR"
}

function make_symlink() {
  local source="$1"
  local target="$2"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "Backing up existing $target"
    mv "$target" "$BACKUP_DIR/"
  fi
  echo "Symlinking $source -> $target"
  ln -s "$source" "$target"
}

function copy_essentials() {
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
  if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
    echo "Installing VIM plugins with vundle"
    git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
    vim +PluginInstall +qall
  else
    echo "Skipping VIM plugins"
  fi
}

function default_shell() {
  if [ $SHELL != '/bin/zsh' ]; then
    echo "Make zsh the default shell"
    chsh -s $(which zsh)
  else
    echo "zsh is already the default shell"
  fi
}

function zshrc_stuff() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Install oh-my-zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" || true
  else
    echo "oh-my-zsh already installed"
  fi

  touch ~/.zshrc
  local startup_line="if [ -f $HOME/.startup ]; then; source $HOME/.startup; fi"
  local secret_line="if [ -f $HOME/.secret ]; then; source $HOME/.secret; fi"

  if ! grep -qF -- "$startup_line" ~/.zshrc; then
    echo "Adding .startup source line to ~/.zshrc"
    echo "$startup_line" >> ~/.zshrc
  fi
  if ! grep -qF -- "$secret_line" ~/.zshrc; then
    echo "Adding .secret source line to ~/.zshrc"
    echo "$secret_line" >> ~/.zshrc
  fi
}

# Copy sample gitconfig as a starting point. If one already exists and differs
# from the sample, prompt before overwriting (and back up the original).
function gitconfig_stuff() {
  local source="$SCRIPT_DIR/gitconfig.sample"
  local target="$HOME/.gitconfig"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    echo "Seeding ~/.gitconfig from sample"
    cp "$source" "$target"
    return
  fi

  if cmp -s "$source" "$target"; then
    echo "~/.gitconfig matches sample; leaving it alone"
    return
  fi

  echo "~/.gitconfig differs from $source:"
  diff -u "$target" "$source" || true
  read -r -p "Overwrite ~/.gitconfig with the sample? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS])
      echo "Backing up existing ~/.gitconfig"
      mv "$target" "$BACKUP_DIR/"
      cp "$source" "$target"
      ;;
    *)
      echo "Leaving ~/.gitconfig alone"
      ;;
  esac
}

function terminal_theme() {
  if [ -d ~/tmp/monokai.terminal ]; then
    echo "monokai.terminal already cloned; skipping"
    return
  fi
  echo "Installing monokai.terminal theme"
  mkdir -p ~/tmp && git clone git@github.com:stephenway/monokai.terminal.git ~/tmp/monokai.terminal
  open ~/tmp/monokai.terminal/Monokai.terminal
  echo "Open Terminal settings and set Monokai.terminal as the default in Profiles"
}

function starship_stuff() {
  mkdir -p "$HOME/.config"
  make_symlink "$SCRIPT_DIR/helpful/starship.toml" "$HOME/.config/starship.toml"
}

function claude_stuff() {
  mkdir -p "$HOME/.claude"
  make_symlink "$SCRIPT_DIR/helpful/claude-settings.json" "$HOME/.claude/settings.json"
}

function ghostty_stuff() {
  local dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
  mkdir -p "$dir"
  make_symlink "$SCRIPT_DIR/helpful/ghostty-config" "$dir/config"
}

# macOS system preferences captured from this machine via `defaults read`.
# Only values that differ from Apple's ship defaults are written here.
# Skipped on non-Darwin hosts.
function macos_defaults() {
  if [ "$(uname)" != "Darwin" ]; then
    echo "Not macOS; skipping defaults"
    return
  fi

  read -r -p "Apply macOS system preferences? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Skipping macOS defaults"; return ;;
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

  echo "Restarting affected services (Dock, Finder, SystemUIServer)…"
  for app in Dock Finder SystemUIServer; do
    killall "$app" 2>/dev/null || true
  done
  echo "Some changes require a logout/restart to fully apply."
}

install_deps
start_fresh
copy_essentials
starship_stuff
claude_stuff
ghostty_stuff
install_vim_plugins
default_shell
zshrc_stuff
gitconfig_stuff
terminal_theme
macos_defaults

echo "Other items:"
echo "- Install VSCode: https://code.visualstudio.com/download"
echo "- Setup SSH Keys: https://help.github.com/articles/adding-a-new-ssh-key-to-the-ssh-agent"
echo "- Optional: pnpm (npm i -g pnpm), bun (curl -fsSL https://bun.sh/install | bash)"
echo "- Set Ghostty as default terminal: open Ghostty, then Ghostty menu > Services > Make Ghostty the default terminal (macOS has no CLI for this)"
