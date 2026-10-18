# Tahoe on three original Intel Macs: OCLP field notes

[繁體中文](README.zh-TW.md)

These notes record hands-on attempts to run macOS Tahoe 26.7.1 (25G241) on three original Apple Macs with OpenCore Legacy Patcher (OCLP). They are a dated field report, not an installation recipe that has been validated on every configuration. **Tested** means observed on the named machine; **inference** and **unverified** are called out explicitly. Status: 18 October 2026.

| Machine | Observed result | Open issue |
| --- | --- | --- |
| MacBookPro11,5 (2015, 15-inch) | Tahoe and accelerated graphics after root patch; Migration Assistant completed after reverting the patch first | No known issue on the installed system; Migration Assistant needs the revert / re-patch sequence |
| iMac17,1 #1 (2015, 5K) | Tahoe, accelerated graphics, physical 5K, and a manually restored account | Broadcom Wi-Fi never powers on, in Tahoe, Sequoia or a High Sierra installer's environment; native High Sierra shows the radio failing calibration, so a faulty card is the working explanation |
| iMac17,1 #2 (2015, 5K, i5-6500, Radeon R9 M380) | Clean Tahoe install with the OCLP root patch applied automatically, physical 5K, Wi-Fi works, account restored with the manual restore script | None observed so far (Command Line Tools must be installed separately) |
| iMac19,1 (2019, 5K) | Tahoe boots with graphics, Wi-Fi and patched audio when the diagnostics boot path is removed | That boot path hangs; the working path outputs physical 4K |

## Known issues at a glance

| Area | Affected | Status |
| --- | --- | --- |
| **5K vs 4K output** | iMac19,1 (2019) | The OCLP diagnostics boot path that keeps 5K hangs on this Mac; the path that boots Tahoe gives physical 4K. Unresolved. [Details](docs/en/02-5k-imac-display.md) |
| **Broadcom Wi-Fi never powers on** | iMac17,1 #1 only | The second iMac17,1 with the same card ID, EFI and patch record **works**. The first fails in every macOS tried, including a native High Sierra installer without OpenCore, where the stock driver reports a radio calibration failure and repeated firmware crashes: a faulty card is the working explanation. [Details](docs/en/05-tahoe-wifi.md) |
| **Nothing known beyond migration** | MacBookPro11,5 (2015) | No other issue observed. |
| **Migration Assistant is troublesome on all of them** | All three | Two prerequisites apply everywhere: create a temporary administrator first, and have no root patch applied while migrating (revert it first). Patched machines reboot-loop in migration mode, while an unpatched 5K iMac cannot keep the desktop alive. A checklist and a manual-restore alternative are documented. [Migration](docs/en/03-migration-assistant.md), [manual restore](docs/en/04-restore-without-migration-assistant.md) |

The two iMac17,1 entries are included to distinguish a tested machine from a planned follow-up. [Machine details](docs/en/01-machines-and-results.md) give the precise evidence limits.

## Read the notes

1. [Machines and results](docs/en/01-machines-and-results.md)
2. [5K iMac display path](docs/en/02-5k-imac-display.md)
3. [Migration Assistant and kernel collections](docs/en/03-migration-assistant.md)
4. [Manual restore without Migration Assistant](docs/en/04-restore-without-migration-assistant.md)
5. [Broadcom Wi-Fi on iMac17,1: one works, one does not (in progress)](docs/en/05-tahoe-wifi.md)
6. [Tips and pitfalls](docs/en/06-tips-and-pitfalls.md)
7. [Restore scripts](scripts/README.md)

Each English page links to its matching Traditional Chinese page. [OCLP's release notes](https://github.com/dortania/OpenCore-Legacy-Patcher/releases/tag/3.0.0-rc.3) describe the Tahoe prerelease and its data-loss risk.

## Risk and discussion

Apple does not support these Tahoe installations on these models. Boot failure, data loss and broken services are possible. Make and verify independent backups before changing an EFI, APFS volume, root patch or account. **Use these notes and scripts at your own risk.** Keep a known-good boot path and recovery plan. Contributions, corrections and reproducible results are welcome through GitHub Issues or Discussions.

## License

Documentation is licensed under [CC BY 4.0](docs/LICENSE-CC-BY-4.0.md). Scripts are licensed under [MIT](LICENSE). External projects linked here retain their own licenses. This repository is an independent field report and is not affiliated with Apple, Dortania or the other linked projects.
