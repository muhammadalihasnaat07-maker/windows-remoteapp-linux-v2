# 8. Finalize the installation

The production launcher does not need to be copied into `~/.local/bin`.

After Windows installation is complete and the desired Windows applications are installed, run:

```bash
./setup.sh finalize
```

Finalization:

1. starts or reuses Windows;
2. waits for successful FreeRDP authentication;
3. detects supported installed applications;
4. writes `~/.config/winapps/apps.tsv`;
5. creates Linux desktop shortcuts and generated broker wrappers.

Production RemoteApp shortcuts use the persistent broker architecture.

If Windows applications are added later, run `./setup.sh finalize` again to refresh detection and shortcuts.
