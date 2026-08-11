#!/usr/bin/env bash
# Install nvm (if missing) and pin the default Node major.
# Bump NODE_MAJOR below to re-run on the next `chezmoi apply`.
set -euo pipefail

NODE_MAJOR=24
NVM_VERSION=v0.40.6
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "chezmoi: installing nvm ${NVM_VERSION}"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

if ! nvm ls "${NODE_MAJOR}" >/dev/null 2>&1; then
  echo "chezmoi: installing Node ${NODE_MAJOR}"
  nvm install "${NODE_MAJOR}"
fi

echo "chezmoi: setting nvm default alias to ${NODE_MAJOR}"
nvm alias default "${NODE_MAJOR}"

node --version
which node
