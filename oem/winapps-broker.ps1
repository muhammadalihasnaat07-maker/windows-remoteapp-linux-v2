param(
    [Parameter(Mandatory = $true)]
    [string]$RequestDir,

    [int]$PollMilliseconds = 500,

    [int]$LastAppGraceSeconds = 5
)

$ErrorActionPreference = 'Continue'

if (-not (Test-Path -LiteralPath $RequestDir)) {
    New-Item `
        -ItemType Directory `
        -Path $RequestDir `
        -Force `
        | Out-Null
}

$managedProcesses = @()
$hasLaunched = $false
$lastEmptyAt = $null

while ($true) {

    # Keep only managed applications that are still running.
    $aliveProcesses = @()

    foreach ($process in $managedProcesses) {
        try {
            if (-not $process.HasExited) {
                $aliveProcesses += $process
            }
        }
        catch {
        }
    }

    $managedProcesses = @($aliveProcesses)

    if ($managedProcesses.Count -gt 0) {
        $lastEmptyAt = $null
    }
    elseif ($hasLaunched) {

        if ($null -eq $lastEmptyAt) {
            $lastEmptyAt = Get-Date
        }

        $idleSeconds = (
            (Get-Date) - $lastEmptyAt
        ).TotalSeconds

        if ($idleSeconds -ge $LastAppGraceSeconds) {
            break
        }
    }

    $requests = @(
        Get-ChildItem `
            -LiteralPath $RequestDir `
            -Filter '*.request' `
            -File `
            -ErrorAction SilentlyContinue `
        | Sort-Object Name
    )

    foreach ($request in $requests) {

        try {

            $rawContent = Get-Content `
                -LiteralPath $request.FullName `
                -Raw `
                -ErrorAction Stop

            if ([string]::IsNullOrWhiteSpace($rawContent)) {
                # A newly redirected RDP-drive file can briefly be visible
                # before its contents are readable. Leave it in place and
                # retry on a later broker poll.
                continue
            }

            $appPath = $rawContent.Trim()

            $process = Start-Process `
                -FilePath $appPath `
                -PassThru `
                -ErrorAction Stop

            $managedProcesses += $process
            $hasLaunched = $true
            $lastEmptyAt = $null

            Remove-Item `
                -LiteralPath $request.FullName `
                -Force `
                -ErrorAction Stop
        }
        catch {
            Write-Warning (
                "Failed to process broker request '{0}': {1}" -f `
                $request.FullName,
                $_.Exception.Message
            )
        }
    }

    Start-Sleep -Milliseconds $PollMilliseconds
}
