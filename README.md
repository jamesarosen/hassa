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
and authenticated (`op signin` / `OP_ACCOUNT`). **`chezmoi apply` must succeed
end-to-end** — a failed secret lookup can leave `~/.zshenv` partially applied
(e.g. missing the `source ~/.zshenv.local` line), which breaks Node/PATH for
non-interactive shells and agents.

## What's managed

- Shell configuration (zsh), including **nvm** in `~/.zshenv` so non-interactive
  shells get `node` (do not move nvm to `~/.zshrc` only)
- Default Node major ≥24 via `run_onchange_after_install-nvm-node.sh`
- Git configuration
- Personal scripts (`~/bin`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) settings, hooks,
  skills, and agent definitions

### Node, pnpm, and Volta

- **nvm** is the supported Node installer. Volta is [unmaintained](https://github.com/volta-cli/volta);
  it is only added to `PATH` when `~/.volta/bin/volta` exists (opt-in).
- **pnpm** is configured in `~/.zshenv` and requires Node on `PATH`.
- Machine-specific extras (Colony libpq/pyenv, Node 22 for work repos, etc.)
  belong in `~/.zshenv.local` — see the stub comments in
  `create_private_dot_zshenv.local`.

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
