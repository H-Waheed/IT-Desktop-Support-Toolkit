# Troubleshooting Common Intune & Autopilot Issues

A practical guide for diagnosing and resolving common enrollment and deployment problems.

---

## Table of Contents
1. [Autopilot Issues](#autopilot-issues)
2. [Intune Enrollment Issues](#intune-enrollment-issues)
3. [Entra ID Join Issues](#entra-id-join-issues)
4. [Hardware Hash Problems](#hardware-hash-problems)
5. [Diagnostic Commands](#diagnostic-commands)

---

## Autopilot Issues

### Issue: Device not showing in Autopilot

**Symptoms:**
- Hardware Hash uploaded but device missing from Intune portal
- Device shows "Not assigned" during OOBE
- Autopilot profile not applying

**Diagnosis:**
```powershell
# Check if CSV was formatted correctly
Import-Csv .\AutopilotHWID.csv | Format-Table

# Verify upload in Intune portal
# Devices > Windows > Windows enrollment > Devices
```

**Solutions:**
1. **Wait for sync** - Can take 15-30 minutes after upload
2. **Check CSV format** - Must have exact column names
3. **Verify serial number** - Must match BIOS serial exactly
4. **Delete and re-import** - Remove device from Autopilot, wait 10 min, re-upload

---

### Issue: "Something went wrong" during Autopilot OOBE

**Symptoms:**
- Red error screen during Windows setup
- Error code: 0x80180014 or 0x800705b4
- Cannot proceed with setup

**Diagnosis:**
```powershell
# On the error screen, press Shift+F10 to open CMD
# Check logs
notepad C:\Windows\Panther\UnattendGC\Setupact.log

# Check network
ping login.microsoftonline.com
```

**Common Causes:**
- ❌ **No internet connection** - Verify network/WiFi
- ❌ **Firewall blocking** - Check required URLs
- ❌ **No Autopilot profile assigned** - Verify in Intune
- ❌ **Wrong tenant** - Device registered to different Entra ID
- ❌ **TPM issues** - Clear TPM in BIOS

**Solutions:**
1. **Check required URLs are accessible:**
   ```
   login.microsoftonline.com
   login.windows.net
   *.manage.microsoft.com
   *.microsoftonline-p.com
   ```

2. **Reset and retry:**
   - Press Shift+F10 during error
   - Run: `shutdown /r /t 0`
   - Or factory reset device

3. **Check Event Viewer:**
   ```
   Applications and Services Logs > Microsoft > Windows >
   - DeviceManagement-Enterprise-Diagnostics-Provider
   - Provisioning-Diagnostics-Provider
   ```

---

## Intune Enrollment Issues

### Issue: Device not enrolling in Intune

**Symptoms:**
- "We couldn't connect to the enrollment server" error
- Settings > Accounts shows no MDM connection
- Missing from Intune > Devices

**Diagnosis:**
```powershell
# Check enrollment status
.\Start-IntuneEnrollment.ps1 -CheckOnly

# Check registry
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Enrollments\*" -Name UPN -ErrorAction SilentlyContinue

# Run dsregcmd
dsregcmd /status
```

**Solutions:**

1. **Verify Azure AD Join:**
   ```powershell
   dsregcmd /status
   # Look for: AzureAdJoined : YES
   ```
   If NO → Device must be Entra ID joined first

2. **Check user license:**
   - User MUST have Intune license assigned
   - Verify in M365 Admin Center > Users > Licenses

3. **Manual enrollment trigger:**
   ```powershell
   .\Start-IntuneEnrollment.ps1
   ```

4. **Check MDM authority:**
   - Intune > Tenant administration > MDM authority
   - Should be set to "Microsoft Intune"

5. **Clear previous enrollments:**
   ```powershell
   # Delete old enrollment registries
   Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments" | Remove-Item -Recurse -Force
   
   # Restart enrollment
   .\Start-IntuneEnrollment.ps1
   ```

---

### Issue: Policies not applying to device

**Symptoms:**
- Device enrolled but no policies sync
- Settings > Accounts shows "Info" button greyed out
- Last sync time is old or never

**Diagnosis:**
```powershell
# Force sync
Get-ScheduledTask | Where-Object {$_.TaskName -like "*Enterprise*"} | Start-ScheduledTask

# Check sync status
Get-ScheduledTask | Where-Object {$_.TaskName -like "*Enterprise*"} | Format-Table TaskName, State, LastRunTime
```

**Solutions:**

1. **Manual sync from Settings:**
   - Settings > Accounts > Access work or school
   - Click your account > Info > Sync

2. **Force sync via PowerShell:**
   ```powershell
   $session = New-CimSession
   $enrollment = Get-CimInstance -Namespace root/cimv2/mdm/dmmap -ClassName MDM_EnterpriseModernAppManagement_AppManagement01
   Invoke-CimMethod -InputObject $enrollment -MethodName UpdateScanMethod
   ```

3. **Check device compliance:**
   - Intune > Devices > All devices > [Your Device] > Overview
   - Look for compliance issues

4. **Restart Intune services:**
   ```powershell
   Restart-Service -Name dmwappushservice -Force
   ```

---

## Entra ID Join Issues

### Issue: Cannot join device to Entra ID

**Symptoms:**
- "Something went wrong" during join process
- Error: 0x801c0002 or 0x801c03ed
- Join button greyed out

**Diagnosis:**
```powershell
# Check current status
dsregcmd /status

# Test connectivity
Test-NetConnection login.microsoftonline.com -Port 443
```

**Solutions:**

1. **Verify prerequisites:**
   - Windows 10 1809+ or Windows 11
   - Internet connectivity
   - User has permission to join devices
   - Not already domain-joined (or use Hybrid join)

2. **Clear cached credentials:**
   ```
   Settings > Accounts > Access work or school >
   Remove all existing connections > Restart > Try again
   ```

3. **Check Entra ID settings:**
   - Entra ID > Devices > Device settings
   - "Users may join devices to Azure AD" = All or Selected
   - "Maximum number of devices per user" not exceeded

4. **Network/Proxy issues:**
   - Ensure no proxy blocking Microsoft services
   - Test from different network
   - Check firewall rules

---

## Hardware Hash Problems

### Issue: Cannot extract Hardware Hash

**Symptoms:**
- Script fails with WMI error
- Empty Hardware Hash field
- "Access denied" errors

**Diagnosis:**
```powershell
# Test WMI access
Get-WmiObject -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -ErrorAction Stop

# Check admin rights
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
```

**Solutions:**

1. **Run as Administrator** - MUST have admin rights

2. **Enable WMI:**
   ```powershell
   # Start WMI service
   Start-Service Winmgmt
   Set-Service Winmgmt -StartupType Automatic
   ```

3. **Rebuild WMI repository (if corrupted):**
   ```cmd
   # In CMD as Admin
   winmgmt /salvagerepository
   winmgmt /verifyrepository
   ```

4. **Alternative extraction method:**
   ```powershell
   # Using Get-WindowsAutopilotInfo (if available)
   Install-Script -Name Get-WindowsAutopilotInfo
   Get-WindowsAutopilotInfo.ps1 -OutputFile C:\Temp\AutopilotHWID.csv
   ```

---

## Diagnostic Commands

### Essential troubleshooting commands

```powershell
# ===================================
# DEVICE STATUS
# ===================================

# Complete device status
dsregcmd /status

# Enrollment details
dsregcmd /debug

# Leave Azure AD (use with caution!)
dsregcmd /leave


# ===================================
# INTUNE SYNC & ENROLLMENT
# ===================================

# Force Intune sync
Get-ScheduledTask | Where-Object {$_.TaskPath -like "*Microsoft*Windows*EnterpriseMgmt*"} | Start-ScheduledTask

# Check enrollment status
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Enrollments\*" | Select-Object PSPath, UPN, ProviderID

# View last sync time
Get-ScheduledTask | Where-Object {$_.TaskPath -like "*EnterpriseMgmt*"} | Get-ScheduledTaskInfo


# ===================================
# EVENT LOGS
# ===================================

# Autopilot events
Get-WinEvent -LogName "Microsoft-Windows-Provisioning-Diagnostics-Provider/Admin" -MaxEvents 50

# Enrollment events
Get-WinEvent -LogName "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin" -MaxEvents 50

# MDM events
Get-WinEvent -LogName "Microsoft-Windows-AAD/Operational" -MaxEvents 50


# ===================================
# NETWORK CONNECTIVITY
# ===================================

# Test required URLs
$urls = @(
    "login.microsoftonline.com",
    "enrollment.manage.microsoft.com",
    "portal.manage.microsoft.com"
)

foreach ($url in $urls) {
    Test-NetConnection $url -Port 443 | Select-Object ComputerName, TcpTestSucceeded
}


# ===================================
# HARDWARE HASH
# ===================================

# Quick Hardware Hash check
$hash = (Get-WmiObject -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'").DeviceHardwareData
if ($hash) { Write-Host "Hardware Hash exists: $($hash.Length) characters" -ForegroundColor Green }
else { Write-Host "No Hardware Hash found!" -ForegroundColor Red }


# ===================================
# CLEANUP & RESET
# ===================================

# Remove all enrollments (use carefully!)
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

# Remove Azure AD join (requires restart)
dsregcmd /leave

# Full device reset (last resort)
# systemreset
```

---

## Event Viewer Locations

Key logs for troubleshooting:

```
Applications and Services Logs >
├── Microsoft > Windows >
│   ├── AAD
│   │   └── Operational (Azure AD join/auth)
│   ├── DeviceManagement-Enterprise-Diagnostics-Provider
│   │   ├── Admin (Intune enrollment)
│   │   └── Operational
│   ├── Provisioning-Diagnostics-Provider
│   │   ├── Admin (Autopilot provisioning)
│   │   └── AutoPilot
│   └── User Device Registration
│       └── Admin (Device registration events)
```

---

## Getting Help

If issues persist:

1. **Check Microsoft Docs:**
   - [Intune Troubleshooting](https://docs.microsoft.com/en-us/troubleshoot/mem/intune/)
   - [Autopilot Known Issues](https://docs.microsoft.com/en-us/mem/autopilot/known-issues)

2. **Collect logs:**
   ```powershell
   # Export event logs
   wevtutil epl Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin C:\Temp\IntuneEnrollment.evtx
   ```

3. **Community support:**
   - [r/Intune](https://www.reddit.com/r/Intune/)
   - [Microsoft Tech Community](https://techcommunity.microsoft.com/t5/microsoft-intune/ct-p/Microsoft-Intune)

---

**Remember:** Always test in a non-production environment first!
