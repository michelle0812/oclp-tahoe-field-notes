# Tahoe on three original Intel Macs: OCLP field notes

[繁體中文](README.zh-TW.md)

<!-- zh-begin -->
<details>
<summary><b>🇹🇼 繁體中文版（點此展開）</b></summary>

這份筆記記錄三台原廠 Apple Mac 透過 OpenCore Legacy Patcher（OCLP）執行 macOS Tahoe 26.7.1（25G241）的過程。這是有日期的實機紀錄，並非適用所有配置的安裝保證。文中以**實測**標示當機觀察，**推論**與**未驗證**則明確區分。狀態日期：2026 年 10 月 18 日。

| 機型 | 實際結果 | 未解問題 |
| --- | --- | --- |
| MacBookPro11,5（2015，15 吋） | Tahoe 與 root patch 後的圖形加速；先還原補丁後完成遷移 | 已安裝的系統沒有已知問題；遷移輔助程式需要「先還原、再重打補丁」的流程 |
| iMac17,1 #1（2015，5K） | Tahoe、圖形加速、實體 5K，手動還原帳號 | Broadcom Wi-Fi 無法上電：Tahoe、Sequoia、High Sierra 安裝環境皆然；原生 High Sierra 顯示射頻校準失敗，網卡故障是目前的解釋 |
| iMac17,1 #2（2015，5K，i5-6500，Radeon R9 M380） | 乾淨安裝 Tahoe，OCLP root patch 自動套用，實體 5K，Wi-Fi 可用，以手動還原腳本還原帳號 | 目前沒有觀察到問題（Command Line Tools 需另外安裝） |
| iMac19,1（2019，5K） | 移除診斷開機繞路後，Tahoe 可開機，圖形、Wi-Fi 與補丁後音效可用 | 診斷繞路會卡住；可開機的路徑只有實體 4K |

## 已知問題一覽

| 面向 | 受影響機型 | 狀態 |
| --- | --- | --- |
| **5K／4K 輸出** | iMac19,1（2019） | 讓畫面維持 5K 的 OCLP 診斷開機繞路在這台會卡住；能開進 Tahoe 的路徑只有實體 4K。未解。[細節](docs/zh-TW/02-5k-imac-display.md) |
| **Broadcom Wi-Fi 無法上電** | 只有 iMac17,1 #1 | 網卡 ID、EFI、補丁記錄都相同的第二台 iMac17,1 **可以用**。第一台在試過的每個 macOS 都失敗，包括沒有 OpenCore 的原生 High Sierra 安裝程式：原廠驅動回報射頻校準失敗與韌體反覆當機，網卡故障是目前的解釋。[細節](docs/zh-TW/05-tahoe-wifi.md) |
| **除了遷移之外沒有已知問題** | MacBookPro11,5（2015） | 沒有觀察到其他問題。 |
| **遷移輔助程式在三台都有麻煩** | 三台全部 | 每台都有兩個前置條件：要先建立臨時管理員帳號，而且遷移期間不能有 root patch（要先還原）。有補丁的機器會在遷移模式反覆重開，沒打補丁的 5K iMac 又撐不住桌面。已整理檢查清單與手動還原替代方案。[遷移](docs/zh-TW/03-migration-assistant.md)、[手動還原](docs/zh-TW/04-restore-without-migration-assistant.md) |

列出兩台 iMac17,1，是為了區分已測機器與後續計畫。[機器細節](docs/zh-TW/01-machines-and-results.md)記載證據範圍。

## 文件索引

1. [機型與結果](docs/zh-TW/01-machines-and-results.md)
2. [5K iMac 顯示路徑](docs/zh-TW/02-5k-imac-display.md)
3. [遷移輔助程式與核心快取](docs/zh-TW/03-migration-assistant.md)
4. [不靠遷移輔助程式的手動還原](docs/zh-TW/04-restore-without-migration-assistant.md)
5. [iMac17,1 的 Broadcom Wi-Fi：一台能用、一台不能用（進行中）](docs/zh-TW/05-tahoe-wifi.md)
6. [技巧與踩坑](docs/zh-TW/06-tips-and-pitfalls.md)
7. [還原腳本](scripts/README.zh-TW.md)

每份中文文件皆連到對應英文版。[OCLP 發行說明](https://github.com/dortania/OpenCore-Legacy-Patcher/releases/tag/3.0.0-rc.3)也明示 Tahoe 預覽版可能不穩定並造成資料遺失。

## 風險與交流

Apple 不支援這些機型安裝 Tahoe。可能無法開機、遺失資料或使服務失效。修改 EFI、APFS 卷宗、root patch 或帳號之前，請製作並驗證獨立備份。**使用本筆記與腳本，風險由使用者自負。**保留已知可開機的路徑與復原方案。歡迎透過 GitHub Issues 或 Discussions 提供更正與可重現的結果。

## 授權

文件採 [CC BY 4.0](docs/LICENSE-CC-BY-4.0.md)，腳本採 [MIT](LICENSE)。連結的外部專案各依自身授權。本倉庫是獨立實戰紀錄，與 Apple、Dortania 或其他連結專案無隸屬關係。

（也可以直接開啟[完整的繁體中文首頁](README.zh-TW.md)。）

</details>
<!-- zh-end -->

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
