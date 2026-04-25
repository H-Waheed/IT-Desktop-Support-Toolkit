<#
.SYNOPSIS
    Validates device readiness for Autopilot/Intune enrollment

.DESCRIPTION
    Comprehensive pre-flight check script that verifies:
    - Windows version compatibility
    - TPM status
    - Network connectivity
    - Required services running
    - BIOS mode (UEFI vs Legacy)
    - Internet access to Microsoft services
    
    Use this BEFORE attempting Autopilot enrollment to catch issues early.

.EXAMPLE
    .\Test-AutopilotReadiness.ps1

.NOTES
    Author: Hesh - IT Desktop Support Engineer
    Requires: Administrator privileges
    Compatible: Windows 10/11
#>

[CmdletBinding()]
param()

# Check for admin rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges!"
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Autopilot Readiness Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$results = @()
$passCount = 0
$failCount = 0
$warnCount = 0

# Helper function for results
function Add-Result {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Status,  # PASS, FAIL, WARN
        [string]$Details
    )
    
    $script:results += [PSCustomObject]@{
        Category = $Category
        Check = $Check
        Status = $Status
        Details = $Details
    }
    
    $color = switch ($Status) {
        "PASS" { "Green"; $script:passCount++; "✓" }
        "FAIL" { "Red"; $script:failCount++; "✗" }
        "WARN" { "Yellow"; $script:warnCount++; "⚠" }
    }
    
    Write-Host "$($color[2]) $Check" -ForegroundColor $color[0]
    Write-Host "  $Details" -ForegroundColor Gray
}

# =====================================
# CATEGORY 1: Windows Version
# =====================================
Write-Host "[1/7] Checking Windows Version..." -ForegroundColor Cyan

$os = Get-WmiObject -Class Win32_OperatingSystem
$build = [System.Environment]::OSVersion.Version.Build

if ($os.Caption -match "Windows 11") {
    Add-Result "Windows" "Windows 11 Detected" "PASS" "$($os.Caption) Build $build"
}
elseif ($os.Caption -match "Windows 10") {
    if ($build -ge 17763) {
        Add-Result "Windows" "Windows 10 Version" "PASS" "Build $build (1809+) - Autopilot Compatible"
    } else {
        Add-Result "Windows" "Windows 10 Version" "FAIL" "Build $build is too old. Requires 1809+ (Build 17763+)"
    }
}
else {
    Add-Result "Windows" "Operating System" "FAIL" "$($os.Caption) - Not supported for Autopilot"
}

# Check Windows edition
if ($os.Caption -match "Pro|Enterprise|Education") {
    Add-Result "Windows" "Windows Edition" "PASS" "$($os.Caption)"
} else {
    Add-Result "Windows" "Windows Edition" "FAIL" "Home edition not supported for Intune/Autopilot"
}

Write-Host ""

# =====================================
# CATEGORY 2: Hardware
# =====================================
Write-Host "[2/7] Checking Hardware..." -ForegroundColor Cyan

# Check BIOS mode
$firmwareType = (Get-WmiObject -Class Win32_ComputerSystem).BootupState
try {
    $secureBootEnabled = Confirm-SecureBootUEFI
    Add-Result "Hardware" "Firmware Mode" "PASS" "UEFI with Secure Boot enabled"
}
catch {
    if ((Get-WmiObject -Class Win32_BIOS).SMBIOSBIOSVersion -match "UEFI") {
        Add-Result "Hardware" "Firmware Mode" "WARN" "UEFI detected but Secure Boot not enabled"
    } else {
        Add-Result "Hardware" "Firmware Mode" "FAIL" "Legacy BIOS detected. Autopilot requires UEFI"
    }
}

# Check TPM
$tpm = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTpm" -Class Win32_Tpm -ErrorAction SilentlyContinue
if ($tpm) {
    $tpmVersion = $tpm.SpecVersion.Split(",")[0]
    if ($tpmVersion -eq "2.0") {
        Add-Result "Hardware" "TPM Status" "PASS" "TPM 2.0 present and enabled"
    } else {
        Add-Result "Hardware" "TPM Status" "WARN" "TPM $tpmVersion detected. TPM 2.0 recommended"
    }
} else {
    Add-Result "Hardware" "TPM Status" "FAIL" "TPM not detected or not enabled in BIOS"
}

Write-Host ""

# =====================================
# CATEGORY 3: Network Connectivity
# =====================================
Write-Host "[3/7] Checking Network Connectivity..." -ForegroundColor Cyan

# Test internet
try {
    $internet = Test-NetConnection -ComputerName "www.microsoft.com" -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($internet) {
        Add-Result "Network" "Internet Connectivity" "PASS" "Connected to internet"
    } else {
        Add-Result "Network" "Internet Connectivity" "FAIL" "No internet connection detected"
    }
}
catch {
    Add-Result "Network" "Internet Connectivity" "FAIL" "Unable to test connectivity"
}

# Test required Microsoft URLs
$requiredUrls = @(
    "login.microsoftonline.com",
    "enrollment.manage.microsoft.com",
    "portal.manage.microsoft.com"
)

$urlTestFailed = $false
foreach ($url in $requiredUrls) {
    try {
        $test = Test-NetConnection -ComputerName $url -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if (-not $test) {
            $urlTestFailed = $true
            break
        }
    }
    catch {
        $urlTestFailed = $true
        break
    }
}

if (-not $urlTestFailed) {
    Add-Result "Network" "Microsoft Services" "PASS" "All required URLs accessible"
} else {
    Add-Result "Network" "Microsoft Services" "FAIL" "Cannot reach required Microsoft services. Check firewall/proxy"
}

