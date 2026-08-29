# 9. Docker user access

The v2 runtime expects Docker commands to work as the current Linux user.

Verify:

```bash
docker ps
docker compose version
```

Desktop shortcuts cannot answer terminal privilege prompts, so Docker user permissions must be working before using RemoteApps.

On distributions that use the `docker` group, installation commonly adds the Linux account to that group.

A logout/login is normally required before new group membership becomes active.

Inspect current groups with:

```bash
id
```

The WinApps production launchers call Docker directly as the current user.
