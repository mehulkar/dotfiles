## dotfiles

### Usage

```bash
git clone git@github.com:mehulkar/dotfiles.git && cd dotfiles
./install.sh
```

### Notes

1. Vim uses [vundle][1]. `./install.sh` will install it and all plugins.
1. `./install.sh` adds env vars and aliases  to `~/.bash_profile` by default. Change to `~/.zshrc` or whateve
1. shell aliases assume `~/dev` and `~/dev/scrap` directories exist. Shortcuts to main dev dirs and a tmp dir for throwaway stuff
1. `touch essentials/.secret` for aliases/env variables you want to put in your shell profile that you don't want to put in source control"


[1]: https://github.com/gmarik/Vundle.vim.git
