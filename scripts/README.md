# Restore scripts (v2.1 field copy)

[繁體中文](README.zh-TW.md) · [Home](../README.md)

`restore-user.sh` is an anonymized copy of the v2.1 script tested on iMac17,1 #1 with a **local** encrypted Time Machine APFS sparsebundle. The test reported 56,605 compared entries, zero differences, no remaining Time Machine protection ACEs, and a successful user login. The copy here has **not** been run on a real Mac. It is not a full Migration Assistant replacement. See [scope and keychain consequences](../docs/en/04-restore-without-migration-assistant.md).

Run only on a dedicated Tahoe 26 test installation with a verified, independent backup. Review the script and target paths first. The image path is required; there is no machine-specific default. In a local terminal, after checking the target system:

```sh
sudo ./restore-user.sh --list --image '/Volumes/<backup-volume>/<backup>.sparsebundle'
sudo ./restore-user.sh --dry-run --image '/Volumes/<backup-volume>/<backup>.sparsebundle'
sudo ./restore-user.sh --user '<user>' --image '/Volumes/<backup-volume>/<backup>.sparsebundle'
```

The command prompts for confirmation and a new account password. It expects the temporary administrator to invoke `sudo`; the script uses `SUDO_USER` for remote-copy ownership, folder ACL sampling and protection against selecting that account for restore. Options include `--snapshot`, `--no-apps`, `--no-usr-local`, `--apps-only`, and `--boot-volume`. `--from-host` with `--remote-image` is still present from v2.1 but was **not** validated in the cited local restore. Do not assume it resumes an interrupted copy. `--dry-run` does not pull a remote image.

**Known gaps in this revision:** it does not restore `crontab` entries, does not warn about missing Command Line Tools, asks for the new password only once (no confirmation), and may report a false failure for three OS-created `containermanagerd` cache directories. See [the restore notes](../docs/en/04-restore-without-migration-assistant.md).

**Unsupported; data loss is possible. Back up first. Use at your own risk.** Scripts are [MIT licensed](../LICENSE). The bilingual documentation is [CC BY 4.0](../docs/LICENSE-CC-BY-4.0.md).
