# The 5K iMac display path

[繁體中文](../zh-TW/02-5k-imac-display.md) · [Home](../../README.md)

**Tested:** OCLP's dual DisplayPort workaround enters OpenCore through an Apple Diagnostics loader and places its launcher at `.diagnostics/Drivers/HardwareDrivers/Product.efi`. The goal is to keep the firmware's two-stream 5K mode. This mechanism was originally demonstrated on another iMac generation; applicability to each model needs measurement. [Original research](https://khronokernel.github.io/macos/2021/12/08/5K-UEFI.html), [OCLP implementation](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/opencore_legacy_patcher/efi_builder/firmware.py), [OCLP PR #777](https://github.com/dortania/OpenCore-Legacy-Patcher/pull/777).

On **iMac19,1**, the OpenCore picker appeared at 5K, but selecting Sequoia, safe mode or the Tahoe installer stopped after the boot handoff, before any `-v` text. Removing that diagnostics path and using the ordinary `LauncherPath=Default` path allowed Tahoe to boot, but the physical output stayed at 4K. OpenCore 1.0.9, `TextRenderer=SystemGraphics`, and `DirectGopRendering=true` did not fix the diagnostics-path hang in the recorded trials. **Inference:** The hang is associated with that path; its exact failing instruction is unknown. The last DEBUG line is not proof of where execution stopped.

On **iMac17,1 #1**, an OCLP 3.0 EFI using the diagnostics path booted both Sequoia and Tahoe at physical 5K. This comparison rejects the idea that the OCLP 3.0 APFS driver change alone always causes this hang; it does not identify the iMac19,1 cause. A different Diagnostics module such as `Fan.efi` is an **untested idea**, not a fix.

## Measure actual output

**Tested:** `system_profiler SPDisplaysDataType` can report a Retina 5K panel or 5120 × 2880 even while the iMac19,1 is physically running its 4K path. Record the IORegistry `IOFBCurrentPixelCount` on the same boot:

```sh
ioreg -lw0 | grep IOFBCurrentPixelCount
```

The recorded 5K path reported **15,639,360** pixels (5280 × 2962 framebuffer), and the 4K path **8,888,000** (4000 × 2222). These framebuffer counts include timing or padding and are not the panel's advertised active resolution. Compare them with the display's reported mode, framebuffer topology and a known-good boot. A scaled “looks like” setting is insufficient evidence of physical 5K.

On both iMac17,1 machines running the OCLP 3.0 EFI with the diagnostics path, the check reads **15,639,360** (5K):

![Terminal on iMac17,1 #1 showing sw_vers 26.7.1 and IOFBCurrentPixelCountReal = 15639360](../images/imac17-1-no1-terminal-pixelcount-5k.png)

*iMac17,1 #1, macOS 26.7.1: `IOFBCurrentPixelCountReal = 15639360`.*

![Terminal on iMac17,1 #2 showing sw_vers 26.7.1 and IOFBCurrentPixelCountReal = 15639360](../images/imac17-1-no2-terminal-pixelcount-5k.png)

*iMac17,1 #2, macOS 26.7.1: `IOFBCurrentPixelCountReal = 15639360`.*

On the iMac19,1 running the working (non-diagnostics) path, the same check reads **8,888,000**, which is the 4K figure:

![Terminal on the iMac19,1 showing sw_vers 26.7.1 and IOFBCurrentPixelCountReal = 8888000](../images/imac19-1-terminal-pixelcount-4k.png)

*iMac19,1, macOS 26.7.1: `IOFBCurrentPixelCountReal = 8888000` (4K). The iMac17,1 machines read 15639360 (5K) on the same OCLP release.*

**Unresolved:** We have no tested iMac19,1 route that both boots Tahoe and retains physical 5K. Keep a working EFI and compare one variable per test.
