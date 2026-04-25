# IT Desktop Support Toolkit
**Professional PowerShell Tools for Microsoft Intune & Windows Autopilot Management**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 👨‍💻 About

This repository contains production-ready PowerShell scripts and tools developed for **Microsoft Intune device management** and **Windows Autopilot** deployments. Created by an IT Desktop Support Engineer to streamline common enrollment, troubleshooting, and automation tasks in modern endpoint management environments.

### Key Focus Areas:
- 🖥️ **Intune MDM Enrollment** (manual and automated)
- ✈️ **Windows Autopilot** (Hardware Hash extraction, bulk registration)
- 🔐 **Entra ID (Azure AD)** device management
- 🛠️ **Troubleshooting Tools** for enrollment issues
- 📊 **Reporting & Validation** scripts

---

## 📁 Repository Structure

```
IT-Desktop-Support-Toolkit/
│
├── Scripts/
│   ├── Get-AutopilotHardwareHash.ps1    # Extract Hardware Hash for single device
│   ├── Start-IntuneEnrollment.ps1       # Manual Intune enrollment trigger
│   ├── Register-AutopilotBulk.ps1       # Bulk Autopilot registration
│   └── [More scripts coming soon]
│
├── Documentation/
│   ├── Intune-Enrollment-Guide.md       # Step-by-step enrollment workflows
│   ├── Autopilot-Overview.md            # Autopilot concepts and setup
│   └── Troubleshooting-Common-Issues.md # Common problems and solutions
│
└── Examples/
    └── Real-world use cases and scenarios
```

---

## 🚀 Quick Start

### Prerequisites
- Windows 10 (1809+) or Windows 11
- PowerShell 5.1 or later
- Administrator privileges
- Microsoft Intune subscription
- Entra ID (Azure AD) tenant

### Basic Usage

#### 1. Extract Hardware Hash for Autopilot
```powershell
# Run as Administrator
.\Scripts\Get-AutopilotHardwareHash.ps1

# With custom output path and group tag
.\Scripts\Get-AutopilotHardwareHash.ps1 -OutputPath "C:\Temp" -GroupTag "IT-Department"
```

#### 2. Manual Intune Enrollment
```powershell
# Check enrollment status
.\Scripts\Start-IntuneEnrollment.ps1 -CheckOnly

# Trigger enrollment
.\Scripts\Start-IntuneEnrollment.ps1
```

#### 3. Bulk Autopilot Registration
```powershell
# Register multiple devices
.\Scripts\Register-AutopilotBulk.ps1 -ComputerNames "PC01","PC02","PC03" -GroupTag "Sales"

# From file with credentials
$cred = Get-Credential
$computers = Get-Content .\computers.txt
.\Scripts\Register-AutopilotBulk.ps1 -ComputerNames $computers -Credential $cred
```

---

## 📋 Script Details

### `Get-AutopilotHardwareHash.ps1`
**Purpose:** Extract the 4K Hardware Hash (HWID) required for Windows Autopilot device registration.

**Features:**
- ✅ Automatic module installation
- ✅ CSV export (Intune-compatible format)
- ✅ Group tag support
- ✅ Error handling and validation
- ✅ Timestamped output files

**Use Cases:**
- Manual Autopilot enrollment
- Pre-provisioning devices
- Troubleshooting Autopilot registration issues

---

### `Start-IntuneEnrollment.ps1`
**Purpose:** Manually trigger Intune MDM enrollment for troubleshooting or initial setup.

**Features:**
- ✅ Enrollment status check
- ✅ Entra ID join validation
- ✅ Multi-method enrollment trigger
- ✅ Re-enrollment support
- ✅ Detailed troubleshooting output

**Use Cases:**
- Fixing broken enrollments
- Initial device setup outside Autopilot
- Troubleshooting enrollment failures
- Re-enrolling after domain disjoin

---

### `Register-AutopilotBulk.ps1`
**Purpose:** Collect Hardware Hashes from multiple devices for bulk Autopilot import.

