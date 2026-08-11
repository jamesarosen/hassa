#!/bin/sh

cat <<'EOF'

chezmoi: machine-specific settings live in local override files (not tracked):
  ~/.gitconfig.local   git user.email / user.signingkey for this machine
  ~/.zshenv.local      extra $PATH, functions, work-only settings

Node / pnpm:
  - Node comes from nvm (loaded in tracked ~/.zshenv) so agents and other
    non-interactive shells see `node` without ~/.zshrc.
  - Default Node major is pinned by run_onchange_after_install-nvm-node.sh (≥24).
  - pnpm requires Node on PATH; install Node before relying on pnpm.
  - Volta is unmaintained (https://github.com/volta-cli/volta). It is only
    added to PATH when ~/.volta/bin/volta exists (opt-in). Prefer nvm.

Apply must succeed end-to-end:
  - Secrets in ~/.zshenv come from 1Password (`op`). If apply fails mid-way
    (missing OP_ACCOUNT, not signed in, etc.), the applied ~/.zshenv can drift
    from source — e.g. losing the `source ~/.zshenv.local` line — and agents
    will not see machine-local PATH/nvm overrides.
  - Fix with: eval $(op signin)  # or set OP_ACCOUNT, then: chezmoi apply

Stubs were created only where the file was missing — edit them as needed.
EOF
