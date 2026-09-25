# Windows RemoteApp on Linux

Run Microsoft Office and other Windows applications as individual Linux desktop windows using a Dockerized Windows 10/11 VM, FreeRDP 3 RemoteApp, and a persistent RemoteApp broker.

> **Community project.** Not affiliated with Microsoft, FreeRDP, Dockur, Docker, or WinApps.

---

## How it works

The production design uses a **single FreeRDP connection with a persistent broker**.

The first RemoteApp starts Windows and establishes the broker session. Additional applications reuse that same session instead of creating competing RDP sessions. When the final managed application closes, the broker exits and the Linux supervisor stops the Windows container automatically.

---

## Main components

| Path | Purpose |
|---|---|
| `setup.sh` | Main installation/configuration entry point |
| `compose.yml` | Canonical Dockur Windows Compose definition |
| `config/winapps.env.example` | Configuration template |
| `oem/install.bat` | Windows OEM provisioning entry point |
| `oem/configure-winapps.ps1` | Windows RemoteApp/RDP provisioning |
| `oem/RDPApps.reg` | Remote Desktop and RemoteApp registry policy |
| `oem/winapps-broker.ps1` | Persistent Windows application broker |
| `scripts/start-windows.sh` | Starts or reconstructs the Windows container |
| `scripts/wait-for-rdp.sh` | Authentication-based Windows readiness check |
| `scripts/broker-launcher.sh` | Production RemoteApp supervisor |
| `scripts/broker-request.sh` | Queues application requests for the broker |
| `scripts/detect-apps.sh` | Detects supported applications installed in Windows |
| `scripts/create-shortcuts.sh` | Creates Linux `.desktop` shortcuts |
| `scripts/windows-desktop.sh` | Opens a normal Windows RDP desktop |
| `scripts/diagnose-winapps.sh` | Read-only diagnostic helper |
| `scripts/test-notepad.sh` | Manual RemoteApp functionality test |
| `uninstall.sh` | Safe project uninstaller |
| `tests/` | Repository and lifecycle regression tests |

`scripts/winapp-launcher.sh` is retained as an internal one-shot transport used by application detection. It is not the production user-facing RemoteApp launcher.

---

## PRE-Requirments

- 64-bit Linux.
- Hardware virtualization enabled.
- `/dev/kvm` available.
- `/dev/net/tun` available.
- Docker Engine.
- Docker Compose v2.
- Docker usable by the current user.
- FreeRDP 3.26 or newer.
- X11/Xorg desktop session.
- At least 40 GiB free disk space for the default Windows disk.
- At least 4 GiB RAM assignable to Windows.

The current tested configuration uses FreeRDP 3 and X11. Wayland/XWayland is not currently considered a supported RemoteApp input path.

---

## Install dependencies/PRE-Requirments

The repository includes a dependency/PRE-Requirments installer for supported Debian-family systems:

```bash
./scripts/install-dependencies.sh
```

System package installation may require administrator privileges. Runtime WinApps Docker commands, however, are expected to work as the current user.

Verify:

```bash
docker --version
docker compose version
docker ps
xfreerdp3 /version
ls -l /dev/kvm
ls -l /dev/net/tun
echo "$XDG_SESSION_TYPE"
```

`docker ps` must work without an interactive privilege prompt.

For distribution-specific notes, see `distro/`.

---

## Preflight

Run:

```bash
./scripts/preflight.sh
```

Resolve any `FAIL` result before installation.

---

## Quick setup

Clone the repository:

```bash
git clone https://github.com/muhammadalihasnaat07-maker/windows-remoteapp-linux.git
cd windows-remoteapp-linux
```

### 1. Configure WinApps

```bash
./setup.sh configure
```

This creates the WinApps configuration, credentials, Compose configuration, and OEM provisioning files.

Default VM settings are:

| Variable | Default |
|---|---:|
| `WINDOWS_VERSION` | `10` |
| `WINDOWS_RAM` | `6G` |
| `WINDOWS_CPUS` | `4` |
| `WINDOWS_DISK` | `40G` |

