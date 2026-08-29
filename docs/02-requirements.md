# 2. Requirements

- 64-bit Linux system
- Hardware virtualization enabled in firmware
- `/dev/kvm` available
- `/dev/net/tun` available
- Docker Engine
- Docker Compose v2
- Docker usable by the current Linux user
- FreeRDP 3.26 or newer
- X11/Xorg desktop session
- At least 4 GiB RAM assignable to the Windows VM
- At least 40 GiB free disk space for the default Windows disk

The default v2 Windows allocation is 6 GiB RAM, 4 CPU cores, and a 40 GiB virtual disk.

Check virtualization and device access:

```bash
ls -l /dev/kvm
ls -l /dev/net/tun
lscpu | grep -i virtualization
```

Check Docker access as the current user:

```bash
docker ps
docker compose version
```

Check FreeRDP:

```bash
xfreerdp3 /version
```

Check the desktop session:

```bash
echo "$XDG_SESSION_TYPE"
```

The supported RemoteApp path currently expects `x11`.
