# Windows RemoteApp on Linux

Run Microsoft Office and other Windows applications as individual native-looking Linux desktop windows using a Dockerized Windows 11 VM, FreeRDP 3 RemoteApp, and desktop shortcuts.

> **Community guide.** Not affiliated with Microsoft, FreeRDP, Dockur, Docker, or WinApps.

---

## How it works

```
Linux desktop
  └── .desktop shortcut / CLI
        └── winapp-launcher (Bash)
              ├── starts Windows container (if not running)
              ├── waits for RDP + cold-boot delay
              ├── launches FreeRDP RemoteApp window
              └── stops container when all apps close
```

Each Windows application appears as a separate Linux window. You can have Word, Excel, and PowerPoint open at the same time. When you close the last one, the container stops automatically.

---

## What is included

| Path | Purpose |
|---|---|
| `examples/compose.yml` | Docker Compose file for the Windows container |
| `examples/.env.example` | Environment variable template |
| `examples/credentials.example` | Launcher credential template |
| `oem/RDPApps.reg` | Registry policy that enables unlisted RemoteApps |
| `oem/install.bat` | Applies the registry policy automatically after Windows installs |
| `scripts/winapp-launcher.sh` | Main launcher — start, wait, connect, stop |
| `scripts/install-launcher.sh` | Installs the launcher to `~/.local/bin` |
| `scripts/create-shortcuts.sh` | Creates `.desktop` shortcuts for Office apps |
| `scripts/diagnose-winapps.sh` | Diagnostic helper for troubleshooting |
| `docs/` | Step-by-step setup guide |
| `distro/` | Distribution-specific package install commands |

---

## Important compatibility notes

- **FreeRDP 3.26 or newer** is required. Earlier versions have RAIL rendering bugs.
- **Use an X11/Xorg desktop session.** RemoteApp windows may appear under Wayland/XWayland but keyboard and mouse input will not work correctly. Log out and select an Xorg session from your login screen.
- **Do not keep a full RDP desktop session open** while using RemoteApps. A competing session causes connection failures.
- **Do not use `exec xfreerdp3`** in the launcher. It prevents the shell cleanup trap from running, which breaks automatic container shutdown.
- **TCP port 3389 becomes reachable before Windows logon services are fully ready.** The launcher applies a configurable cold-boot delay after the port opens.

---

## Requirements

- 64-bit Linux with hardware virtualization enabled in firmware
- `/dev/kvm` accessible
- Docker Engine with Compose v2 (or Podman with compatible setup)
- FreeRDP 3.26+
- X11/Xorg desktop session
- 8 GB+ host RAM recommended
- 80 GB+ free disk space recommended

---

## Install packages by distribution

### Debian / Ubuntu / Parrot OS / Kali Linux

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin freerdp3-x11 curl git util-linux
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

> If `freerdp3-x11` is not available or the version is below 3.26, try backports:
> ```bash
> # Replace <suite>-backports with your actual backports suite name
> sudo apt install -t <suite>-backports freerdp3-x11
> ```

---

### Fedora

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin freerdp git util-linux
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

---

### RHEL / AlmaLinux / Rocky Linux

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin freerdp git util-linux
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

---

### Arch Linux / Manjaro

```bash
sudo pacman -Syu --noconfirm docker docker-compose freerdp git util-linux
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

---

### openSUSE Tumbleweed

```bash
sudo zypper install -y docker docker-compose freerdp git util-linux
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

---

### openSUSE Leap

```bash
sudo zypper addrepo https://download.docker.com/linux/suse/docker-ce.repo
sudo zypper install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin freerdp git util-linux
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

---

### Verify after install (all distros)

```bash
xfreerdp3 /version         # must show 3.26.0 or newer
sudo docker compose version
ls -l /dev/kvm
echo "$XDG_SESSION_TYPE"   # must show: x11
```

---

## Quick setup

```bash
# 1. Clone this repository
git clone https://github.com/muhammadalihasnaat07-maker/windows-remoteapp-linux.git
cd windows-remoteapp-linux

