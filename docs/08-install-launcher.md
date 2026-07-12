# 8. Install the launcher

```bash
cd /path/to/repository
./scripts/install-launcher.sh
nano "$HOME/.config/winapps/credentials"
chmod 600 "$HOME/.config/winapps/credentials"
```

If your Compose directory is not `$HOME/WinApps`, export:

```bash
export WINAPPS_COMPOSE_DIR="$HOME/path/to/compose-directory"
```

For permanent configuration, add variables to your shell profile or create a small wrapper script.
