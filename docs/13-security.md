# 13. Security notes

- Keep RDP bound to `127.0.0.1` unless network exposure is explicitly required.
- Do not commit `.env` or credential files.
- Restrict credentials to mode `600`.
- Use a strong Windows password.
- Limit sudoers permissions to the exact Docker commands required.
- Review the launcher warning that `/p:` exposes the password in the process list.
- For higher security, adapt the launcher to use FreeRDP `/from-stdin` or an askpass provider.
