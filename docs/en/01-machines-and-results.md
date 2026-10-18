# Machines and results

[繁體中文](../zh-TW/01-machines-and-results.md) · [Home](../../README.md)

All observations below are from macOS Tahoe 26.7.1 (25G241) in October 2026 unless stated otherwise. A reported OCLP version describes the build used in the experiment, not an endorsement of later releases. OCLP 3.0.0-rc.3 is a [prerelease](https://github.com/dortania/OpenCore-Legacy-Patcher/releases/tag/3.0.0-rc.3).

| Model | GPU / OCLP and OpenCore | Tested | Unresolved or unverified |
| --- | --- | --- | --- |
| MacBookPro11,5, 2015 15-inch | Radeon R9 M370X; OCLP 3.0.0-rc.3 | Tahoe booted with root-patched graphics; Migration Assistant completed after reverting patches first | Patched migration rebooted repeatedly; not every app and service was checked |
| iMac17,1 #1, 2015 5K | Radeon R9 M395; OCLP 3.0.0-rc.3 build, later OpenCore 1.0.9 | Tahoe booted with graphics acceleration and physical 5K; manual account restore v2.1 completed and login was checked | Broadcom Wi-Fi remains `Off (forced)`; no successful Migration Assistant route on this 5K setup |
| iMac17,1 #2, 2015 5K | Radeon R9 M380 (i5-6500); same OCLP 3.0.0-rc.3 + OpenCore 1.0.9 EFI as #1 | Clean Tahoe install with automatic root patch; physical 5K (`IOFBCurrentPixelCount` 15,639,360); Wi-Fi powers on and scans; manual restore v3 of an account completed | Command Line Tools are not part of a restore and must be installed separately |
| iMac19,1, 2019 5K | Radeon Pro Vega 48; OCLP 3.0.0, later OpenCore 1.0.9 | Tahoe booted with native graphics and Wi-Fi; Modern Audio root patch restored built-in speaker output | Diagnostics boot path hangs before verbose output; working boot path produces physical 4K; 5K unresolved |

**Tested:** On iMac19,1, the Vega GPU did not require a graphics root patch, while audio did. OCLP's then-current model data treated this Mac as natively supported for the newest OS, so it did not automatically relax SIP or include AMFIPass for the audio patch. The local EFI was adjusted, and those changes had to be reapplied after an OCLP rebuild. These are configuration-specific observations, not general OCLP instructions. [OCLP model data](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/opencore_legacy_patcher/datasets/smbios_data.py).

**Evidence boundary:** “5K” below means measured framebuffer output, not a scaled user-interface label. [Display measurement](02-5k-imac-display.md), [migration](03-migration-assistant.md), [restore](04-restore-without-migration-assistant.md), and [Wi-Fi](05-tahoe-wifi.md) contain the observed failures and remaining questions.

## Screenshots

System Settings → General → About on macOS Tahoe 26.7.1 (25G241), October 2026. The device name and serial number fields are blank in the images.

![About This Mac on an iMac (Retina 5K, 27-inch, Late 2015) with Core i5 and Radeon R9 M380, macOS Tahoe 26.7.1](../images/imac17-1-no2-about-this-mac-tahoe.png)

*iMac17,1 #2: Core i5, Radeon R9 M380 2 GB, macOS Tahoe 26.7.1.*

![About This Mac on a MacBook Pro (Retina, 15-inch, Mid 2015) with Core i7, Radeon R9 M370X and Iris Pro, macOS Tahoe 26.7.1](../images/macbookpro11-5-about-this-mac-tahoe.png)

*MacBookPro11,5: Core i7, Radeon R9 M370X 2 GB plus Intel Iris Pro, macOS Tahoe 26.7.1.*

![About This Mac on an iMac (Retina 5K, 27-inch, Late 2015) with Core i7 and Radeon R9 M395, macOS Tahoe 26.7.1](../images/imac17-1-no1-about-this-mac-tahoe.png)

*iMac17,1 #1: Core i7, Radeon R9 M395 2 GB, macOS Tahoe 26.7.1.*

![About This Mac on an iMac (Retina 5K, 27-inch, 2019) with Core i9 and Radeon Pro Vega 48, macOS Tahoe 26.7.1; the display line reads 3840 x 2160](../images/imac19-1-about-this-mac-tahoe.png)

*iMac19,1: Core i9, Radeon Pro Vega 48 8 GB, macOS Tahoe 26.7.1. Here the display line already reads 3840 × 2160, matching the 4K output measured in the [display notes](02-5k-imac-display.md).*

**Caution:** The display line in About This Mac shows the panel's specification, not the signal actually being sent. On the 5K iMacs, confirm real output with the IORegistry measurement in [the display notes](02-5k-imac-display.md).
