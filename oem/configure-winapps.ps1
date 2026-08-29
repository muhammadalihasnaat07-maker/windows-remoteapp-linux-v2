$ErrorActionPreference = 'Stop'

$LogFile = 'C:\OEM\winapps-provisioning.log'
$Marker  = 'C:\OEM\winapps-provisioned.txt'

function Write-Log {
    param([string]$Message)

    $Line = ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)

    Write-Host $Line
    Add-Content -Path $LogFile -Value $Line
}

try {
    Write-Log 'Starting Windows RemoteApp Linux v2 provisioning.'

    # --------------------------------------------------------
    # Import RemoteApp / RDP registry configuration
    # --------------------------------------------------------

    $RegFile = 'C:\OEM\RDPApps.reg'

    if (-not (Test-Path $RegFile)) {
        throw "Registry file not found: $RegFile"
    }

    Write-Log 'Importing RemoteApp registry settings.'

    $RegProcess = Start-Process `
        -FilePath 'reg.exe' `
        -ArgumentList @('import', $RegFile) `
        -Wait `
        -PassThru `
        -WindowStyle Hidden

    if ($RegProcess.ExitCode -ne 0) {
        throw "reg.exe import failed with exit code $($RegProcess.ExitCode)"
    }

    Write-Log 'Registry settings imported.'

    # --------------------------------------------------------
    # Explicitly enforce no automatic Windows console login.
    # This duplicates AUTOLOGIN=N intentionally.
    # --------------------------------------------------------

    $WinlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    New-ItemProperty `
        -Path $WinlogonPath `
        -Name 'AutoAdminLogon' `
        -Value '0' `
        -PropertyType String `
        -Force | Out-Null

    Write-Log 'AutoAdminLogon disabled.'

    # --------------------------------------------------------
    # Ensure Remote Desktop service starts automatically.
    # --------------------------------------------------------

    Set-Service -Name 'TermService' -StartupType Automatic

    $TermService = Get-Service -Name 'TermService'

    if ($TermService.Status -ne 'Running') {
        Start-Service -Name 'TermService'
    }

    Write-Log 'Remote Desktop Services enabled.'

    # --------------------------------------------------------
    # Enable Windows Firewall rules for Remote Desktop.
    # --------------------------------------------------------

    $FirewallRules = Get-NetFirewallRule `
        -DisplayGroup 'Remote Desktop' `
        -ErrorAction SilentlyContinue

    if ($FirewallRules) {
        $FirewallRules | Enable-NetFirewallRule
        Write-Log 'Remote Desktop firewall rules enabled.'
    }
    else {
        Write-Log 'Remote Desktop firewall rule group not found; using netsh fallback.'

        & netsh.exe advfirewall firewall set rule `
            group='remote desktop' `
            new enable=Yes | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enable Remote Desktop firewall rules."
        }

        Write-Log 'Remote Desktop firewall rules enabled using netsh.'
    }

    # --------------------------------------------------------
    # Verify registry values
    # --------------------------------------------------------

    $TerminalServer = Get-ItemProperty `
        'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'

    if ($TerminalServer.fDenyTSConnections -ne 0) {
        throw 'Remote Desktop registry verification failed.'
    }

    $AllowList = Get-ItemProperty `
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\TSAppAllowList'

    if ($AllowList.fDisabledAllowList -ne 1) {
        throw 'RemoteApp allow-list verification failed.'
    }

    $Policy = Get-ItemProperty `
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'

    if ($Policy.fAllowUnlistedRemotePrograms -ne 1) {
        throw 'Unlisted RemoteApp policy verification failed.'
    }

    $AutoLogin = Get-ItemPropertyValue `
        -Path $WinlogonPath `
        -Name 'AutoAdminLogon'

    if ($AutoLogin -ne '0') {
        throw 'AutoAdminLogon verification failed.'
    }

    # --------------------------------------------------------
    # Success marker
    # --------------------------------------------------------

    @(
        'Windows RemoteApp Linux v2 provisioning completed successfully.'
        ('Completed: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        'RDP enabled: YES'
        'RemoteApp unlisted programs: YES'
        'AutoAdminLogon: DISABLED'
    ) | Set-Content -Path $Marker

    Write-Log 'Provisioning completed successfully.'
    exit 0
}
catch {
    Write-Log ('ERROR: {0}' -f $_.Exception.Message)

    if (Test-Path $Marker) {
        Remove-Item $Marker -Force
    }

    exit 1
}
