<#
.SYNOPSIS
    Triggers manual Intune enrollment for Windows devices

.DESCRIPTION
    Forces a Windows device to enroll in Microsoft Intune MDM. Useful for:
    - Troubleshooting enrollment issues
    - Re-enrolling devices after disjoin
    - Initial manual enrollment outside Autopilot

.PARAMETER CheckOnly
    Only checks enrollment status without triggering enrollment

.EXAMPLE
    .\Start-IntuneEnrollment.ps1
    Triggers Intune enrollment

.EXAMPLE
    .\Start-IntuneEnrollment.ps1 -CheckOnly
    Checks current enrollment status only

.NOTES
    Author: Hesh - IT Desktop Support Engineer
    Requires: Administrator privileges, Entra ID (Azure AD) joined device
    Compatible: Windows 10/11
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$CheckOnly
)

# Check for admin rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges!"
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Intune Manual Enrollment Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check enrollment status
function Get-EnrollmentStatus {
    Write-Host "Checking enrollment status..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check Azure AD join status
    $dsregStatus = dsregcmd /status
    $azureAdJoined = $dsregStatus | Select-String "AzureAdJoined : YES"
    $domainJoined = $dsregStatus | Select-String "DomainJoined : YES"
    
    Write-Host "Device Status:" -ForegroundColor Cyan
    if ($azureAdJoined) {
        Write-Host "  ✓ Entra ID (Azure AD) Joined: YES" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Entra ID (Azure AD) Joined: NO" -ForegroundColor Red
    }
    
    if ($domainJoined) {
        Write-Host "  ✓ On-Premises Domain Joined: YES" -ForegroundColor Green
    } else {
        Write-Host "  ○ On-Premises Domain Joined: NO" -ForegroundColor Gray
    }
    
    # Check MDM enrollment
    $enrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    $enrollments = Get-ChildItem -Path $enrollmentPath -ErrorAction SilentlyContinue
    
    $intuneEnrolled = $false
    foreach ($enrollment in $enrollments) {
        $upn = (Get-ItemProperty -Path $enrollment.PSPath -Name UPN -ErrorAction SilentlyContinue).UPN
        $providerID = (Get-ItemProperty -Path $enrollment.PSPath -Name ProviderID -ErrorAction SilentlyContinue).ProviderID
        
        if ($providerID -like "*MS DM Server*") {
            $intuneEnrolled = $true
            Write-Host ""
            Write-Host "Intune Enrollment:" -ForegroundColor Cyan
            Write-Host "  ✓ Enrolled: YES" -ForegroundColor Green
            Write-Host "  User: $upn" -ForegroundColor White
            Write-Host "  Provider: $providerID" -ForegroundColor White
        }
    }
    
    if (-not $intuneEnrolled) {
        Write-Host ""
        Write-Host "Intune Enrollment:" -ForegroundColor Cyan
        Write-Host "  ✗ Enrolled: NO" -ForegroundColor Red
    }
    
    Write-Host ""
    return @{
        AzureADJoined = [bool]$azureAdJoined
        IntuneEnrolled = $intuneEnrolled
    }
}

# Check current status
$status = Get-EnrollmentStatus

if ($CheckOnly) {
    Write-Host "Check complete. Use without -CheckOnly to trigger enrollment." -ForegroundColor Yellow
    exit
}

# Proceed with enrollment if not enrolled
if ($status.IntuneEnrolled) {
    Write-Host "Device is already enrolled in Intune." -ForegroundColor Green
    $reEnroll = Read-Host "Force re-enrollment? (Y/N)"
    if ($reEnroll -ne 'Y' -and $reEnroll -ne 'y') {
        Write-Host "Enrollment cancelled." -ForegroundColor Yellow
        exit
    }
}

if (-not $status.AzureADJoined) {
    Write-Warning "Device is not Entra ID (Azure AD) joined!"
    Write-Host ""
    Write-Host "This device must be joined to Entra ID before Intune enrollment." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To join Entra ID:" -ForegroundColor Cyan
    Write-Host "1. Settings > Accounts > Access work or school" -ForegroundColor White
    Write-Host "2. Click 'Connect'" -ForegroundColor White
    Write-Host "3. Select 'Join this device to Azure Active Directory'" -ForegroundColor White
    Write-Host "4. Sign in with your organizational account" -ForegroundColor White
    exit
}

# Trigger enrollment
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Starting Intune Enrollment..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

try {
    # Method 1: Trigger via Task Scheduler
    Write-Host "[1/3] Triggering enrollment task..." -ForegroundColor Cyan
    $taskPath = "\Microsoft\Windows\EnterpriseMgmt"
    
    # Get existing enrollment tasks
    $enrollmentTasks = Get-ScheduledTask -TaskPath $taskPath* -ErrorAction SilentlyContinue
    
    if ($enrollmentTasks) {
        foreach ($task in $enrollmentTasks) {
            Write-Host "  Starting task: $($task.TaskName)" -ForegroundColor White
            Start-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction SilentlyContinue
        }
    }
    
    # Method 2: Trigger via DeviceEnroller
    Write-Host "[2/3] Initiating device enrollment..." -ForegroundColor Cyan
    & "C:\Windows\System32\DeviceEnroller.exe" /C /AutoEnrollMDM
    Start-Sleep -Seconds 2
    
    # Method 3: Sync via OMAdmClient
    Write-Host "[3/3] Syncing enrollment policies..." -ForegroundColor Cyan
    $session = New-Object -ComObject Microsoft.Management.Infrastructure.CimSession
    $enrollment = Get-CimInstance -Namespace root/cimv2/mdm/dmmap -ClassName MDM_EnterpriseModernAppManagement_AppManagement01 -ErrorAction SilentlyContinue
    
    if ($enrollment) {
        Invoke-CimMethod -InputObject $enrollment -MethodName UpdateScanMethod -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Enrollment triggered successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Wait 5-10 minutes for enrollment to complete" -ForegroundColor White
    Write-Host "2. Check: Settings > Accounts > Access work or school" -ForegroundColor White
    Write-Host "3. Verify in Intune Admin Center > Devices > Windows" -ForegroundColor White
    Write-Host ""
    Write-Host "Run this script with -CheckOnly to verify enrollment status." -ForegroundColor Cyan
    
}
catch {
    Write-Error "Enrollment failed: $_"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "- Ensure device is Entra ID joined" -ForegroundColor White
    Write-Host "- Check internet connectivity" -ForegroundColor White
    Write-Host "- Verify user has Intune license assigned" -ForegroundColor White
    Write-Host "- Check Event Viewer > Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider" -ForegroundColor White
}
