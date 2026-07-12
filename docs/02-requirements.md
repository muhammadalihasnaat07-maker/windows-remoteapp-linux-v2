# 2. Requirements

- 64-bit Linux system
- Hardware virtualization enabled in firmware
- `/dev/kvm` available
- Docker Engine with Compose v2
- FreeRDP 3.26 or newer
- X11/Xorg desktop session
- At least 8 GB host RAM recommended
- At least 80 GB free disk space recommended

Check virtualization:

```bash
ls -l /dev/kvm
lscpu | grep -i virtualization
```
