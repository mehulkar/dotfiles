#!/usr/bin/env bash

set -x
set -e

BACKUPDIR="$HOME/dotfiles-bak"
rm -rf $BACKUPDIR
mkdir -p $BACKUPDIR

for file in essentials/*; do
  SOURCE="$PWD/$file"
  TARGET="$HOME/.$(basename $file)"
  if [ -f $TARGET ] || [ -L $TARGET ] ; then
   mv $TARGET $BACKUPDIR
  fi
  ln -s $SOURCE $TARGET
done

if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
  git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  vim +PluginInstall +qall
fi

if [ $SHELL != '/bin/zsh' ]; then
  echo "Make zsh the default shell"
  chsh -s $(which zsh)
else
  echo "zsh is already the default shell"
fi

echo "Install oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

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
