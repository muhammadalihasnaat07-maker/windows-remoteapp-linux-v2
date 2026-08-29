# 3. Install Docker

Install Docker Engine and Docker Compose v2 using either:

```bash
./scripts/install-dependencies.sh
```

or your distribution-specific instructions in `distro/`.

If your distribution requires it, enable Docker:

```bash
sudo systemctl enable --now docker
```

The WinApps runtime requires Docker to work as the current Linux user.

Verify:

```bash
docker --version
docker compose version
docker ps
```

If `docker ps` reports a permission error, fix Docker user access for your distribution and log out/in before continuing.

The production WinApps launchers do not use privilege escalation for routine container startup or shutdown.
