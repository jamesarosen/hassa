#!/bin/sh

cat <<'EOF'

chezmoi: machine-specific settings live in local override files (not tracked):
  ~/.gitconfig.local   git user.email / user.signingkey for this machine
  ~/.zshenv.local      extra $PATH, functions, work-only settings

Stubs were created only where the file was missing — edit them as needed.
EOF
