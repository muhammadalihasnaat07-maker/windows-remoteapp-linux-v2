# 3. Install Docker

Use your distribution's current official Docker installation method.

After installation:

```bash
sudo systemctl enable --now docker
sudo docker run --rm hello-world
sudo docker compose version
```

This guide uses `sudo docker` intentionally. Rootless Docker and Podman require different permissions and are not covered by the default launcher.
