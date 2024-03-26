#!/usr/bin/env bash

set -e

BACKUPDIR="$HOME/dotfiles-bak"
rm -rf $BACKUPDIR
mkdir -p $BACKUPDIR

for file in essentials/*; do
  SOURCE="$PWD/$file"
  TARGET="$HOME/.$(basename $file)"
  if [ -f $TARGET ] || [ -L $TARGET ] ; then
    echo "Backing up existing $TARGET"
    mv $TARGET $BACKUPDIR
  fi
  echo "Symlinking $SOURCE to $HOME"
  ln -s $SOURCE $TARGET
done

if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
  echo "Installing VIM plugins with vundle"
  git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  vim +PluginInstall +qall
else
  echo "Skipping VIM plugins"
fi

if [ $SHELL != '/bin/zsh' ]; then
  echo "Make zsh the default shell"
  chsh -s $(which zsh)
else
  echo "zsh is already the default shell"
fi

echo "Install oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" || true

echo "Add startup scripts to zsh"
echo "if [ -f $HOME/.startup ]; then; source $HOME/.startup; fi" >> ~/.zshrc
echo "if [ -f $HOME/.secret ]; then; source $HOME/.secret; fi" >> ~/.zshrc

# Copy sample gitconfig
GITSOURCE="$PWD/gitconfig.sample"
GITTARGET="$HOME/.gitconfig"

if [ -f $GITTARGET ] || [ -L $GITTARGET]; then
  mv $GITTARGET $BACKUPDIR
fi

cp $GITSOURCE $GITTARGET

echo "Installing monokai.terminal theme"
rm -rf ~/tmp/monokai.terminal || true
mkdir -p ~/tmp && git clone git@github.com:stephenway/monokai.terminal.git ~/tmp/monokai.terminal
open ~/tmp/monokai.terminal/Monokai.terminal
echo "Open Terminal settings and set Monokai.terminal as the default in Profiles"

echo "Other items:"
echo
echo "- Install HomeBrew: https://brew.sh"
echo "- Install Volta: https://docs.volta.sh/guide/getting-started"
echo "- Install VSCode: https://code.visualstudio.com/download"
echo "- Setup SSH Keys: https://help.github.com/articles/adding-a-new-ssh-key-to-the-ssh-agent"
