# 1. Architecture overview

The solution consists of four layers:

1. A Windows 11 virtual machine runs inside a Docker container using Dockur Windows.
2. Windows Remote Desktop Services exposes individual applications through RemoteApp/RAIL.
3. FreeRDP renders each Windows application as a separate Linux window.
4. A Linux launcher starts and stops the container automatically.

The launcher tracks active RemoteApp processes. When the final application closes, it stops the Windows container to release RAM and CPU resources.
