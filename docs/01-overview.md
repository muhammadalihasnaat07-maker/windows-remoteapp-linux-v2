# 1. Architecture overview

Windows RemoteApp Linux v2 consists of these layers:

1. A Windows 10/11 virtual machine runs inside a Dockur Windows container.
2. Windows Remote Desktop Services exposes applications through RemoteApp / RAIL.
3. One persistent FreeRDP connection starts the Windows RemoteApp broker.
4. Linux application shortcuts queue requests to that broker instead of opening independent RDP sessions.
5. The broker tracks the Windows processes it launches.
6. After the final managed application closes, the broker exits and the Linux supervisor stops the `WinApps` container.

The Windows system disk is stored separately in the persistent Docker volume `winapps_data`.

The container itself is disposable. If necessary, it can be reconstructed around the existing persistent volume.

Using one persistent broker avoids the session-conflict behavior that can occur when Word, Excel, PowerPoint, or other RemoteApps each establish separate FreeRDP sessions.
