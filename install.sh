#!/usr/bin/env bash

set -e

BACKUP_DIR="$HOME/dotfiles-bak"

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
  rm -rf $BACKUP_DIR
  mkdir -p $BACKUP_DIR
}

function make_symlink() {
  local source="$1"
  local target="$2"

  if [ -f $target ] || [ -L $target ] ; then
    echo "Backing up existing $target"
    mv $target $BACKUP_DIR
  fi
  echo "Symlinking $source to $HOME"
  ln -s $source $target
}

function copy_essentials() {
  for file in essentials/*; do
    SOURCE="$PWD/$file"
    TARGET="$HOME/.$(basename $file)"
    make_symlink $SOURCE $TARGET
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
  echo "Install oh-my-zsh"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" || true
  echo "Add startup scripts to zsh"
  echo "if [ -f $HOME/.startup ]; then; source $HOME/.startup; fi" >> ~/.zshrc
  echo "if [ -f $HOME/.secret ]; then; source $HOME/.secret; fi" >> ~/.zshrc
}

# Copy sample gitconfig
function gitconfig_stuff() {
  local source="$PWD/gitconfig.sample"
  local target="$HOME/.gitconfig"

  if [ -f "$target" ] || [ -L "$target" ]; then
    mv "$target" "$BACKUP_DIR"
  fi

  cp "$source" "$target"
}

function terminal_theme() {
  echo "Installing monokai.terminal theme"
  rm -rf ~/tmp/monokai.terminal || true
  mkdir -p ~/tmp && git clone git@github.com:stephenway/monokai.terminal.git ~/tmp/monokai.terminal
  open ~/tmp/monokai.terminal/Monokai.terminal
  echo "Open Terminal settings and set Monokai.terminal as the default in Profiles"
}

function starship_stuff() {
  mkdir -p "$HOME/.config"
  if [ -f "$HOME/.config/starship.toml" ] || [ -L "$HOME/.config/starship.toml" ]; then
    echo "Backing up existing starship.toml"
    mv "$HOME/.config/starship.toml" "$BACKUP_DIR"
  fi
  echo "Symlinking starship.toml to ~/.config"
  ln -s "$PWD/helpful/starship.toml" "$HOME/.config/starship.toml"
}

function claude_stuff() {
  mkdir -p "$HOME/.claude"
  if [ -f "$HOME/.claude/settings.json" ] || [ -L "$HOME/.claude/settings.json" ]; then
    echo "Backing up existing claude settings.json"
    mv "$HOME/.claude/settings.json" "$BACKUP_DIR/claude-settings.json"
  fi
  make_symlink "$PWD/helpful/claude-settings.json" "$HOME/.claude/settings.json"
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
