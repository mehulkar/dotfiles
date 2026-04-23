# dotfiles

## Usage

```bash
git clone git@github.com:mehulkar/dotfiles.git && cd dotfiles
./setup.sh
```

## Notes

1. Vim uses [Vundle][1]. `./setup.sh` will install it and all plugins.
1. `./setup.sh` adds env vars and aliases to `~/.zshrc` by default.
1. shell aliases assume `~/dev` exist. Shortcuts to main dev dirs and a tmp dir for throwaway stuff
1. `touch essentials/.secret` for aliases/env variables you want to put in your shell profile that shouldn't be in source control.

[1]: https://github.com/gmarik/Vundle.vim.git
