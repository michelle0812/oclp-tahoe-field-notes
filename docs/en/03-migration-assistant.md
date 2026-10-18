# Migration Assistant and patched kernel collections

[繁體中文](../zh-TW/03-migration-assistant.md) · [Home](../../README.md)

## Checklist: the two prerequisites

On every OCLP machine in these notes, using Migration Assistant meant meeting two conditions first. Missing either one cost time on at least one of the machines.

1. **Create a temporary administrator first.** In Setup Assistant do **not** migrate; create a throwaway account (for example `tempadmin`) and sign in. This gives you a working account that survives a failed migration and lets you run OCLP and SSH commands.
2. **Have no OCLP root patch applied during the migration.** If the machine is already patched, use OCLP **Revert Root Patches** and reboot before starting. Re-apply the patch from the temporary administrator afterwards (`--patch_sys_vol`).

**Tested:** the MacBookPro11,5 completed Migration Assistant this way. The iMac19,1 migrated its account before any root patch was applied, which is the same condition. **Why it is a trap:** the Radeon GPUs on the iMac17,1 and the MacBookPro11,5 cannot render Tahoe's first-run screens without the patch, and an unpatched 5K iMac17,1 could not keep WindowServer alive through a full migration, so the two conditions pull against each other. [The restore alternative](04-restore-without-migration-assistant.md) exists for that case.


**Tested on MacBookPro11,5:** Migration Assistant reboots into `bootMode='migration'`, using a Preboot `com.apple.Boot.plist` containing `-bsdmgroot`. With OCLP root patches installed, the observed verbose boot showed `RSRHelper` reporting a kernel-collection (KC) UUID mismatch and rebooting repeatedly. Reverting the patches before migration, rebooting, then reapplying them afterward completed the migration. [OCLP Time Machine guidance](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/docs/TIMEMACHINE.md) also describes the revert/repatch route.

The working sequence on that laptop was: create a temporary administrator without migrating in Setup Assistant; use OCLP **Revert Root Patches** and reboot; start Migration Assistant from the desktop; after the transfer, run OCLP's `--patch_sys_vol` from the temporary administrator if the mini setup screen cannot render; reboot and verify the migrated account. The Radeon R9 M370X could not render the initial Tahoe setup screen without acceleration, so “never patch until migration finishes” was not a workable initial-install sequence on that machine. Check the exact installed OCLP executable path and flags for your version before using its CLI. [OCLP post-install guide](https://dortania.github.io/OpenCore-Legacy-Patcher/POST-INSTALL.html).

**Tested on iMac17,1 #1:** With patches reverted, its unaccelerated 5K WindowServer was killed by a watchdog during Migration Assistant. With patches present, migration copied files at the desktop stage but the migration-mode boot looped. This machine did **not** show a conclusive `RSRHelper` mismatch line, so assigning the same root cause as the laptop remains an **inference**. Booting normally after removing the migration boot plist cleared the temporary migration sandbox; the result was an empty account, not recovered data. **Do not remove that boot plist as a way to complete a pending migration.** Recreate the migration from an intact source if its sandbox is gone.

**Inference from [XNU KC dependency checks](https://github.com/apple-oss-distributions/xnu) and a read-only comparison:** Replacing only `BootKernelExtensions.kc` is unsafe. The patched System and Auxiliary collections depend on its UUID; `-nokcmismatchpanic` does not guarantee a valid collection chain or migration completion. No KC replacement procedure was validated on this iMac. `-bsdmgroot` and a later BaseSystem pivot also do not prove which absolute KC path Tahoe's `boot.efi` loaded; [XNU's image boot code](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/bsd_init.c) is mechanism evidence, not a trace of this boot.

**Tested network pitfall:** A network Time Machine source was reached over slow Wi-Fi at about 3.7 MB/s until the source used wired networking, when transfer reached roughly 123–158 MB/s in that trial. Confirm the actual route before starting; changing the source interface mid-transfer did not make the existing SMB session reconnect. These rates are observations from one setup, not expected performance.
