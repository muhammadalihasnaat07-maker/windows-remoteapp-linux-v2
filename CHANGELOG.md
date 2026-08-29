# Changelog

## 2.0.0

- Rebuilt installation workflow around `setup.sh configure`, `install-windows`, and `finalize`.
- Added canonical `compose.yml` and `config/winapps.env.example` configuration.
- Changed the default Windows configuration to Windows 10, 6G RAM, 4 CPUs, and a 40G disk.
- Added authentication-based Windows readiness instead of relying on TCP port availability or a fixed delay.
- Added a persistent Windows RemoteApp broker using one FreeRDP / RAIL connection.
- Added redirected-drive application request transport through `winappsbroker`.
- Added managed-process tracking and automatic shutdown after the final RemoteApp closes.
- Added automatic application detection and generated Linux shortcuts.
- Added Windows container reconstruction around the persistent `winapps_data` volume.
- Added stdin-based FreeRDP argument handling to keep credentials out of process arguments.
- Added safe uninstall behavior that preserves `winapps_data` by default.
- Added explicit `--purge-data` support for permanent Windows-data deletion.
- Added regression tests for broker lifecycle, shortcuts, setup finalization, repository policy, release surface, and uninstall behavior.
- Retired duplicate v1 Compose/example files and the obsolete launcher installer.

## 1.0.0

- Initial documentation set.
- Docker Compose example.
- RemoteApp registry policy.
- Automatic start/stop launcher.
- Multi-application tracking.
- Desktop shortcut generator.
- Troubleshooting and security guidance.
