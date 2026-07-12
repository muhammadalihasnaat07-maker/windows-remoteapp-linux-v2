# 6. Install FreeRDP

FreeRDP 3.26 or newer is recommended.

Verify:

```bash
xfreerdp3 /version
```

On Debian-family systems, a newer version may be available from backports:

```bash
sudo apt update
apt-cache policy freerdp3-x11 freerdp-x11
sudo apt install -t <your-backports-suite> freerdp-x11 freerdp3-x11
```

Do not copy the suite name blindly. Use the backports suite configured by your distribution.