# 2. Create your working directory
mkdir -p "$HOME/WinApps/oem"
cp examples/compose.yml "$HOME/WinApps/"
cp examples/.env.example "$HOME/WinApps/.env"
cp oem/* "$HOME/WinApps/oem/"
chmod 600 "$HOME/WinApps/.env"

# 3. Set your Windows credentials in the .env file
nano "$HOME/WinApps/.env"

# 4. Start the Windows container
cd "$HOME/WinApps"
sudo docker compose up -d

# 5. Open the web console and complete Windows setup
xdg-open http://127.0.0.1:8006
# (or open manually in your browser)

# 6. Install the launcher
cd /path/to/windows-remoteapp-linux
./scripts/install-launcher.sh

# 7. Set your RDP credentials for the launcher
nano "$HOME/.config/winapps/credentials"
chmod 600 "$HOME/.config/winapps/credentials"

# 8. Configure passwordless sudo for Docker (required for desktop shortcuts)
sudo visudo -f /etc/sudoers.d/winapps-container
# Add (replace YOUR_LINUX_USER with your actual username):
# YOUR_LINUX_USER ALL=(root) NOPASSWD: /usr/bin/docker compose up -d, /usr/bin/docker stop WinApps

# 9. Create desktop shortcuts
./scripts/create-shortcuts.sh

# 10. Test with Notepad
"$HOME/.local/bin/winapp-launcher" 'notepad.exe'
```

---

## Environment variables (.env)

| Variable | Default | Description |
|---|---|---|
| `WINDOWS_VERSION` | `11` | Windows version (see dockur/windows docs) |
| `WINDOWS_RAM` | `4G` | RAM allocated to the VM |
| `WINDOWS_CPUS` | `4` | CPU cores allocated to the VM |
| `WINDOWS_DISK` | `64G` | Primary virtual disk size |
| `WINDOWS_USERNAME` | `MyWindowsUser` | Windows account username |
| `WINDOWS_PASSWORD` | `ChangeThisPassword` | Windows account password |

Copy `examples/.env.example` to your compose directory as `.env` and edit before first launch.

---

## Launcher environment variables

| Variable | Default | Description |
|---|---|---|
| `WINAPPS_COMPOSE_DIR` | `$HOME/WinApps` | Directory containing `compose.yml` |
| `WINAPPS_SHARE_DIR` | `$HOME` | Linux directory shared with Windows |
| `WINAPPS_CREDENTIALS_FILE` | `$HOME/.config/winapps/credentials` | File containing `RDP_USER` and `RDP_PASS` |
| `WINAPPS_CONTAINER_NAME` | `WinApps` | Container name matching `compose.yml` |
| `WINAPPS_RDP_HOST` | `127.0.0.1` | RDP host |
| `WINAPPS_RDP_PORT` | `3389` | RDP port |
| `WINAPPS_COLD_BOOT_DELAY` | `45` | Seconds to wait after port opens on cold boot |
| `WINAPPS_STOP_GRACE_SECONDS` | `5` | Seconds before stopping container after last app closes |
| `DOCKER_BIN` | `/usr/bin/docker` | Path to Docker binary |

---

## Launching apps manually

```bash
# Notepad
"$HOME/.local/bin/winapp-launcher" 'notepad.exe'

# Microsoft Word
"$HOME/.local/bin/winapp-launcher" 'C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE'

# Microsoft Excel
"$HOME/.local/bin/winapp-launcher" 'C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE'

# Microsoft PowerPoint
"$HOME/.local/bin/winapp-launcher" 'C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE'
```

---

## Security

- RDP is bound to `127.0.0.1` by default. Never expose port 3389 to the internet.
- Never commit `.env` or `credentials` files. Both are excluded by `.gitignore`.
- Store credentials with mode `600`.
- The `/p:` argument exposes the password in the Linux process list. See `docs/13-security.md` for mitigation options.
- Limit sudoers permissions to exactly the two Docker commands required.

---

## Troubleshooting

See [docs/12-troubleshooting.md](docs/12-troubleshooting.md) for full details.

Run the diagnostic helper:

```bash
./scripts/diagnose-winapps.sh
```

Common issues:

| Symptom | Cause | Fix |
|---|---|---|
| Window appears but no keyboard/mouse input | Wayland session | Log into X11/Xorg session |
| `BadMatch` / `X_CopyArea` errors | Old FreeRDP version | Upgrade to FreeRDP 3.26+ |
| `LOGON_MSG_BUMP_OPTIONS` | Competing RDP session | Run `query session` and `logoff` in Windows |
| Connection reset on first launch | Port opens before login services ready | Increase `WINAPPS_COLD_BOOT_DELAY` |
| Container does not stop after last app | `exec` prefix on `xfreerdp3` | Remove `exec` from launcher |

---

## Tested with

- FreeRDP 3.26.0
- Windows 11
- Microsoft Office (Word, Excel, PowerPoint)
- Notepad
- Parrot OS (Debian-based)
- X11/Xorg desktop session

---

## Docs

1. [Architecture overview](docs/01-overview.md)
2. [Requirements](docs/02-requirements.md)
3. [Install Docker](docs/03-install-docker.md)
4. [Create Windows container](docs/04-create-windows-container.md)
5. [Configure Windows RemoteApp](docs/05-configure-windows.md)
6. [Install FreeRDP](docs/06-install-freerdp.md)
7. [Use an X11 session](docs/07-x11-session.md)
8. [Install launcher](docs/08-install-launcher.md)
9. [Configure sudoers](docs/09-sudoers.md)
10. [Create desktop shortcuts](docs/10-create-shortcuts.md)
11. [Test the setup](docs/11-test.md)
12. [Troubleshooting](docs/12-troubleshooting.md)
13. [Security notes](docs/13-security.md)
14. [Uninstall](docs/14-uninstall.md)

---

## License

MIT — see [LICENSE](LICENSE).
