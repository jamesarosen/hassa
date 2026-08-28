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

Apply / source notes:
  - `chezmoi apply` reads ~/.local/share/chezmoi (its own clone), not an
    arbitrary workspace checkout — push/pull or sync before expecting new
    commits to apply.
  - Keep secrets (e.g. PIHOLE_PASSWORD) in ~/.zshenv.local, not tracked
    ~/.zshenv, so a failed `op` lookup cannot block Node/PATH from applying.
  - Fix op with: eval $(op signin)  # or set OP_ACCOUNT, then: chezmoi apply

Stubs were created only where the file was missing — edit them as needed.
EOF
