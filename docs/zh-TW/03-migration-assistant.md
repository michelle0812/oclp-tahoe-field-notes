# 遷移輔助程式與補丁版核心快取

[English](../en/03-migration-assistant.md) · [首頁](../../README.zh-TW.md)

## 檢查清單：兩個前置條件

這份筆記裡的每一台 OCLP 機器，使用遷移輔助程式前都要先滿足兩個條件；少了任何一個，至少在其中一台上耗費過時間。

1. **先建立臨時管理員帳號。**設定助理中**不要**做遷移；建立一個一次性的帳號（例如 `tempadmin`）並登入。這樣遷移失敗時還有一個能用的帳號，也能用它執行 OCLP 與 SSH 指令。
2. **遷移期間不能有 OCLP root patch。**如果機器已經打過補丁，先用 OCLP 的 **Revert Root Patches** 並重開，再開始遷移；遷移完成後，用臨時管理員重打補丁（`--patch_sys_vol`）。

**實測：**MacBookPro11,5 照這個順序完成了遷移輔助程式。iMac19,1 是在尚未打任何 root patch 時轉移帳號，等於同樣的條件。**為什麼這是陷阱：**iMac17,1 與 MacBookPro11,5 的 Radeon 顯示卡沒有補丁就無法畫出 Tahoe 的首次設定畫面，而沒打補丁的 5K iMac17,1 撐不過完整的遷移流程，兩個條件互相拉扯。這種情況就要用[手動還原替代方案](04-restore-without-migration-assistant.md)。


**MacBookPro11,5 實測：**遷移輔助程式會重開進入 `bootMode='migration'`；Preboot 的 `com.apple.Boot.plist` 含 `-bsdmgroot`。安裝 OCLP root patch 時，verbose 畫面見到 `RSRHelper` 回報核心快取（KC）UUID 不符，接著反覆重開。遷移前先還原補丁並重開、遷移後再打回補丁，才成功完成。[OCLP 的 Time Machine 指引](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/docs/TIMEMACHINE.md)也描述先還原再補回的路線。

該筆電成功的順序是：設定助理先略過遷移，建立臨時管理員；以 OCLP **Revert Root Patches** 還原並重開；在桌面啟動遷移輔助程式；轉移後若迷你設定畫面無法顯示，由臨時管理員執行 OCLP 的 `--patch_sys_vol`；重開後驗證轉入帳號。Radeon R9 M370X 在沒有加速時連 Tahoe 初始設定畫面都無法正常繪出，因此「等遷移全程結束才打第一次補丁」在此機不可行。使用 CLI 前，請先核對自己安裝的 OCLP 執行檔位置與版本參數。[OCLP 安裝後補丁說明](https://dortania.github.io/OpenCore-Legacy-Patcher/POST-INSTALL.html)。

**iMac17,1 #1 實測：**還原補丁後，無加速的 5K WindowServer 在遷移時被 watchdog 終止。保留補丁時，桌面階段雖然複製了檔案，遷移模式仍反覆重開。此機**沒有**明確的 `RSRHelper` mismatch 訊息，所以認定與筆電完全同因仍屬**推論**。移走遷移用的開機 plist 後一般開機，會清掉臨時遷移沙盒，結果只剩空帳號，資料並未復原。**不要靠移走該 plist 來完成待處理的遷移。**沙盒若已消失，應從完整來源重新建立遷移作業。

**依 [XNU 的 KC 相依檢查](https://github.com/apple-oss-distributions/xnu)與唯讀比對推論：**只換 `BootKernelExtensions.kc` 有風險。補丁後的 System 與 Auxiliary collection 依賴其 UUID；`-nokcmismatchpanic` 不保證整組 KC 有效，也不保證遷移完成。此 iMac 沒有驗證成功的 KC 替換流程。`-bsdmgroot` 與之後轉入 BaseSystem，也不足以證明 Tahoe `boot.efi` 實際讀取哪個絕對 KC 路徑；[XNU image boot 程式碼](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/bsd_init.c)是機制參考，不是本次開機追蹤。

**網路實測踩坑：**一次網路 Time Machine 遷移先經慢速 Wi-Fi，約 3.7 MB/s；來源改用有線後，該次量到約 123–158 MB/s。開始前要確認實際路徑；傳輸中途切換來源網卡，既有 SMB 工作階段沒有自動重連。這些速度只是單一環境的觀測，不是預期效能。
