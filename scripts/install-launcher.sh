#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p "$HOME/.local/bin" "$HOME/.config/winapps"
install -m 700 "$(dirname "$0")/winapp-launcher.sh" "$HOME/.local/bin/winapp-launcher"

if [[ ! -f "$HOME/.config/winapps/credentials" ]]; then
  install -m 600 "$(dirname "$0")/../examples/credentials.example" "$HOME/.config/winapps/credentials"
  echo "Edit $HOME/.config/winapps/credentials before launching an app."
fi

echo "Launcher installed at $HOME/.local/bin/winapp-launcher"
