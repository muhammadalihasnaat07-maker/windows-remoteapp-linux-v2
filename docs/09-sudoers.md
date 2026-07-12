# 9. Configure restricted sudo permissions

Desktop shortcuts cannot respond to terminal password prompts. Add narrowly scoped permissions.

Run:

```bash
sudo visudo -f /etc/sudoers.d/winapps-container
```

Add, replacing `YOUR_LINUX_USER`:

```text
YOUR_LINUX_USER ALL=(root) NOPASSWD: /usr/bin/docker compose up -d, /usr/bin/docker stop WinApps
```

Validate:

```bash
sudo chmod 440 /etc/sudoers.d/winapps-container
sudo visudo -cf /etc/sudoers.d/winapps-container
```

Test:

```bash
cd "$HOME/WinApps"
sudo -n /usr/bin/docker compose up -d
sudo -n /usr/bin/docker stop WinApps
```
