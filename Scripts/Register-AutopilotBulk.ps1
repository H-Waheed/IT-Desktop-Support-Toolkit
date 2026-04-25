<#
.SYNOPSIS
    Bulk Autopilot device registration for multiple computers

.DESCRIPTION
    Collects Hardware Hashes from multiple devices on the network and 
    generates a consolidated CSV for bulk Autopilot import into Intune.
    
    Can run remotely against multiple computers or locally on each device.

.PARAMETER ComputerNames
    Array of computer names to collect Hardware Hashes from

.PARAMETER OutputPath
    Path where the consolidated CSV will be saved

.PARAMETER GroupTag
    Optional group tag to apply to all devices

.PARAMETER Credential
    PSCredential for remote access (if needed)

.EXAMPLE
    .\Register-AutopilotBulk.ps1 -ComputerNames "PC01","PC02","PC03" -GroupTag "Sales-Team"

.EXAMPLE
    $cred = Get-Credential
    .\Register-AutopilotBulk.ps1 -ComputerNames (Get-Content .\computers.txt) -Credential $cred

.NOTES
    Author: Hesh - IT Desktop Support Engineer
    Requires: Administrator privileges, network access to target computers
    Compatible: Windows 10/11
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string[]]$ComputerNames = @($env:COMPUTERNAME),
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "$env:USERPROFILE\Desktop",
    
    [Parameter(Mandatory=$false)]
    [string]$GroupTag = "",
    
    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential
)

# Check for admin rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges!"
    exit
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Autopilot Bulk Registration Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target Computers: $($ComputerNames.Count)" -ForegroundColor Cyan
Write-Host ""

$results = @()
$successCount = 0
$failCount = 0

foreach ($computer in $ComputerNames) {
    Write-Host "Processing: $computer" -ForegroundColor Yellow
    
    try {
        # Prepare scriptblock for remote execution
        $scriptBlock = {
            $devDetail = Get-WmiObject -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'"
            $bios = Get-WmiObject -Class Win32_BIOS
            $os = Get-WmiObject -Class Win32_OperatingSystem
            
            return @{
                SerialNumber = $bios.SerialNumber
                ProductID = $os.SerialNumber
                HardwareHash = $devDetail.DeviceHardwareData
                ComputerName = $env:COMPUTERNAME
            }
        }
        
        # Execute locally or remotely
        if ($computer -eq $env:COMPUTERNAME) {
            $deviceData = & $scriptBlock
        } else {
            $params = @{
                ComputerName = $computer
                ScriptBlock = $scriptBlock
                ErrorAction = 'Stop'
            }
            if ($Credential) {
                $params.Add('Credential', $Credential)
            }
            $deviceData = Invoke-Command @params
        }
        
        if ($deviceData.HardwareHash) {
            $deviceInfo = [PSCustomObject]@{
                'Device Serial Number' = $deviceData.SerialNumber
                'Windows Product ID' = $deviceData.ProductID
                'Hardware Hash' = $deviceData.HardwareHash
                'Group Tag' = $GroupTag
                'Assigned User' = ""
            }
            
            $results += $deviceInfo
            Write-Host "  ✓ Success" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  ✗ Failed: No Hardware Hash retrieved" -ForegroundColor Red
            $failCount++
        }
    }
    catch {
        Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        $failCount++
    }
    Write-Host ""
}

# Export results
if ($results.Count -gt 0) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $fileName = "AutopilotBulk_${timestamp}.csv"
    $fullPath = Join-Path -Path $OutputPath -ChildPath $fileName
    
    $results | Export-Csv -Path $fullPath -NoTypeInformation -Force
    
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Bulk Registration Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Total Devices: $($ComputerNames.Count)" -ForegroundColor White
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor Red
    Write-Host ""
    Write-Host "Output File: $fullPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Review the CSV file for accuracy" -ForegroundColor White
    Write-Host "2. Upload to Intune: Devices > Windows > Windows enrollment > Devices > Import" -ForegroundColor White
    Write-Host "3. Monitor import status in Intune portal" -ForegroundColor White
    
} else {
    Write-Warning "No devices were successfully processed!"
}
