# Windows Autopilot Overview

A comprehensive guide to understanding and implementing Windows Autopilot for modern device deployment.

---

## What is Windows Autopilot?

Windows Autopilot is a cloud-based deployment technology that allows organizations to:
- ✅ Deploy new devices with zero-touch provisioning
- ✅ Pre-configure devices before users receive them
- ✅ Reset and repurpose existing devices
- ✅ Eliminate traditional imaging and manual setup

**Key Benefit:** Users unbox a device, connect to WiFi, sign in with their organizational account, and Autopilot automatically configures everything.

---

## Deployment Scenarios

### 1. User-Driven Mode (Most Common)
**Use Case:** Standard employee laptops/desktops

**Flow:**
1. User unboxes device
2. Connects to WiFi
3. Signs in with work account (user@company.com)
4. Autopilot automatically:
   - Joins device to Entra ID
   - Enrolls in Intune
   - Applies policies and apps
   - Configures settings
5. User lands on desktop, ready to work

**Best For:** Remote workers, BYOD scenarios, distributed teams

---

### 2. Self-Deploying Mode
**Use Case:** Shared devices, kiosks, digital signage

**Flow:**
1. Device boots up
2. Automatically connects to network (Ethernet)
3. Enrolls without ANY user interaction
4. Configured as shared device
5. Ready for use

**Best For:** Conference rooms, reception kiosks, shared workstations

---

### 3. Pre-Provisioning (White Glove)
**Use Case:** IT pre-configures devices before shipping

**Flow:**
1. IT technician unboxes device
2. Initiates pre-provisioning process
3. Device downloads apps, policies, updates
4. IT verifies, seals device, ships to user
5. User completes minimal setup

**Best For:** Executives, complex configurations, slow networks at user location

---

## Prerequisites

### Licensing Requirements
- ✅ **Intune License** (included in M365 Business Premium, E3, E5)
- ✅ **Entra ID Premium P1 or P2** (for dynamic groups, Conditional Access)
- ✅ **Windows 10 Pro/Enterprise** (1809+) or **Windows 11**

### Network Requirements
- Internet connectivity during OOBE
- Access to Microsoft services (no firewall blocking)
- Required URLs must be accessible

### Device Requirements
- ✅ UEFI-based (not legacy BIOS)
- ✅ TPM 2.0 enabled
- ✅ Windows 10 version 1809 or later
- ✅ No existing Windows installation (or factory reset)

---

## Setup Process

### Step 1: Register Devices

**Option A: OEM Direct (Easiest)**
- Purchase devices from Microsoft Cloud Solution Provider (CSP)
- OEM automatically registers devices to your Autopilot
- No manual work required

**Option B: Manual Registration (This Toolkit)**
- Extract Hardware Hash using our scripts
- Upload CSV to Intune portal
- Wait 15-30 minutes for sync

```powershell
# Single device
.\Scripts\Get-AutopilotHardwareHash.ps1

# Multiple devices
.\Scripts\Register-AutopilotBulk.ps1 -ComputerNames "PC01","PC02","PC03"
```

---

### Step 2: Create Autopilot Profile

**In Intune Portal:**
1. Navigate to: **Devices > Windows > Windows enrollment > Deployment profiles**
2. Click **Create profile > Windows PC**
3. Configure:

**Basic Settings:**
- Name: "Standard User Deployment"
- Mode: User-Driven
- Join type: Entra ID joined

**OOBE Settings:**
- ✅ Show organization branding
- ✅ Hide privacy settings (optional)
- ✅ Hide change account options
- ✅ User license agreement (EULA) - Auto accept
- ❌ Allow local admin (security best practice)

**Assignments:**
- Assign to device group or all Autopilot devices

---

### Step 3: Create Device Group (Optional but Recommended)

**Dynamic Group Example:**
```
Group Name: All Autopilot Devices
Membership type: Dynamic Device
Rule:
(device.devicePhysicalIDs -any (_ -contains "[ZTDId]"))
```

This automatically includes all Autopilot-registered devices.

---

### Step 4: Assign Apps & Policies

**Required Assignments:**
- Configuration profiles (WiFi, VPN, security)
- Compliance policies
- Required apps (Office, Teams, company apps)

**Assign to:** Your Autopilot device group

**Important:** Mark critical apps as "Required" so they install during Autopilot.

---

## The Autopilot Experience

### What Users See (User-Driven Mode):

1. **Welcome Screen**
   - Company branding displayed
   - Select region and keyboard

2. **Network Connection**
   - Connect to WiFi or Ethernet

3. **Sign-In**
   - Enter work email (user@company.com)
   - Enter password
   - Complete MFA if required

4. **Enrollment Phase**
   - "Setting up your device for work"
   - Progress bar showing:
     - Device preparation
     - Device setup
     - Account setup

5. **Desktop**
   - User lands on configured desktop
   - Apps installing in background
   - Ready to work!

**Total Time:** 15-30 minutes (depending on apps/policies)

---

## Hardware Hash Explained

### What is a Hardware Hash?

The Hardware Hash (also called 4K Hardware Hash or HWID) is a **unique identifier** derived from:
- Motherboard serial number
- BIOS details
- TPM information
- Network adapter MAC address
- Disk serial numbers

It's a **4096-byte signature** that uniquely identifies the physical device.

### Why It's Important

