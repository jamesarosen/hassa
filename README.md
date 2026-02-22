# hassa

Personal dotfiles and development environment, managed with
[chezmoi](https://www.chezmoi.io/).

## Setup on a new machine

```sh
# Install chezmoi and apply dotfiles in one step:
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply jamesarosen/hassa

# Or, if chezmoi is already installed:
chezmoi init --apply jamesarosen/hassa
```

Secrets are stored in 1Password and resolved at apply-time via the `op` CLI.
You'll need [1Password CLI](https://developer.1password.com/docs/cli/) installed
and authenticated.

## What's managed

- Shell configuration (zsh)
- Git configuration
- Personal scripts (`~/bin`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) settings, hooks,
  skills, and agent definitions

## Day-to-day usage

```sh
chezmoi add ~/.some/new/file    # start tracking a file
chezmoi edit ~/.zshrc           # edit in source dir, then apply
chezmoi diff                    # preview pending changes
chezmoi apply                   # apply source state to $HOME
chezmoi cd                      # cd into the source directory
```

After editing, commit and push from the source directory:

```sh
chezmoi cd
git add -A && git commit -m "description" && git push
```

## Whence the name?

_Hassa_ (ḫašša) is the Hittite word for "hearth" — the center of the ancient
Anatolian household. Hittite is one of the oldest attested Indo-European
languages, preserved in cuneiform tablets from the second millennium BCE.

Your dotfiles are the hearth of your digital home: the warmth and configuration
that make a machine _yours_.
