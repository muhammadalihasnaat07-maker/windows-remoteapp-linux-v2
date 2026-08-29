@echo off
setlocal

echo ============================================================
echo Windows RemoteApp Linux v2 - OEM Provisioning
echo ============================================================

if not exist "C:\OEM\configure-winapps.ps1" (
    echo [ERROR] C:\OEM\configure-winapps.ps1 was not found.
    exit /b 1
)

if not exist "C:\OEM\RDPApps.reg" (
    echo [ERROR] C:\OEM\RDPApps.reg was not found.
    exit /b 1
)

echo [INFO] Running Windows provisioning...

powershell.exe ^
    -NoLogo ^
    -NoProfile ^
    -NonInteractive ^
    -ExecutionPolicy Bypass ^
    -File "C:\OEM\configure-winapps.ps1"

set RESULT=%ERRORLEVEL%

if not "%RESULT%"=="0" (
    echo [ERROR] Windows provisioning failed with exit code %RESULT%.
    exit /b %RESULT%
)

echo [SUCCESS] Windows RemoteApp provisioning completed.
exit /b 0