- Allows Microsoft to recognize the device during OOBE
- Links physical hardware to your Autopilot profile
- Enables zero-touch deployment
- Cannot be duplicated or faked

### How to Extract It

**Using Our Scripts:**
```powershell
# Single device
.\Scripts\Get-AutopilotHardwareHash.ps1

# Output: CSV file with Hardware Hash ready for Intune upload
```

**Manual Method (Built-in):**
```powershell
# Install module
Install-Script -Name Get-WindowsAutopilotInfo

# Extract
Get-WindowsAutopilotInfo.ps1 -OutputFile AutopilotHWID.csv
```

---

## Group Tags

Group Tags are **custom labels** you can assign during device registration.

**Use Cases:**
- Department assignment ("Finance", "Sales", "IT")
- Location tagging ("HQ", "Branch-1", "Remote")
- Device type ("Laptop", "Desktop", "Tablet")
- Configuration profile ("StandardUser", "PowerUser", "Kiosk")

**How to Use:**
```powershell
# Add group tag during Hardware Hash extraction
.\Scripts\Get-AutopilotHardwareHash.ps1 -GroupTag "IT-Department"
```

**In Intune:**
- Create dynamic groups based on group tags
- Assign specific policies/apps to tagged devices
- Simplifies large-scale deployments

**Example Dynamic Group Rule:**
```
(device.enrollmentProfileName -eq "Autopilot") -and (device.devicePhysicalIds -any (_ -eq "[OrderId]:IT-Department"))
```

---

## Best Practices

### 1. Test First
- ✅ Create test Autopilot profile
- ✅ Register 1-2 test devices
- ✅ Verify complete flow before production rollout

### 2. Plan App Deployment
- ✅ Only mark critical apps as "Required" during Autopilot
- ✅ Use "Available" for optional apps (faster deployment)
- ✅ Test app installation times

### 3. Use Enrollment Status Page (ESP)
- ✅ Enable ESP to show installation progress
- ✅ Prevents users from skipping setup
- ✅ Configure timeout appropriately (60-90 minutes)

### 4. Monitor and Troubleshoot
- ✅ Check Intune > Devices > Monitor > Enrollment failures
- ✅ Review Autopilot deployment reports
- ✅ Set up alerts for failures

### 5. Maintain Device Hygiene
- ✅ Remove old/retired devices from Autopilot
- ✅ Update Hardware Hashes if motherboard replaced
- ✅ Regular sync checks

---

## Common Scenarios

### Scenario: New Employee Onboarding
1. Order device from OEM (auto-registers to Autopilot)
2. Ship directly to employee's home
3. Employee receives device, connects to WiFi, signs in
4. Autopilot configures everything
5. Employee productive in 30 minutes

**No IT involvement needed!**

---

### Scenario: Device Refresh/Replacement
1. Extract Hardware Hash from new device
2. Upload to Intune
3. Assign same group tag as old device
4. Dynamic group membership triggers
5. New device gets same policies/apps as old one

---

### Scenario: Lost/Stolen Device
1. Intune > Devices > Wipe
2. Device removed from user's account
3. Device auto-removed from Autopilot (optional)
4. Order replacement
5. Repeat deployment

---

## Troubleshooting Quick Reference

| Error | Likely Cause | Solution |
|-------|--------------|----------|
| 0x80180014 | No Autopilot profile assigned | Assign profile, wait 15 min, retry |
| 0x800705b4 | Network/firewall issue | Check required URLs accessible |
| 0x801c0003 | Device already joined | Reset device, try again |
| Red screen during OOBE | Various | Press Shift+F10, check logs |
| "Not assigned" message | Hardware Hash not synced | Wait 30 min or re-upload CSV |

**Full troubleshooting:** See [Troubleshooting-Common-Issues.md](Troubleshooting-Common-Issues.md)

---

## Required URLs (Firewall Whitelist)

Ensure these Microsoft services are accessible:

```
# Authentication
login.microsoftonline.com
login.windows.net

# Enrollment
enrollment.manage.microsoft.com
portal.manage.microsoft.com

# Device Management
*.manage.microsoft.com
*.microsoftonline-p.com

# Windows Update
*.windowsupdate.com
*.delivery.mp.microsoft.com

# Licensing
licensing.mp.microsoft.com

# Telemetry (optional but recommended)
*.events.data.microsoft.com
```

---

## Resources

### Official Documentation
- [Autopilot Overview](https://docs.microsoft.com/en-us/mem/autopilot/windows-autopilot)
- [Autopilot Requirements](https://docs.microsoft.com/en-us/mem/autopilot/windows-autopilot-requirements)
- [Deployment Scenarios](https://docs.microsoft.com/en-us/mem/autopilot/tutorial/autopilot-scenarios)

### Community
- [r/Intune](https://www.reddit.com/r/Intune/)
- [Microsoft Tech Community](https://techcommunity.microsoft.com/t5/microsoft-intune/ct-p/Microsoft-Intune)

### Tools
- [Get-WindowsAutopilotInfo Script](https://www.powershellgallery.com/packages/Get-WindowsAutopilotInfo)
- [Autopilot Diagnostics](https://docs.microsoft.com/en-us/mem/autopilot/troubleshoot-device-enrollment)

---

**Ready to get started? Use our scripts in the `/Scripts` folder to begin your Autopilot journey!**
