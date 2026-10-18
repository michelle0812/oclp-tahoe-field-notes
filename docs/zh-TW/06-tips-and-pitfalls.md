# 技巧與踩坑

[English](../en/06-tips-and-pitfalls.md) · [首頁](../../README.zh-TW.md)

以下是當次配置的限定觀察。會變更開機路徑或系統卷宗的指令，仍須另備份並依機型驗證。

- **實測：**OCLP CLI 只建置而不安裝時，產物位於程序結束就刪掉的暫存目錄。一次實驗在日誌出現「has been built at」後暫停程序、複製 EFI、再讓程序繼續。這是脆弱的繞法，**不是受支援的純建置介面**。測試複製的 EFI 前，應使用相符版本的 OpenCore `ocvalidate` 檢查。[OCLP 原始碼](https://github.com/dortania/OpenCore-Legacy-Patcher)、[OpenCore](https://github.com/acidanthera/OpenCorePkg)。
- **實測：**iMac17,1 #1 未打補丁的 GCN GPU 無法繪出 Tahoe 首次設定畫面。當次從另一套 macOS 佈署專用首次開機輔助程序，建立臨時管理員並開啟 SSH；之後安裝 `AutoPkg-Assets.pkg`，其 postinstall 觸發 root patch，Tahoe 畫面才可用。該輔助程序含臨時密碼與 SSH 金鑰，**沒有作為可重用公開腳本收錄**。自行重現前須檢查目的 APFS 卷宗角色、帳號安全及復原方式。[Apple APFS 安全說明](https://support.apple.com/en-asia/guide/security/seca6147599e/web)、[OCLP 資源套件](https://github.com/dortania/OpenCore-Legacy-Patcher/releases/tag/3.0.0-rc.3)。
- **實測：**iMac19,1 每次 OCLP 重建都會把會卡住的 5K 診斷路徑裝回，也會清掉當次手動加入的 AMFIPass kext；後續重建還可能把另裝的 OpenCore 1.0.9 換掉。**重開前**應檢查新 EFI，只補回該機確實需要的本地調整。AMFIPass 與 SIP 設定是此配置音效補丁的特定需要。[AMFIPass](https://github.com/dortania/OpenCore-Legacy-Patcher/tree/main/payloads/Kexts/Acidanthera)。
- **實測：**Preboot 的 `Persist/*.tracev3` 只有早期開機證據。解碼需有對應 timesync、`uuidtext` 與 `OSArchiveVersion=4` 的有效 log archive；資料不齊可能誤導。若 shell 內建 `log` 會遮蔽執行檔，請使用 `/usr/bin/log show --archive ...`。筆電上的 `RSRHelper` 訊息，以 verbose 開機照片更容易確定。[Apple Unified Logging](https://developer.apple.com/documentation/os/logging)。
- **實測 shell 坑：**Bash 3.2 配 `set -e` 時，函式最後是失敗的 `條件 && 動作`，可能讓整支腳本靜默結束；適當位置要明確成功回傳。`LC_ALL=C` 時，變數後接非 ASCII 文字要寫 `${VAR}`。macOS 的 `plutil -replace` 用於陣列索引可能是插入而非取代，應檢查結果。`chmod -a "<ACE>"` 是從符合的項目「減去」列出的權限，所以清掉 Time Machine 的 `deny write,delete,…` 時，家目錄標準資料夾的 `group:everyone deny delete` 也會一起被拿掉，事後要補回（或改用 `ditto --noacl` 複製，再只補標準項目）。倚賴遠端複製前，要查目前安裝的 `rsync` 實作與旗標。這些觀察不能取代在確切 shell 與系統版本上的測試。

- **實測（iMac17,1 #2）：**把 OCLP 的 `AutoPkg-Assets.pkg`（取自該版本安裝媒體）複製到 `createinstallmedia` 隨身碟的 `Library/Packages`，新系統就會自己打補丁：首次開機前後，`/Applications` 已有 OCLP 3.0.0-rc.3、`/System/Library/CoreServices/OpenCore-Legacy-Patcher.plist` 有補丁記錄、自動補丁記錄檔結尾是「Patching complete」，並且有加速的 5K 顯示，不需要手動 `installer -pkg`。副作用：系統卷宗的封存狀態會顯示 `Sealed: Broken`；把「已封存」當作「安裝完成」的工具，也要接受 OCLP 補丁記錄。放進 888 MB 的套件後，安裝分割區只剩約 1 GB，要先確認空間。[OCLP RC3 資源](https://github.com/dortania/OpenCore-Legacy-Patcher/releases/tag/3.0.0-rc.3)。
- **實測：**輔助程式在設定助理已經啟動之後才寫入 `.AppleSetupDone`，即使帳號與旗標都正確，畫面仍會停在設定助理（選擇國別）。再重開一次就會進登入畫面。
- **實測：**還原後的系統執行 `brew update` 會失敗，訊息是「No developer tools installed」，因為 Command Line Tools 位於 `/Library/Developer/CommandLineTools`，在家目錄與 `/usr/local` 之外。要另外用 `xcode-select --install` 安裝（需要網路；這不是好幾 GB 的 Xcode App）。
