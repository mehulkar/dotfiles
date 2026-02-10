#!/usr/bin/env bash

set -e

BACKUP_DIR="$HOME/dotfiles-bak"

function start_fresh() {
  rm -rf $BACKUP_DIR
  mkdir -p $BACKUP_DIR
}

function dosymlink() {
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
    dosymlink $SOURCE $TARGET
  done
}

function copy_files() {
  copy_essentials
  dosymlink "$PWD/.claude/settings.json" "$HOME/$(basename helpful/claude.json)"
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

function zhrc_stuff() {
  echo "Install oh-my-zsh"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" || true
  echo "Add startup scripts to zsh"
  echo "if [ -f $HOME/.startup ]; then; source $HOME/.startup; fi" >> ~/.zshrc
  echo "if [ -f $HOME/.secret ]; then; source $HOME/.secret; fi" >> ~/.zshrc
}

# Copy sample gitconfig
function gitconfig_stuff() {
  GITSOURCE="$PWD/gitconfig.sample"
  GITTARGET="$HOME/.gitconfig"

  if [ -f $GITTARGET ] || [ -L $GITTARGET]; then
    mv $GITTARGET $BACKUPDIR
  fi

  cp $GITSOURCE $GITTARGET
}

function terminal_theme() {
  echo "Installing monokai.terminal theme"
  rm -rf ~/tmp/monokai.terminal || true
  mkdir -p ~/tmp && git clone git@github.com:stephenway/monokai.terminal.git ~/tmp/monokai.terminal
  open ~/tmp/monokai.terminal/Monokai.terminal
  echo "Open Terminal settings and set Monokai.terminal as the default in Profiles"
}

start_fresh
copy_files
install_vim_plugins
default_shell
zhrc_stuff
gitconfig_stuff
terminal_theme

echo "Other items:"
echo
echo "- Install HomeBrew: https://brew.sh"
echo "- Install VSCode: https://code.visualstudio.com/download"
echo "- Setup SSH Keys: https://help.github.com/articles/adding-a-new-ssh-key-to-the-ssh-agent"
