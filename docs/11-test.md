# 11. Test the setup

Start with the Notepad broker test:

```bash
./scripts/test-notepad.sh
```

Verify:

- keyboard input;
- window resizing;
- minimize and restore;
- maximize and restore;
- Linux-to-Windows clipboard;
- Windows-to-Linux clipboard.

Next launch two detected applications from the Linux application menu, for example Word and Excel.

Expected lifecycle:

1. Word opens.
2. Excel opens without logging Word off.
3. Both applications remain usable simultaneously.
4. Closing Word leaves Excel running.
5. Closing Excel as the final managed application ends the broker session.
6. The `WinApps` container stops automatically.

Check container state with:

```bash
docker ps -a --filter name=WinApps --format 'table {{.Names}}\t{{.Status}}'
```

After automatic shutdown, `Exited (143)` is expected because the supervisor performs a normal Docker stop operation.

While applications are open, inspect broker state with:

```bash
./scripts/diagnose-winapps.sh
```

There should normally be one persistent broker FreeRDP connection rather than one independent FreeRDP connection per application.