**Features:**
- ✅ Remote device support
- ✅ Credential management
- ✅ Consolidated CSV output
- ✅ Success/failure tracking
- ✅ Parallel processing capable

**Use Cases:**
- Bulk device provisioning
- Large-scale Autopilot deployments
- Remote device registration
- Multi-location deployments

---

## 🎯 Real-World Scenarios

### Scenario 1: New Device Deployment
```powershell
# Extract Hardware Hash during unboxing
.\Get-AutopilotHardwareHash.ps1 -GroupTag "Finance-Dept"

# Upload CSV to Intune portal
# Wait 15 minutes for sync
# Ship device to end user
# User completes OOBE with Autopilot
```

### Scenario 2: Troubleshooting Enrollment Failure
```powershell
# Check current status
.\Start-IntuneEnrollment.ps1 -CheckOnly

# If not enrolled, trigger manually
.\Start-IntuneEnrollment.ps1

# Verify in Intune portal after 10 minutes
```

### Scenario 3: Bulk Office Refresh
```powershell
# Prepare list of computers
$computers = "PC01","PC02","PC03","PC04","PC05"

# Collect all Hardware Hashes remotely
$cred = Get-Credential -Message "Enter domain admin credentials"
.\Register-AutopilotBulk.ps1 -ComputerNames $computers -Credential $cred -GroupTag "Office-Refresh-2024"

# Upload consolidated CSV to Intune
# Schedule deployment
```

---

## 🛠️ Environment & Testing

### Development Environment
- **Primary OS:** Windows 11 Pro
- **Test Environment:** Windows Server 2022 (hwlab.dd domain)
- **Management Platform:** Microsoft 365 Business Premium
- **MDM:** Microsoft Intune
- **Identity:** Entra ID (Azure AD)

### Tested Scenarios
- ✅ Autopilot deployment (User-Driven mode)
- ✅ Manual Intune enrollment
- ✅ Hybrid Entra ID join + Intune
- ✅ Hardware Hash extraction (various OEMs)
- ✅ Bulk registration (10+ devices)

---

## 📚 Documentation

Detailed guides available in the `Documentation/` folder:

- **[Autopilot Overview](Documentation/Autopilot-Overview.md)** - Concepts, setup, and best practices
- **[Troubleshooting Guide](Documentation/Troubleshooting-Common-Issues.md)** - Common issues and solutions

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to:
- 🐛 Report bugs
- 💡 Suggest new scripts or features
- 📖 Improve documentation
- ⭐ Star this repo if you find it useful

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🔗 Useful Resources

### Official Microsoft Documentation
- [Windows Autopilot Documentation](https://docs.microsoft.com/en-us/mem/autopilot/)
- [Microsoft Intune Documentation](https://docs.microsoft.com/en-us/mem/intune/)
- [Entra ID Device Management](https://docs.microsoft.com/en-us/azure/active-directory/devices/)

### PowerShell Modules
- [Microsoft.Graph.Intune](https://www.powershellgallery.com/packages/Microsoft.Graph.Intune)
- [WindowsAutoPilotIntune](https://www.powershellgallery.com/packages/WindowsAutoPilotIntune)

### Community Resources
- [r/Intune Subreddit](https://www.reddit.com/r/Intune/)
- [Microsoft Tech Community - Intune](https://techcommunity.microsoft.com/t5/microsoft-intune/ct-p/Microsoft-Intune)

---

## 📧 Contact

**Author:** Hesh  
**Role:** IT Desktop Support Engineer  
**Focus:** Microsoft 365, Intune MDM, Windows Autopilot, Entra ID  
**Location:** Germany 🇩🇪

---

## ⚡ Changelog

### v1.0.0 (2024-04-25)
- Initial release
- Added Hardware Hash extraction script
- Added manual Intune enrollment script
- Added bulk Autopilot registration script
- Comprehensive documentation and examples

---

**Built with ❤️ for IT professionals managing modern Windows endpoints**