Write-Host ""

# =====================================
# CATEGORY 4: Services
# =====================================
Write-Host "[4/7] Checking Required Services..." -ForegroundColor Cyan

$requiredServices = @(
    @{Name="Winmgmt"; DisplayName="Windows Management Instrumentation"},
    @{Name="dmwappushservice"; DisplayName="Device Management Wireless Push Service"}
)

foreach ($svc in $requiredServices) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -eq "Running") {
            Add-Result "Services" $svc.DisplayName "PASS" "Running"
        } else {
            Add-Result "Services" $svc.DisplayName "WARN" "Service exists but not running"
        }
    } else {
        Add-Result "Services" $svc.DisplayName "FAIL" "Service not found"
    }
}

Write-Host ""

# =====================================
# CATEGORY 5: MDM Capability
# =====================================
Write-Host "[5/7] Checking MDM Capability..." -ForegroundColor Cyan

# Check if device can retrieve Hardware Hash
try {
    $devDetail = Get-WmiObject -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'" -ErrorAction Stop
    if ($devDetail.DeviceHardwareData) {
        Add-Result "MDM" "Hardware Hash Available" "PASS" "Device can provide Hardware Hash for Autopilot"
    } else {
        Add-Result "MDM" "Hardware Hash Available" "FAIL" "Cannot retrieve Hardware Hash"
    }
}
catch {
    Add-Result "MDM" "Hardware Hash Available" "FAIL" "MDM/WMI namespace not accessible"
}

# Check current enrollment status
$enrollments = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Enrollments\*" -ErrorAction SilentlyContinue | Where-Object {$_.ProviderID -like "*MS DM Server*"}
if ($enrollments) {
    Add-Result "MDM" "Current Enrollment" "WARN" "Device already enrolled in Intune"
} else {
    Add-Result "MDM" "Current Enrollment" "PASS" "Device not currently enrolled (ready for fresh enrollment)"
}

Write-Host ""

# =====================================
# CATEGORY 6: Azure AD Status
# =====================================
Write-Host "[6/7] Checking Entra ID Status..." -ForegroundColor Cyan

$dsregOutput = dsregcmd /status
$azureAdJoined = $dsregOutput | Select-String "AzureAdJoined : YES"
$domainJoined = $dsregOutput | Select-String "DomainJoined : YES"

if ($azureAdJoined) {
    Add-Result "Identity" "Entra ID Join" "WARN" "Already joined to Entra ID (may need reset for fresh Autopilot)"
} else {
    Add-Result "Identity" "Entra ID Join" "PASS" "Not joined (ready for Autopilot deployment)"
}

if ($domainJoined) {
    Add-Result "Identity" "Domain Join" "WARN" "Joined to on-premises domain (consider Hybrid Autopilot scenario)"
} else {
    Add-Result "Identity" "Domain Join" "PASS" "Not domain-joined"
}

Write-Host ""

# =====================================
# CATEGORY 7: Disk & Performance
# =====================================
Write-Host "[7/7] Checking Disk Space..." -ForegroundColor Cyan

$disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)

if ($freeSpaceGB -gt 20) {
    Add-Result "Disk" "Free Space" "PASS" "$freeSpaceGB GB available"
} elseif ($freeSpaceGB -gt 10) {
    Add-Result "Disk" "Free Space" "WARN" "$freeSpaceGB GB available (recommend 20GB+)"
} else {
    Add-Result "Disk" "Free Space" "FAIL" "$freeSpaceGB GB available (insufficient for Autopilot)"
}

Write-Host ""

# =====================================
# SUMMARY
# =====================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Total Checks: $($results.Count)" -ForegroundColor White
Write-Host "✓ Passed: $passCount" -ForegroundColor Green
Write-Host "⚠ Warnings: $warnCount" -ForegroundColor Yellow
Write-Host "✗ Failed: $failCount" -ForegroundColor Red
Write-Host ""

if ($failCount -eq 0 -and $warnCount -eq 0) {
    Write-Host "🎉 READY FOR AUTOPILOT!" -ForegroundColor Green
    Write-Host "This device meets all requirements for Autopilot enrollment." -ForegroundColor Green
}
elseif ($failCount -eq 0) {
    Write-Host "⚠ READY WITH WARNINGS" -ForegroundColor Yellow
    Write-Host "Device can proceed but review warnings above." -ForegroundColor Yellow
}
else {
    Write-Host "❌ NOT READY" -ForegroundColor Red
    Write-Host "Address the failed checks before attempting Autopilot enrollment." -ForegroundColor Red
}

Write-Host ""

# Export detailed results
$exportChoice = Read-Host "Export detailed results to CSV? (Y/N)"
if ($exportChoice -eq 'Y' -or $exportChoice -eq 'y') {
    $exportPath = "$env:USERPROFILE\Desktop\AutopilotReadiness_$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $results | Export-Csv -Path $exportPath -NoTypeInformation
    Write-Host "Results exported to: $exportPath" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
if ($failCount -eq 0) {
    Write-Host "1. Extract Hardware Hash: .\Get-AutopilotHardwareHash.ps1" -ForegroundColor White
    Write-Host "2. Upload CSV to Intune portal" -ForegroundColor White
    Write-Host "3. Assign Autopilot profile" -ForegroundColor White
    Write-Host "4. Factory reset device and begin OOBE" -ForegroundColor White
} else {
    Write-Host "1. Fix failed checks listed above" -ForegroundColor White
    Write-Host "2. Re-run this validation script" -ForegroundColor White
    Write-Host "3. Proceed with Autopilot enrollment once all checks pass" -ForegroundColor White
}
Write-Host ""
