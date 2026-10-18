# iMac17,1 的 Broadcom Wi-Fi：一台能用、完全相同的另一台不能用（進行中）

[English](../en/05-tahoe-wifi.md) · [首頁](../../README.zh-TW.md)

兩台 iMac17,1（2015，5K）裝著同一種 Broadcom 網卡（`pci14e4,43ba`、子系統 `106b:14a`、BCM43602），使用**位元組完全相同**的 OpenCore 1.0.9 EFI 與同一版 OCLP 3.0.0-rc.3 root patch，跑 macOS Tahoe 26.7.1。**B 機**的 Wi-Fi 可以上電、掃描、連線；**A 機**顯示 `Off (forced)`，`APPLE80211_IOC_POWER` 回傳 `-1`。本頁記錄試過什麼、排除了什麼、還有什麼沒解。狀態日期：2026 年 10 月 18 日。**實測**表示在該機器上親眼觀察；**推論**會明確標出。

## 不能用的機器發生了什麼

時間線是從 unified log 還原的，管理員帳號不用 root 就讀得到（見[重現時間線](#重現時間線)）。時間為開機後的秒數，超過五次開機都一模一樣：

| 時間 | A 機的事件 |
| --- | --- |
| T+10 秒 | `ARPT` 做一次 D0 → D3 → D0（`setPCIPowerState(OFF)`，接著 `(ON)`），這一次成功。 |
| **T+20 秒** | `ARPT` 再次進入 D3，**之後整個開機都沒有 `setPCIPowerState(ON)`。** |
| T+24～35 秒 | 核心重複 87～101 次 `nub ARPT is not powered, retrying matching in 100ms` 後停止；節點多出 `IOPCIDevicePublishRetryTimeout = Yes`。 |
| T+25 秒 | `airportd` 要求上電，`APPLE80211_IOC_POWER` 回傳 `-1`；`networksetup -getairportpower en1` 顯示 `Off (forced)`。 |

在 IORegistry 裡，網卡的驅動物件存在且是 `matched, active`，但驅動通常會讀到的晶片欄位（`chipnum`、`chiprev`、`corerev`、`boardid`、`boardrev`）全是空的，`IOLinkSpeed` 是 `0`，`TruePowerOff = Yes`。PCIe 連結本身有訓練起來（x1、2.5 GT/s）。

## 能用的機器長什麼樣

B 機沒有上述任何電源事件，沒有 `IOC_POWER` 失敗，`Wi-Fi Power: On`，`status: active`（已連上 5 GHz 網路），CoreWLAN 掃描有結果，也讀得到晶片欄位：`chipnum 0xaa52`（BCM43602）、`chiprev 1`、`corerev 0x31`、`boardid 0x14a`、`boardrev 0x1114`、`IOLinkSpeed 11000000`。帳號還原與使用者登入之後仍然正常。

## 身分比對（兩台完全相同）

- PCI：廠商 `14e4`、裝置 `43ba`、**修訂版本 `01`**、子系統 `106b:14a`、類別 `028000`、相同的 ACPI 路徑（`_SB/PCI0/RP01/ARPT`）、相同的 BAR 配置，以及同一顆 Intel 根埠（`8086:a110`，修訂 `f1`）與相同的連結能力。
- 載入的 kext：`IOSkywalkFamily 1.0`、`IO80211FamilyLegacy 1200.12.2b1`、`AirPort.BrcmNIC 1400.1.1`，UUID 一致。
- OCLP Modern Wireless 補丁放進系統卷宗的檔案（`wifip2pd`、`IO80211` 與 `WiFiPeerToPeer` framework 及其 `Old` 函式庫）：SHA-256 相同。
- Boot 與 System 核心快取：SHA-256 相同。輔助核心快取不同（本來就是每台自建的），但列出的擴充套件與 UUID 一致，且不含 Wi-Fi 驅動。
- OCLP 補丁記錄：除了時間戳，逐行相同。
- EFI：A 機的內建 EFI 與在 B 機能用的 EFI 逐位元組相同（175 個檔案）。

**晶片與板子欄位**（`chipnum`、`chiprev`、`corerev`、`boardid`、`boardrev`）在 A 機的 Tahoe 下讀不到，因為驅動走不到那一步；但在原生 High Sierra 安裝程式下讀得到，而且**跟 B 機完全相同**，所以兩張卡是同一型號、同一修訂。

## 在不能用的機器上做過的實驗

| 實驗 | 結果 |
| --- | --- |
| 只改 `DisableIoMapper=true`（外接 EFI） | 核心 panic：`IONVMeController::CommandTimeout`、`nvme: Controller fatal bit set`、`Still waiting for root device`。它的第三方內建 NVMe 位於 AppleVTD 的裝置 mapper 之下，所以全域改動 IOMapper 在這台不安全。**這不能證明 AppleVTD 是 Wi-Fi 故障原因。** |
| 能用 EFI 的複本、只換 Lilu 1.7.2 | 可開機；Lilu 1.7.2 已載入；Wi-Fi 不變。 |
| 同一 EFI 再加 [BroadcomVTD-Tahoe](https://github.com/kgp-macPro/BroadcomVTD-Tahoe) v0.2.17 | 可開機；外掛已載入；狀態由 `Off (forced)` 變成單純的 `Off`，系統資訊列出網卡韌體與頻道；上電仍失敗。外掛是否進入修正模式**未知**：它的紀錄是 opaque sysctl（`debug.broadcomvtd`），`sysctl -a` 不會列出，尚未擷取。 |
| 重建網路組態（移開 `NetworkInterfaces.plist`、`preferences.plist`、airport 偏好、`networkextension` 檔案與已知網路清單後重開），做了兩次 | 第一次重建後，網卡在開機後約一分鐘內可以上電並掃描，之後進入 D3 就再也上不了電；第二次重建（連有線設定一起）的表現跟原本的故障相同。 |
| SMC 重置（拔電源線 30 秒） | 沒有改變。 |
| 拔掉所有 Thunderbolt 裝置後重開 | 沒有改變；該次開機沒有列舉到任何 Thunderbolt 裝置。 |
| 改從內建 EFI 開機（不用外接 EFI） | 沒有改變。 |
| 在同一台機器開 Sequoia 15.8.1 | **一樣失敗。**當天記錄中 07:44 起的每一次 Sequoia 開機，都在開機後約 25 秒出現相同的 `IOC_POWER -1`，晶片欄位也是空的。機主也表示，這台機器的 Wi-Fi 在這次調查之前的日常使用中就已經時好時壞，當時以為是驅動不全。 |
| 不經 OpenCore，原生開機進 macOS High Sierra 10.13 (build 17G66) 安裝程式並讀取網卡狀態（OpenCore 的 NVRAM 變數不存在，確認沒經過 OpenCore） | 原生的 `AirPort_BrcmNIC` 驅動**讀得到晶片**：`chipnum 0xaa52`、`chiprev 0x1`、`corerev 0x31`、`boardid 0x14a`、`boardrev 0x1114`，與 B 機相同。但核心訊息顯示射頻校準失敗、韌體反覆當機重啟：`wlc_phy_radio2069_afecal: SPINWAIT ERROR : AFECAL for core`、`wl0: fatal error, reinitializing, total count of reinit's[17`、`syncPowerState: WWEN[disabled]`。`TruePowerOff = Yes`，掃不到網路。 |

## 解讀（推論）

- 在能用的那台機器上，OCLP 注入的驅動、root patch 放進系統的檔案、核心快取與 EFI 全都相同，而且故障在三個作業系統下重現，所以它不是 Tahoe 專屬，也不是 OCLP 無線補丁組合造成的。
- 故障序列看起來像網卡無法從某個電源管理事件中恢復：驅動物件建立了，但在電源策略把網卡推進 D3 之前沒有完成初始化，之後就回不來。
- **目前的解釋：A 機的 Wi-Fi 網卡故障。**在原生 High Sierra 安裝程式下，沒有 OpenCore、沒有 OCLP 的 kext、也沒有 root patch，原廠驅動找得到晶片，但射頻類比前端校準失敗（`AFECAL ... SPINWAIT ERROR`），韌體不停當機重啟（`total count of reinit's[17`）。這與 macOS 版本、EFI、驅動、補丁都無關，也吻合機主所說這台的 Wi-Fi 在這些實驗之前就時好時壞。接頭沒插緊或主機板供電問題，不拆機就無法排除。
- 同一台機器的有線網路不受影響，藍牙也正常：機主在 A 機上用藍牙連 Apple Magic Mouse。這張二合一網卡的藍牙是獨立的 USB 功能，符合「故障只限於 Wi-Fi 那一半」。

## 重現時間線

管理員帳號不需要 root。把起始時間換成該機器的開機時間：

```sh
log show --start "YYYY-MM-DD HH:MM:SS" --style compact --predicate \
  '(process == "kernel" AND eventMessage CONTAINS "ARPT" AND (eventMessage CONTAINS "PowerState(OFF)" OR eventMessage CONTAINS "PowerState(ON)")) \
   OR (process == "kernel" AND eventMessage CONTAINS "nub ARPT is not powered") \
   OR (process == "airportd" AND eventMessage CONTAINS "type 19/")'
```

讀 `kern.boottime` 時要取 `sec` 欄位，不是 `usec`；貪婪的正規表示式會取到微秒。

## 尚待解答的問題

1. 有人在 iMac17,1 的 BCM43602 上見過 `wlc_phy_radio2069_afecal: SPINWAIT ERROR` 與韌體反覆重新初始化嗎？換卡或重新插拔是解法嗎？
2. 有辦法知道是誰要求斷電嗎？記錄只顯示執行者（`IOPCIDevice::setPCIPowerState`），看不到要求者。
3. 如果是網卡或接頭的問題，有人試過讓網卡本身重新斷電（不只是 SMC）或重新插拔後就好了嗎？拆開 5K iMac 是最後手段；下一個不用動手拆機的檢查，就是上表的原生 High Sierra 開機。
