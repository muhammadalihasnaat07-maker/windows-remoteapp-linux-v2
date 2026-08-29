# 13. Security

- Keep RDP bound to `127.0.0.1`.
- Keep the web console bound to `127.0.0.1`.
- Do not expose TCP port `3389` directly to the internet.
- Keep credential files out of source control.
- Restrict `~/.config/winapps/credentials` to mode `600`.
- Use a strong Windows password.
- The launchers supply FreeRDP arguments through `/args-from:stdin`, keeping the runtime password out of the Linux process argument list.
- Preserve this stdin-based credential flow when modifying the launchers; do not move credentials into command-line arguments.
- Runtime Docker access is expected to work as the current Linux user.
- Treat the `winapps_data` volume as sensitive persistent Windows data.
- Do not use broad Docker prune operations as part of normal maintenance or uninstall.
- Review logs before publishing them and remove usernames, personal paths, addresses, tokens, or credential material.

The `WinApps` container is disposable; the persistent Windows volume is not.

Permanent deletion of Windows data should happen only through an explicit destructive action such as:

```bash
./uninstall.sh --purge-data
```
