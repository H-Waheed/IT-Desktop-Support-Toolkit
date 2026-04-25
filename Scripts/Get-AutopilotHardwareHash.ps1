<#
.SYNOPSIS
    Extracts Hardware Hash (4K HH) for Windows Autopilot enrollment

.DESCRIPTION
    This script retrieves the device's Hardware Hash required for manual 
    Autopilot enrollment in Microsoft Intune. The output CSV can be uploaded 
    directly to the Intune portal.

.PARAMETER OutputPath
    Path where the CSV file will be saved. Defaults to current user's Desktop.

.PARAMETER GroupTag
    Optional group tag to assign to the device during enrollment.

.EXAMPLE
    .\Get-AutopilotHardwareHash.ps1
    Exports Hardware Hash to Desktop with default naming

.EXAMPLE
    .\Get-AutopilotHardwareHash.ps1 -OutputPath "C:\Temp" -GroupTag "IT-Dept"
    Exports to C:\Temp with IT-Dept group tag

.NOTES
    Author: Hesh - IT Desktop Support Engineer
    Requires: Administrator privileges
    Compatible: Windows 10/11
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "$env:USERPROFILE\Desktop",
    
    [Parameter(Mandatory=$false)]
    [string]$GroupTag = ""
)

# Check for admin rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges!"
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Autopilot Hardware Hash Extractor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get computer info
$computerName = $env:COMPUTERNAME
$serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber

Write-Host "Computer Name: $computerName" -ForegroundColor Green
Write-Host "Serial Number: $serialNumber" -ForegroundColor Green
Write-Host ""

# Install required module if missing
Write-Host "Checking for required modules..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Intune)) {
    Write-Host "Installing Microsoft.Graph.Intune module..." -ForegroundColor Yellow
    try {
        Install-Module -Name Microsoft.Graph.Intune -Force -AllowClobber -Scope CurrentUser
        Write-Host "Module installed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to install module. Trying alternative method..."
    }
}

# Get Hardware Hash
Write-Host "Extracting Hardware Hash (this may take a moment)..." -ForegroundColor Yellow

try {
    $devDetail = (Get-WmiObject -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
    
    if ($null -eq $devDetail) {
        Write-Error "Failed to retrieve device details. Ensure the device supports modern management."
        exit
    }
    
    $hardwareHash = $devDetail.DeviceHardwareData
    
    # Create custom object for export
    $deviceInfo = [PSCustomObject]@{
        'Device Serial Number' = $serialNumber
        'Windows Product ID' = (Get-WmiObject -Class Win32_OperatingSystem).SerialNumber
        'Hardware Hash' = $hardwareHash
        'Group Tag' = $GroupTag
        'Assigned User' = ""
    }
    
    # Generate filename with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $fileName = "AutopilotHWID_${computerName}_${timestamp}.csv"
    $fullPath = Join-Path -Path $OutputPath -ChildPath $fileName
    
    # Export to CSV
    $deviceInfo | Export-Csv -Path $fullPath -NoTypeInformation -Force
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS! Hardware Hash exported." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "File Location: $fullPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Open Microsoft Intune Admin Center" -ForegroundColor White
    Write-Host "2. Navigate to: Devices > Windows > Windows enrollment > Devices" -ForegroundColor White
    Write-Host "3. Click 'Import' and upload this CSV file" -ForegroundColor White
    Write-Host "4. Wait for sync (can take up to 15 minutes)" -ForegroundColor White
    Write-Host ""
    
    # Open file location
    $openFolder = Read-Host "Open output folder? (Y/N)"
    if ($openFolder -eq 'Y' -or $openFolder -eq 'y') {
        Start-Process explorer.exe -ArgumentList "/select,`"$fullPath`""
    }
    
}
catch {
    Write-Error "Failed to extract Hardware Hash: $_"
    Write-Host ""
    Write-Host "Troubleshooting Tips:" -ForegroundColor Yellow
    Write-Host "- Ensure you're running as Administrator" -ForegroundColor White
    Write-Host "- Verify Windows 10/11 (1809 or later)" -ForegroundColor White
    Write-Host "- Check if device supports MDM enrollment" -ForegroundColor White
    exit
}
