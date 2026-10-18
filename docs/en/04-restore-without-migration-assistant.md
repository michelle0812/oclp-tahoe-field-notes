# Manual restore without Migration Assistant

[繁體中文](../zh-TW/04-restore-without-migration-assistant.md) · [Home](../../README.md)

**Tested on iMac17,1 #1:** The v2.1 [restore script](../../scripts/README.md) restored a user from an encrypted Time Machine APFS sparsebundle. Its file comparison reported 56,605 entries with no differences in the tested run, and the owner subsequently logged in successfully. That is a machine-specific result, not proof that every app, secret or system service was migrated. Test with `--list` and `--dry-run` first, then inspect the planned target and backup before a write run.

The script mounts the image and snapshot read-only, creates a new local account with an interactively chosen password, copies the home and selected missing apps with `ditto --noacl`, and can merge missing Intel Homebrew files under `/usr/local`. It reports missing system helpers instead of installing them. Time Machine protection ACLs can deny writes to restored files: the earlier manual copy preserved roughly 35,948 such entries. v2.1 excludes those ACLs and restores the standard `group:everyone deny delete` ACE to applicable home folders. Verification checks for remaining Time Machine ACEs and file differences.

**Tested keychain difference:** Creating an account with a new password does not unlock a copied `login.keychain-db` whose old password is unknown. An initial manual copy caused repeated keychain prompts even though the file hash matched the source. v2.1 preserves the old login keychain under a dated name and lets macOS create a new one at first login. It also excludes UUID-named Local Items keychain folders, which are tied to a particular Mac, and `.sb-*` keychain files. **Existing secrets can be lost from the active keychain**; keep the original backup and do not assume iCloud Keychain was enabled. A compatible old password may permit manual recovery from the archived keychain.

The user picture lives in the directory-service record rather than just the home folder; the script copies its JPEG data if present. Homebrew on Intel is outside the home directory, so `/usr/local` needs separate attention. The tested run found no old UID ownership remaining in the copied Homebrew tree, but app helpers, licenses and login items still need individual checks.

**Difference from Migration Assistant:** This is a selected file and local-account restore. It does not transfer the source password hash, Secure Token, FileVault entitlement, machine-bound Local Items, system services, or all app state. The successful MacBookPro11,5 Migration Assistant run did not have the same keychain problem; do not attribute that successful run to this script. The v2.1 test used a local image. Remote copy options are present in the source script but were **not** validated in that run.

## Results from a second machine

**Tested on iMac17,1 #2 (local image, newer script revision):** 56,478 home entries compared after excluding machine-bound keychain items, zero content (SHA-256) differences, zero remaining Time Machine ACEs, the account picture matched the backup byte for byte, Homebrew merged without disturbing an existing helper link, and the new login produced no keychain prompt. The script nevertheless reported a failure at its last check: three directories under `Library/Caches/com.apple.containermanagerd` had been created by the operating system inside the new account. Nothing was missing, so this was a **false positive** that a newer revision tolerates (only directories under that path).

**Not covered by a restore, check manually:**

- **Scheduled jobs.** User and root `crontab` entries live outside the home folder. If a root job runs a script, the copy on the new machine must be owned by root; a copy owned by the old UID (which on the new machine can be the temporary administrator) would let that account change what root runs.
- **Command Line Tools**, system-level helpers (`LaunchDaemons`, `LaunchAgents`, `PrivilegedHelperTools`) and machine settings. Most apps reinstall their own helpers on first launch.
- **The account password.** `sysadminctl` asks once and has no confirmation field; a typo creates the account with the typo. Type it twice yourself before running it, or confirm the first login.

The published script copy is the earlier revision; these gaps are being closed in a newer one.