Windows 10 and 11 are supported by the project configuration; Windows 10 is the current default.

Credentials are stored separately under:

```text
~/.config/winapps/credentials
```

The credentials file should remain mode `600`.

### 2. Install Windows

Run the Windows installation step:

```bash
./setup.sh install-windows
```

<!-- 👇 PASTE START: Right after the install-windows command in Step 2 👇 -->

#### Step 2 (Part 1): Fix Podman Socket Error (If Step 2 Fails)

> [!WARNING]
> **Only follow this step if `./setup.sh install-windows` fails because the Podman socket service isn't running.**

Since you are using rootless Podman (`uid 1000`), start and enable the socket service as your user:

```bash
systemctl --user enable --now podman.socket
```

Then verify that the service is running and the socket exists:

```bash
systemctl --user status podman.socket
ls -la /run/user/1000/podman/podman.sock
```

If the socket dies after logout or reboot, also enable linger:

```bash
sudo loginctl enable-linger $(whoami)
```

After that, re-run `./setup.sh install-windows` — the `docker-compose` (`podman-compose`) provider will now be able to connect to the socket.

<!-- 👆 PASTE END: Keep your existing completion note and Step 3 below 👆 -->

Complete Windows installation and install any desired Windows applications such as Microsoft Office before finalizing.

Finalize Linux integration

After Windows and the desired applications are installed:
For a non-destructive validation first:

```bash
./setup.sh install-windows --dry-run
```

The Windows installer/web console is available locally at:

```text
http://127.0.0.1:8006
```

### 4. Finalize Linux Integration

After Windows and your desired applications are installed:
```bash
./setup.sh finalize
```

`finalize`:

1. starts Windows if necessary;
2. verifies real FreeRDP authentication readiness;
3. detects supported Windows applications;
4. writes the application manifest;
5. creates Linux desktop shortcuts.

---

## Authentication readiness

TCP port `3389` becoming reachable does **not** mean Windows logon services are ready.

The startup path therefore performs an authentication readiness check with FreeRDP. Windows is considered ready only after FreeRDP authentication succeeds.

This avoids relying on a fixed cold-boot delay.

---

## Generated shortcuts

Depending on the detected Windows applications, `finalize` can create:

- Microsoft Word
- Microsoft Excel
- Microsoft PowerPoint
- Windows PowerShell
- Start Windows
- Windows Desktop

Desktop entries are created under:

```text
~/.local/share/applications/
```

Generated RemoteApp wrappers are stored under:

```text
~/.local/share/winapps/launchers/
```

---

## RemoteApp lifecycle

When the first application is opened:

1. `broker-launcher.sh` starts or reuses the `WinApps` container.
2. The launcher waits for successful Windows authentication.
3. One FreeRDP RemoteApp connection starts the Windows broker.
4. The requested application is queued through the redirected `winappsbroker` drive.

When another application is opened while the broker is active:

1. no second RDP session is created;
2. a new request file is queued;
3. the existing Windows broker launches the application.

When applications close:

- closing one application does not affect the others;
- after the final managed application closes, the broker exits;
- the Linux supervisor then stops the `WinApps` container.

An exited container status such as `Exited (143)` after normal automatic shutdown is expected because Docker stops the container using SIGTERM.

---

## Launch an application manually

For a production-path manual launch, call the broker launcher directly.

Notepad:

```bash
./scripts/broker-launcher.sh 'C:\Windows\System32\notepad.exe'
```

Word:

```bash
./scripts/broker-launcher.sh 'C:\Program Files\Microsoft Office\Root\Office16\WINWORD.EXE'
```

Excel:

```bash
./scripts/broker-launcher.sh 'C:\Program Files\Microsoft Office\Root\Office16\EXCEL.EXE'
```

PowerPoint:

```bash
./scripts/broker-launcher.sh 'C:\Program Files\Microsoft Office\Root\Office16\POWERPNT.EXE'
```

For a normal full Windows desktop:

```bash
./scripts/windows-desktop.sh
```

---

## Test the installation

Run the Notepad RemoteApp test:

```bash
./scripts/test-notepad.sh
```

