# 5. Configure Windows RemoteApp

The OEM registry file enables unlisted RemoteApps:

```text
HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\fAllowUnlistedRemotePrograms = 1
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList\fDisabledAllowList = 1
```

If OEM provisioning did not apply the settings, import `oem/RDPApps.reg` manually as Administrator.

Avoid session conflicts:

- Do not leave a full desktop RDP session active.
- Log off old RDP sessions before testing RemoteApps.
- Do not choose session takeover prompts.
- Disable Windows automatic console logon if it creates a competing session.

Useful Windows commands:

```cmd
query session
logoff SESSION_ID
```
