#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="$HOME/dotfiles-bak/$(date +%Y%m%d-%H%M%S)"

# Brew packages required by essentials (aliases, env, gitconfig, etc.)
BREW_DEPS="bat eza gh jq fzf highlight vim fnm starship"

function install_deps() {
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
  fi
  echo "Installing brew deps: $BREW_DEPS"
  brew install $BREW_DEPS
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

# Copy sample gitconfig as a starting point (skip if one already exists)
function gitconfig_stuff() {
  local source="$SCRIPT_DIR/gitconfig.sample"
  local target="$HOME/.gitconfig"

  if [ -f "$target" ] || [ -L "$target" ]; then
    echo "~/.gitconfig already exists; leaving it alone"
    return
  fi

  echo "Seeding ~/.gitconfig from sample"
  cp "$source" "$target"
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

install_deps
start_fresh
copy_essentials
starship_stuff
claude_stuff
install_vim_plugins
default_shell
zshrc_stuff
gitconfig_stuff
terminal_theme

echo "Other items:"
echo "- Install VSCode: https://code.visualstudio.com/download"
echo "- Setup SSH Keys: https://help.github.com/articles/adding-a-new-ssh-key-to-the-ssh-agent"
echo "- Optional: pnpm (npm i -g pnpm), bun (curl -fsSL https://bun.sh/install | bash)"
