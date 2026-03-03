# Manage-USBCamera.ps1
# PowerShell script to manage USB camera attachment to WSL2
# Run as Administrator

param(
    [Parameter(Position=0)]
    [ValidateSet("status", "bind", "attach", "detach", "restart", "help")]
    [string]$Action = "help",
    
    [Parameter()]
    [string]$BusId = "5-4"
)

$USBIPD_PATH = "C:\Program Files\usbipd-win\usbipd.exe"
$CAMERA_NAME = "CCX2F3298"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-UsbIpdInstalled {
    if (Test-Path $USBIPD_PATH) {
        return $true
    }
    return (Get-Command usbipd.exe -ErrorAction SilentlyContinue)
}

function Show-Help {
    Write-ColorOutput "`nQIDI Plus 4 USB Camera Manager for WSL2`n" "Cyan"
    Write-ColorOutput "Usage: .\Manage-USBCamera.ps1 <action> [-BusId <busid>]`n" "White"
    Write-ColorOutput "Actions:" "Yellow"
    Write-ColorOutput "  status   - Show USB device status" "White"
    Write-ColorOutput "  bind     - Share USB camera (one-time setup)" "White"
    Write-ColorOutput "  attach   - Attach camera to WSL2" "White"
    Write-ColorOutput "  detach   - Detach camera from WSL2" "White"
    Write-ColorOutput "  restart  - Detach, restart WSL, and re-attach" "White"
    Write-ColorOutput "  help     - Show this help message`n" "White"
    Write-ColorOutput "Examples:" "Yellow"
    Write-ColorOutput "  .\Manage-USBCamera.ps1 status" "Gray"
    Write-ColorOutput "  .\Manage-USBCamera.ps1 bind" "Gray"
    Write-ColorOutput "  .\Manage-USBCamera.ps1 attach" "Gray"
    Write-ColorOutput "  .\Manage-USBCamera.ps1 restart`n" "Gray"
}

function Invoke-UsbIpd {
    param([string[]]$Arguments)
    
    if (Test-Path $USBIPD_PATH) {
        & $USBIPD_PATH @Arguments
    } else {
        & usbipd.exe @Arguments
    }
}

function Show-Status {
    Write-ColorOutput "`n[Camera Manager] Checking USB devices...`n" "Cyan"
    Invoke-UsbIpd "list"
}

function Invoke-Bind {
    if (-not (Test-Administrator)) {
        Write-ColorOutput "[Error] Administrator privileges required for bind operation." "Red"
        Write-ColorOutput "[Info] Right-click PowerShell and select 'Run as Administrator'`n" "Yellow"
        exit 1
    }
    
    Write-ColorOutput "`n[Camera Manager] Binding camera (BUSID: $BusId)...`n" "Cyan"
    Invoke-UsbIpd "bind", "--busid", $BusId
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "`n[Success] Camera bound successfully!" "Green"
        Write-ColorOutput "[Info] You can now attach it with: .\Manage-USBCamera.ps1 attach`n" "Yellow"
    } else {
        Write-ColorOutput "`n[Error] Bind operation failed (exit code: $LASTEXITCODE)`n" "Red"
    }
}

function Invoke-Attach {
    if (-not (Test-Administrator)) {
        Write-ColorOutput "[Error] Administrator privileges required for attach operation." "Red"
        Write-ColorOutput "[Info] Right-click PowerShell and select 'Run as Administrator'`n" "Yellow"
        exit 1
    }
    
    Write-ColorOutput "`n[Camera Manager] Attaching camera (BUSID: $BusId) to WSL2...`n" "Cyan"
    Write-ColorOutput "[Info] This may take 10-30 seconds...`n" "Yellow"
    
    Invoke-UsbIpd "attach", "--wsl", "--busid", $BusId
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "`n[Success] Camera attached to WSL2!" "Green"
        Write-ColorOutput "[Info] Verify in WSL with: ls -la /dev/video*" "Yellow"
        Write-ColorOutput "[Info] Start services with: make up`n" "Yellow"
    } else {
        Write-ColorOutput "`n[Error] Attach operation failed (exit code: $LASTEXITCODE)" "Red"
        Write-ColorOutput "[Tip] Make sure camera is bound first: .\Manage-USBCamera.ps1 bind`n" "Yellow"
    }
}

function Invoke-Detach {
    if (-not (Test-Administrator)) {
        Write-ColorOutput "[Error] Administrator privileges required for detach operation." "Red"
        Write-ColorOutput "[Info] Right-click PowerShell and select 'Run as Administrator'`n" "Yellow"
        exit 1
    }
    
    Write-ColorOutput "`n[Camera Manager] Detaching camera (BUSID: $BusId) from WSL2...`n" "Cyan"
    Invoke-UsbIpd "detach", "--busid", $BusId
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "`n[Success] Camera detached from WSL2!`n" "Green"
    } else {
        Write-ColorOutput "`n[Warning] Detach may have failed or camera was not attached.`n" "Yellow"
    }
}

function Invoke-Restart {
    if (-not (Test-Administrator)) {
        Write-ColorOutput "[Error] Administrator privileges required for restart operation." "Red"
        Write-ColorOutput "[Info] Right-click PowerShell and select 'Run as Administrator'`n" "Yellow"
        exit 1
    }
    
    Write-ColorOutput "`n[Camera Manager] Restarting WSL2 and re-attaching camera...`n" "Cyan"
    
    # Detach first (ignore errors)
    Write-ColorOutput "[Step 1/3] Detaching camera..." "Yellow"
    Invoke-UsbIpd "detach", "--busid", $BusId 2>$null
    
    # Shutdown WSL
    Write-ColorOutput "[Step 2/3] Shutting down WSL2..." "Yellow"
    wsl --shutdown
    Start-Sleep -Seconds 3
    
    # Attach camera
    Write-ColorOutput "[Step 3/3] Attaching camera..." "Yellow"
    Invoke-UsbIpd "attach", "--wsl", "--busid", $BusId
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "`n[Success] WSL2 restarted and camera re-attached!" "Green"
        Write-ColorOutput "[Info] Verify in WSL with: ls -la /dev/video*`n" "Yellow"
    } else {
        Write-ColorOutput "`n[Error] Failed to re-attach camera after WSL restart.`n" "Red"
    }
}

# Main execution
Write-ColorOutput "QIDI Plus 4 - USB Camera Manager" "Cyan"
Write-ColorOutput "Device: $CAMERA_NAME (BUSID: $BusId)`n" "Gray"

# Check if usbipd is installed
if (-not (Test-UsbIpdInstalled)) {
    Write-ColorOutput "[Error] usbipd-win is not installed!" "Red"
    Write-ColorOutput "[Install] Run: winget install --id dorssel.usbipd-win" "Yellow"
    Write-ColorOutput "[Install] Then restart PowerShell as Administrator`n" "Yellow"
    exit 1
}

# Execute requested action
switch ($Action) {
    "status"  { Show-Status }
    "bind"    { Invoke-Bind }
    "attach"  { Invoke-Attach }
    "detach"  { Invoke-Detach }
    "restart" { Invoke-Restart }
    "help"    { Show-Help }
    default   { Show-Help }
}