Then test two applications together, for example Word and Excel.

Expected behavior:

1. both applications remain open simultaneously;
2. only one broker FreeRDP connection is used;
3. closing Word leaves Excel running;
4. closing the final application shuts down the broker;
5. the `WinApps` container then stops automatically.

Check container state with:

```bash
docker ps -a --filter name=WinApps --format 'table {{.Names}}\t{{.Status}}'
```

---

## Diagnostics

Run:

```bash
./scripts/diagnose-winapps.sh
```

The helper reports session type, FreeRDP version, Docker/container state, broker processes, broker PID files, configuration presence, and installed WinApps shortcuts.

It does not modify the installation.

---

## Security

- RDP is bound to `127.0.0.1` by default.
- The web console is bound to `127.0.0.1` by default.
- Do not expose RDP port `3389` directly to the internet.
- Do not commit `.env` or credential files.
- Keep `~/.config/winapps/credentials` at mode `600`.
- FreeRDP arguments are supplied through `/args-from:stdin`.
- The password therefore does not appear in the FreeRDP process argument list.
- Docker runtime access is performed as the current user.
- The persistent Windows volume is never automatically pruned.

See [SECURITY.md](SECURITY.md) and [docs/13-security.md](docs/13-security.md).

---

## Persistent Windows data

The Windows installation is stored in the Docker volume:

```text
winapps_data
```

The container itself is disposable.

If the container is missing while `winapps_data` still exists, `scripts/start-windows.sh` can reconstruct the container around the existing persistent Windows disk.

Do not manually delete `winapps_data` unless permanent Windows-data destruction is intended.

---

## Uninstall

Safe default uninstall:

```bash
./uninstall.sh
```

This removes the disposable container and generated Linux integration, but preserves:

- `winapps_data`;
- the host WinApps working/shared directory.

To permanently delete the Windows installation as well:

```bash
./uninstall.sh --purge-data
```

For explicitly confirmed non-interactive use:

```bash
./uninstall.sh --purge-data --yes
```

See [docs/14-uninstall.md](docs/14-uninstall.md).

---

## Troubleshooting

See [docs/12-troubleshooting.md](docs/12-troubleshooting.md).

Useful commands:

```bash
./scripts/diagnose-winapps.sh
./scripts/preflight.sh
docker ps -a --filter name=WinApps
```

Common issues:

| Symptom | Check |
|---|---|
| RemoteApp cannot receive input | Confirm `XDG_SESSION_TYPE=x11` |
| Windows starts but app does not appear | Run diagnostics and verify authentication readiness |
| A second application disrupts the first | Verify shortcuts target `broker-launcher.sh` |
| Container remains running after final app closes | Inspect broker PID state and FreeRDP process |
| Windows data appears missing | Verify the `winapps_data` volume still exists |

---

## Tested architecture

The rebuilt v2 workflow has been exercised with:

- Debian-family Linux / Parrot OS
- X11/Xorg
- Docker Engine
- Docker Compose v2
- FreeRDP 3
- Windows 10
- Microsoft Word
- Microsoft Excel
- Microsoft PowerPoint
- Windows PowerShell
- Notepad

The configuration also supports selecting Windows 11 through setup configuration.

---

## Documentation

1. [Architecture overview](docs/01-overview.md)
2. [Requirements](docs/02-requirements.md)
3. [Install Docker](docs/03-install-docker.md)
4. [Create/start Windows](docs/04-create-windows-container.md)
5. [Configure Windows RemoteApp](docs/05-configure-windows.md)
6. [Install FreeRDP](docs/06-install-freerdp.md)
7. [Use an X11 session](docs/07-x11-session.md)
8. [Finalize the installation](docs/08-install-launcher.md)
9. [Docker user access](docs/09-sudoers.md)
10. [Desktop shortcuts](docs/10-create-shortcuts.md)
11. [Test the setup](docs/11-test.md)
12. [Troubleshooting](docs/12-troubleshooting.md)
13. [Security notes](docs/13-security.md)
14. [Uninstall](docs/14-uninstall.md)

---

## License

See [LICENSE](LICENSE).
