# 5. Configure Windows RemoteApp

Windows-side provisioning is performed automatically from the `oem/` directory.

The OEM entry point is:

```text
oem/install.bat
```

It runs:

```text
oem/configure-winapps.ps1
```

The provisioning script applies the Remote Desktop and RemoteApp registry configuration from `oem/RDPApps.reg`.

Important settings include:

- enabling Remote Desktop;
- requiring Network Level Authentication;
- allowing unlisted RemoteApp programs;
- disabling Windows automatic console logon to avoid a competing session;
- starting Remote Desktop Services;
- preparing Windows for the persistent RemoteApp broker.

The broker implementation is:

```text
oem/winapps-broker.ps1
```

The RemoteApp broker receives application requests from the redirected FreeRDP drive and launches the requested Windows processes.

If OEM provisioning must be inspected manually, use the local Windows console:

```text
http://127.0.0.1:8006
```

Avoid session conflicts:

- do not leave an unnecessary full desktop RDP session active while testing RemoteApps;
- log off stale competing RDP sessions;
- keep automatic console logon disabled.

Useful Windows commands:

```cmd
query session
logoff SESSION_ID
```
