# 14. Uninstall

Stop and remove the container:

```bash
cd "$HOME/WinApps"
sudo docker compose down
```

To remove the persistent Windows disk as well:

```bash
sudo docker compose down -v
```

Remove local files:

```bash
rm -f "$HOME/.local/bin/winapp-launcher"
rm -rf "$HOME/.config/winapps"
rm -f "$HOME/.local/share/applications/ms-word.desktop"
rm -f "$HOME/.local/share/applications/ms-excel.desktop"
rm -f "$HOME/.local/share/applications/ms-powerpoint.desktop"
rm -f "$HOME/.local/share/applications/windows-notepad.desktop"
```

Remove the sudo rule:

```bash
sudo rm -f /etc/sudoers.d/winapps-container
```
