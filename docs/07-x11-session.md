# 7. Use an X11 session

Check the current session:

```bash
echo "$XDG_SESSION_TYPE"
```

Expected:

```text
x11
```

If it returns `wayland`, log out and select an Xorg/X11 session from the login screen. FreeRDP RemoteApp windows may render under XWayland but fail to accept keyboard or mouse input.
