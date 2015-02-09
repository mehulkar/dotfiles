#!/usr/bin/env bash

set -x
set -e

BACKUPDIR="$HOME/dotfile-bak"
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

git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall

echo "source ~/.env" >> ~/.bash_profile
echo "source ~/.aliases" >> ~/.bash_profile
echo "if [ -f $HOME/.secret ]; then; source $HOME/.aliases; fi" >> ~/.bash_profile

# Copy sample gitconfig
GITSOURCE="$PWD/gitconfig.sample"
GITTARGET="$HOME/.gitconfig"

if [ -f $GITTARGET ] || [ -L $GITTARGET]; then
  mv $GITTARGET $BACKUPDIR
fi

cp $GITSOURCE $GITTARGET
