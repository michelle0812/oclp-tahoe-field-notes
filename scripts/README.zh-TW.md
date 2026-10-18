# 還原腳本（v2.1 實戰副本）

[English](README.md) · [首頁](../README.zh-TW.md)

`restore-user.sh` 是在 iMac17,1 #1 以**本機**加密 Time Machine APFS sparsebundle 實測的 v2.1 去識別化副本。當次比對 56,605 項、零差異、沒有殘留 Time Machine 保護 ACE，使用者也成功登入。此處公開副本**尚未在實機執行**。它不能完整取代遷移輔助程式。詳見[還原範圍與鑰匙圈後果](../docs/zh-TW/04-restore-without-migration-assistant.md)。

只應在有獨立且已驗證備份的專用 Tahoe 26 測試系統上執行。先檢查腳本與目的路徑。映像路徑為必填，沒有針對特定機器的預設值。在本機終端機核對目的系統後：

```sh
sudo ./restore-user.sh --list --image '/Volumes/<backup-volume>/<backup>.sparsebundle'
sudo ./restore-user.sh --dry-run --image '/Volumes/<backup-volume>/<backup>.sparsebundle'
sudo ./restore-user.sh --user '<user>' --image '/Volumes/<backup-volume>/<backup>.sparsebundle'
```

正式執行會要求確認並互動輸入新帳號密碼。須由臨時管理員執行 `sudo`；腳本以 `SUDO_USER` 處理遠端複本擁有權、資料夾 ACL 取樣，並防止把該管理員選成還原帳號。其他選項有 `--snapshot`、`--no-apps`、`--no-usr-local`、`--apps-only`、`--boot-volume`。v2.1 原有的 `--from-host` 與 `--remote-image` 仍保留，但**沒有**在上述本機還原中驗證；不要假設中斷的複製可續傳。`--dry-run` 不會拉取遠端映像。

**這個版本的已知缺口：**不還原 `crontab`、缺少 Command Line Tools 時不會提醒、新密碼只問一次（沒有確認），並且可能因為三個作業系統自建的 `containermanagerd` 快取目錄而誤報失敗。詳見[還原筆記](../docs/zh-TW/04-restore-without-migration-assistant.md)。

**原廠不支援，可能遺失資料。先備份，使用風險自負。**腳本採 [MIT 授權](../LICENSE)，雙語文件採 [CC BY 4.0](../docs/LICENSE-CC-BY-4.0.md)。
