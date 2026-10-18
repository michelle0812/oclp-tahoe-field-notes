#!/bin/bash
# SPDX-License-Identifier: MIT
# Unsupported restore tool. Back up first; use at your own risk.
set -euo pipefail
VERSION=2.1  # Original release tested on iMac17,1 with Tahoe 26.7.1
umask 077
export LC_ALL=C

# 測試鉤子只接受 /tmp 內具專用標記的假根目錄；正式執行不可指定。
TEST_ROOT=${OCLP_NOTES_TEST_ROOT:-}
TEST=0
if [[ -n $TEST_ROOT ]]; then
  [[ $TEST_ROOT == /tmp/* || $TEST_ROOT == /private/tmp/* ]] || { echo '測試根目錄必須在 /tmp' >&2; exit 2; }
  [[ -f $TEST_ROOT/.oclp-notes-restore-test ]] || { echo '缺少測試標記' >&2; exit 2; }
  TEST=1
fi
ROOT=${TEST_ROOT:-}
IMAGE=''
REMOTE_IMAGE=''
FROM_HOST=''
KEEP_COPY=0
MODE=run
USER_OPT=''
SNAP_OPT=''
APPS=1
USR_LOCAL=1
APPS_ONLY=0
BOOT_VOLUME=''
IMAGE_MOUNT=''
SNAP_MOUNT=''
SNAP_ATTACHED=0
IMAGE_DEVICE=''
COPY_PATH=''
SUCCESS=0
LOG=${OCLP_NOTES_TEST_LOG:-/var/log/oclp-notes-restore-user.log}
[[ $TEST == 0 ]] || LOG=${OCLP_NOTES_TEST_LOG:-$TEST_ROOT/restore.log}

say() { printf '%s\n' "$*"; [[ $MODE == run ]] && printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG" || true; }
die() { say "中止：$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
用法：sudo ./restore-user.sh [--list|--dry-run] [--user 短名稱] [--snapshot 時間戳或快照名]
     [--no-apps|--apps-only] [--no-usr-local] [--image 本機.sparsebundle]
     [--from-host SSH別名或IP --remote-image 遠端.sparsebundle [--keep-copy]]
     [--boot-volume 卷宗名]
EOF
  exit 2
}
while (($#)); do
  case $1 in
    --list) [[ $MODE == run ]] || usage; MODE=list; shift ;;
    --dry-run) [[ $MODE == run ]] || usage; MODE=dry; shift ;;
    --user) (($# >= 2)) || usage; USER_OPT=$2; shift 2 ;;
    --snapshot) (($# >= 2)) || usage; SNAP_OPT=$2; shift 2 ;;
    --no-apps) APPS=0; shift ;;
    --no-usr-local) USR_LOCAL=0; shift ;;
    --apps-only) APPS_ONLY=1; shift ;;
    --image) (($# >= 2)) || usage; IMAGE=$2; shift 2 ;;
    --from-host) (($# >= 2)) || usage; FROM_HOST=$2; shift 2 ;;
    --remote-image) (($# >= 2)) || usage; REMOTE_IMAGE=$2; shift 2 ;;
    --keep-copy) KEEP_COPY=1; shift ;;
    --boot-volume) (($# >= 2)) || usage; BOOT_VOLUME=$2; shift 2 ;;
    *) usage ;;
  esac
done
[[ -z $FROM_HOST || -n $REMOTE_IMAGE ]] || usage
[[ -n $FROM_HOST || -z $REMOTE_IMAGE ]] || usage
[[ -n $FROM_HOST || $KEEP_COPY == 0 ]] || usage
[[ $APPS_ONLY == 0 ]] || USR_LOCAL=0
[[ -z $FROM_HOST || -z $IMAGE ]] || usage
[[ -n $FROM_HOST || -n $IMAGE ]] || usage
[[ $FROM_HOST != *$'\n'* && $FROM_HOST != -* && $REMOTE_IMAGE != *$'\n'* ]] || usage
[[ $REMOTE_IMAGE != *:* ]] || usage

cleanup() {
  local status=$?
  local detached=1
  trap - EXIT HUP INT TERM
  # 中斷時 process substitution 的 find 可能還開著快照裡的檔案，先收掉子程序再卸載
  pkill -P $$ >/dev/null 2>&1 || true
  if [[ $SNAP_ATTACHED == 1 ]]; then
    local i
    for i in 1 2 3; do umount "$SNAP_MOUNT" >/dev/null 2>&1 && break; sleep 1; done
    if mount | grep -qF " on $SNAP_MOUNT "; then umount -f "$SNAP_MOUNT" >/dev/null 2>&1 || detached=0; fi
  fi
  [[ -z $SNAP_MOUNT ]] || rmdir "$SNAP_MOUNT" >/dev/null 2>&1 || true
  if [[ -n $IMAGE_DEVICE ]]; then
    hdiutil detach "$IMAGE_DEVICE" >/dev/null 2>&1 || hdiutil detach -force "$IMAGE_DEVICE" >/dev/null 2>&1 || detached=0
  fi
  if [[ $detached == 0 ]]; then printf '警告：卸載未完全成功；請檢查掛載狀態，暫存副本保留。\n' >&2; fi
  if [[ -n $COPY_PATH && $SUCCESS == 1 && $KEEP_COPY == 0 && $TEST == 0 && $detached == 1 ]]; then
    printf '已成功還原。刪除暫存映像副本 %s？輸入 yes：' "$COPY_PATH" > /dev/tty
    local answer=''; IFS= read -r answer < /dev/tty || true
    if [[ $answer == yes ]]; then rm -rf -- "$COPY_PATH"; else say "保留副本：$COPY_PATH"; fi
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

[[ $TEST == 1 || ( -t 0 && -t 1 ) ]] || die '需要互動 TTY；請在本機終端機或 ssh -t 執行'
prompt_read() {
  if [[ $TEST == 1 ]]; then IFS= read -r REPLY || REPLY=''
  else IFS= read -r REPLY < /dev/tty || REPLY=''
  fi
}
if [[ $TEST == 0 ]]; then
  [[ $EUID == 0 ]] || die '必須以 sudo 執行'
  [[ -n ${SUDO_USER:-} ]] || die '請由臨時管理員使用 sudo 執行'
  [[ $(sw_vers -productVersion) == 26.* ]] || die '目前開機系統不是 macOS Tahoe 26.x'
  if [[ -n $BOOT_VOLUME ]]; then
    actual=$(diskutil info / | awk -F: '/Volume Name:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')
    [[ $actual == "$BOOT_VOLUME" ]] || die "開機卷宗不符：$actual"
  fi
  [[ -d /System/Volumes/Data/Users ]] || die '找不到目前開機的資料卷宗'
fi
if [[ $MODE == run ]]; then
  mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
  touch "$LOG" || { echo "無法寫紀錄：$LOG" >&2; exit 1; }
fi
say "restore-user.sh v${VERSION}；開始：模式=${MODE}，來源=${FROM_HOST:-本機}，應用程式=${APPS}"

free_bytes() { df -k "$ROOT/Users" | awk 'NR==2 {print $4*1024}'; }
size_bytes() { du -sk "$1" | awk '{print $1*1024}'; }
need_space() {
  local need=$1 free
  free=$(free_bytes)
  awk -v n="$need" -v f="$free" 'BEGIN {exit !(f >= n*1.2)}' || die "空間不足：至少需要估算量 ×1.2（$need 位元組），可用 $free 位元組"
}

if [[ -n $FROM_HOST ]]; then
  [[ $MODE != dry ]] || die '遠端 --dry-run 不寫任何檔案；請先以 --list --keep-copy 取得副本，再用 --image 指向該副本'
  [[ $REMOTE_IMAGE == /* && $REMOTE_IMAGE == *.sparsebundle ]] || die '遠端映像須為絕對路徑 .sparsebundle'
  [[ $FROM_HOST =~ ^[A-Za-z0-9._@-]+$ ]] || die 'SSH 主機格式不安全'
  # 遠端 shell 使用單引號包裝路徑，先排除引號與控制字元。
  [[ $REMOTE_IMAGE != *"'"* && $REMOTE_IMAGE != *$'\r'* ]] || die '遠端路徑含不支援字元'
  remote_quoted="'${REMOTE_IMAGE}'"
  if [[ $TEST == 1 ]]; then
    COPY_PATH="$ROOT/copy/$(basename "$REMOTE_IMAGE")"
  else
    COPY_PATH="/private/var/tmp/oclp-notes-restore-$(date +%Y%m%d-%H%M%S)-$$/$(basename "$REMOTE_IMAGE")"
  fi
  copy_parent=$(dirname "$COPY_PATH")
  if [[ $TEST == 0 ]]; then
    remote_kb=$(sudo -u "${SUDO_USER:-tempadmin}" ssh "$FROM_HOST" "du -sk $remote_quoted" | awk 'NR==1 {print $1}') || die '無法查詢遠端映像大小'
    [[ $remote_kb =~ ^[0-9]+$ ]] || die '遠端映像大小無效'
    need_space "$((remote_kb * 1024))"
  fi
  mkdir -p "$copy_parent"
  if [[ $TEST == 0 ]]; then chown "${SUDO_USER:-tempadmin}" "$copy_parent"; fi
  say "開始從 $FROM_HOST 拉取映像：$COPY_PATH"
  if [[ $TEST == 1 ]]; then
    rsync -aE --progress "$FROM_HOST:$remote_quoted" "$COPY_PATH" || die '拉取失敗，暫存副本保留以便續傳'
  else
    sudo -u "${SUDO_USER:-tempadmin}" rsync -aE --progress -e ssh "$FROM_HOST:$remote_quoted" "$COPY_PATH" || die '拉取失敗，暫存副本保留以便續傳'
  fi
  IMAGE=$COPY_PATH
fi
if [[ ! -d $IMAGE || -L $IMAGE ]]; then
  say "映像不存在或為符號連結：$IMAGE"
  if [[ $TEST == 0 ]]; then
    volume_name=$(printf '%s\n' "$IMAGE" | awk -F/ '$2=="Volumes" {print $3}')
    if [[ -n $volume_name ]]; then
      while IFS= read -r volume_line; do
        dev=${volume_line##* }
        [[ $dev == disk* ]] || continue
        mount_status=$(diskutil info "$dev" | awk -F: '/Mounted:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')
        if [[ $mount_status == No ]]; then
          say "名稱相符且未掛載：$volume_line"
          say "確認裝置代號後執行 sudo diskutil mount $dev"
        fi
      done < <(diskutil list | grep -F "$volume_name" || true)
    fi
  fi
  die '請確認映像路徑及所在卷宗'
fi
if [[ $TEST == 1 ]]; then
  IMAGE_MOUNT="$ROOT/image-mount"
  hdiutil attach -readonly -nobrowse "$IMAGE" >/dev/null
  IMAGE_DEVICE='fake-device'
else
  # -stdinpass 直接讀 TTY 會顯示字元，所以先 read -s 隱藏輸入，再用內建 printf 經管線餵入；密碼不進 argv、環境或紀錄。
  IFS= read -r -s -p '請輸入備份映像密碼（不顯示）：' img_pass < /dev/tty || die '無法讀取密碼'
  printf '\n' > /dev/tty
  attach_output=$(printf '%s' "$img_pass" | hdiutil attach -readonly -nobrowse -stdinpass "$IMAGE") || { unset img_pass; die '映像掛載失敗（密碼錯誤或映像損壞）'; }
  unset img_pass
  IMAGE_DEVICE=$(printf '%s\n' "$attach_output" | awk '/^\/dev\/disk/ {print $1; exit}')
  IMAGE_MOUNT=$(printf '%s\n' "$attach_output" | awk -F '\t' '/^\/dev\/disk/ && $NF ~ /^\/Volumes\// {p=$NF} END {print p}')
  [[ -n $IMAGE_DEVICE && -d $IMAGE_MOUNT ]] || die '找不到掛載的映像卷宗'
fi
say "映像已唯讀掛載：$IMAGE_MOUNT"

snap_list=$(diskutil apfs listsnapshots "$IMAGE_MOUNT") || die '無法列出 APFS 快照'
tmutil listbackups -d "$IMAGE_MOUNT" 2>&1 | while IFS= read -r line; do say "tmutil 參考：$line"; done || true
mapfile_compat() { while IFS= read -r line; do [[ -z $line ]] || SNAPSHOTS+=("$line"); done; }
SNAPSHOTS=()
mapfile_compat < <(printf '%s\n' "$snap_list" | awk '/Name: *com\.apple\.TimeMachine\.[0-9]{4}-/ {sub(/^.*Name: */, ""); print}')
# macOS awk 不保證支援 {4}；上式若未命中改用較保守的前綴。
if ((${#SNAPSHOTS[@]} == 0)); then
  mapfile_compat < <(printf '%s\n' "$snap_list" | awk '/Name: *com\.apple\.TimeMachine\./ {sub(/^.*Name: */, ""); if ($0 ~ /\.backup$/) print}')
fi
((${#SNAPSHOTS[@]} > 0)) || die '沒有完整的 Time Machine APFS 快照'
printf '可用快照：\n'; printf '  %s\n' "${SNAPSHOTS[@]}"
SNAP_NAME=''
if [[ -n $SNAP_OPT ]]; then
  for s in "${SNAPSHOTS[@]}"; do [[ $s == "$SNAP_OPT" || $s == *"$SNAP_OPT"* ]] && SNAP_NAME=$s; done
  [[ -n $SNAP_NAME ]] || die '指定的快照不在完整快照清單中'
else
  SNAP_NAME=$(printf '%s\n' "${SNAPSHOTS[@]}" | sort | tail -1)
fi
say "選用快照：$SNAP_NAME"
if [[ $TEST == 1 ]]; then
  SNAP_MOUNT="$ROOT/snapshot-mount"
  SNAP_ATTACHED=1
  mount_apfs -o rdonly,nobrowse -s "$SNAP_NAME" "$IMAGE_MOUNT" "$SNAP_MOUNT"
else
  SNAP_MOUNT=$(mktemp -d /private/tmp/oclp-notes-tm-snapshot.XXXXXX)
  SNAP_ATTACHED=1
  mount_apfs -o rdonly,nobrowse -s "$SNAP_NAME" "$IMAGE_MOUNT" "$SNAP_MOUNT" || die '無法唯讀掛載快照'
fi
[[ -d $SNAP_MOUNT ]] || die '快照掛載點不存在'

# 在 APFS 備份快照內找資料卷宗的 Users，不假定來源機的卷宗名稱。
DATA_ROOT=''
# 部分受保護目錄讀不到時 find 會回非 0；只要找到 Users 就繼續，錯誤另存判斷。
find_err=$(mktemp /private/tmp/oclp-notes-find-err.XXXXXX)
search_result=$(find "$SNAP_MOUNT" -maxdepth 7 -type d -name Users -print 2>"$find_err") || true
if [[ -z $search_result ]]; then
  ! grep -q 'Operation not permitted' "$find_err" || { rm -f "$find_err"; die '完整取用磁碟不足：系統設定 → 隱私權與安全性 → 完整取用磁碟 → SSH 加入 /usr/libexec/sshd-keygen-wrapper；本機加入「終端機」。'; }
  die "快照路徑搜尋失敗：$(head -3 "$find_err")"
fi
rm -f "$find_err"
while IFS= read -r users_dir; do
  [[ -n $users_dir ]] || continue
  candidate=${users_dir%/Users}
  [[ -d $candidate/Applications || -d $candidate/private/var/db/dslocal ]] || continue
  [[ -z $DATA_ROOT ]] || die '快照內有多個可疑的資料卷宗，停止避免誤還原'
  DATA_ROOT=$candidate
done <<< "$search_result"
[[ -n $DATA_ROOT ]] || die '找不到快照資料卷宗 Users；請檢查完整取用磁碟權限或備份格式'
say "資料卷宗：$DATA_ROOT"
probe_error=$(ls "$DATA_ROOT/Users" 2>&1 >/dev/null) || {
  [[ $probe_error != *'Operation not permitted'* ]] || die '完整取用磁碟不足：系統設定 → 隱私權與安全性 → 完整取用磁碟 → SSH 加入 /usr/libexec/sshd-keygen-wrapper；本機加入「終端機」。重新連線後重跑。'
  die "無法讀取 Users：$probe_error"
}

# ditto 對符號連結套 ACL／延伸屬性時會回 Operation not supported（連結本身已建立）；
# 只有這類錯誤、且目的地連結確實存在時才當警告，其餘一律算失敗。
safe_ditto() {
  local src=$1 dst=$2 err rc=0 line p bad=0 n=0
  # 來源本身是符號連結時 ditto 會解析目標；絕對路徑連結（如 /usr/local/bin/kitty → /usr/local/Caskroom/…）
  # 的目標在目前系統還不存在就會失敗，所以照原指向重建連結
  if [[ -L $src ]]; then
    # sudo 底下 umask 可能是 077，連結會變 lrwx------；照一般 022 建
    (umask 022; ln -s "$(readlink "$src")" "$dst") || { say "建立符號連結失敗：$dst"; return 1; }
    return 0
  fi
  err=$(mktemp /private/tmp/oclp-notes-ditto-err.XXXXXX)
  ditto --rsrc --extattr --noacl "$src" "$dst" 2>"$err" || rc=$?
  if [[ $rc != 0 ]]; then
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      p=${line#ditto: }; p=${p%: Operation not supported}
      if [[ $line == *": Operation not supported" && -L $p ]]; then n=$((n + 1)); else bad=1; say "ditto 錯誤：$line"; fi
    done < "$err"
    [[ $bad == 0 ]] && say "警告：$n 個符號連結的延伸屬性無法套用（連結本身已建立），視為成功" && rc=0
  fi
  rm -f "$err"
  return $rc
}

keychain_excluded() {
  local rel=$1 part
  [[ $rel == Library/Keychains/* ]] || return 1
  part=${rel#Library/Keychains/}
  [[ $part == login.keychain-db.sb-* || $part == */* && ${part%%/*} =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ || $part =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]
}
copy_home() {
  local item rel inode seen first
  mkdir -p "$DEST/Library"
  [[ ! -d $SRC/Library/Keychains ]] || mkdir -p "$DEST/Library/Keychains"
  while IFS= read -r -d '' item; do
    rel=${item#"$SRC"/}
    [[ $rel == Library/Keychains ]] && continue
    if [[ $rel == Library ]]; then
      mkdir -p "$DEST/Library"
    elif [[ $rel == Library/Keychains/* ]]; then
      if keychain_excluded "$rel"; then continue; fi
      safe_ditto "$item" "$DEST/$rel" || return 1
    elif [[ $rel == Library/* ]]; then
      safe_ditto "$item" "$DEST/$rel" || return 1
    else
      safe_ditto "$item" "$DEST/$rel" || return 1
    fi
  done < <(find "$SRC" -mindepth 1 -maxdepth 1 ! -name Library -print0)
  if [[ -d $SRC/Library ]]; then
    while IFS= read -r -d '' item; do
      rel=${item#"$SRC"/}
      [[ $rel == Library/Keychains ]] && continue
      safe_ditto "$item" "$DEST/$rel" || return 1
    done < <(find "$SRC/Library" -mindepth 1 -maxdepth 1 ! -name Keychains -print0)
    if [[ -d $SRC/Library/Keychains ]]; then
      while IFS= read -r -d '' item; do
        rel=${item#"$SRC"/}
        keychain_excluded "$rel" && continue
        safe_ditto "$item" "$DEST/$rel" || return 1
      done < <(find "$SRC/Library/Keychains" -mindepth 1 -maxdepth 1 -print0)
    fi
  fi
  chmod "$(stat -f %Lp "$SRC")" "$DEST"
  if [[ -d $SRC/Library ]]; then chmod "$(stat -f %Lp "$SRC/Library")" "$DEST/Library"; fi
  if [[ -d $SRC/Library/Keychains ]]; then chmod "$(stat -f %Lp "$SRC/Library/Keychains")" "$DEST/Library/Keychains"; fi
  seen=$(mktemp -d /private/tmp/oclp-notes-hardlinks.XXXXXX)
  while IFS= read -r -d '' item; do
    rel=${item#"$SRC"/}
    rel=${rel#/}
    keychain_excluded "$rel" && continue
    [[ -f $DEST/$rel && ! -L $DEST/$rel ]] || continue
    inode=$(stat -f '%d-%i' "$item")
    if [[ -f $seen/$inode ]]; then
      IFS= read -r first < "$seen/$inode"
      rm -f "$DEST/$rel" || { rm -rf "$seen"; return 1; }
      ln "$DEST/$first" "$DEST/$rel" || { rm -rf "$seen"; return 1; }
    else
      printf '%s\n' "$rel" > "$seen/$inode"
    fi
  done < <(find "$SRC" -type f -links +1 -print0)
  rm -rf "$seen"
}
count_keychain_exclusions() {
  local item rel
  KEY_EXCLUDED=0
  [[ -d $SRC/Library/Keychains ]] || return 0
  while IFS= read -r -d '' item; do
    rel=${item#"$SRC"/}
    if keychain_excluded "$rel"; then KEY_EXCLUDED=$((KEY_EXCLUDED + 1)); fi
  done < <(find "$SRC/Library/Keychains" -mindepth 1 -print0)
  return 0
}
collect_standard_acl() {
  local sample=${SUDO_USER:-tempadmin} item rel
  STANDARD_DIRS=()
  [[ -d $ROOT/Users/$sample ]] || return 0
  while IFS= read -r -d '' item; do
    rel=${item#"$ROOT/Users/$sample"}
    [[ $rel == "$item" ]] && continue
    if ls -lde "$item" | grep -Eq '(group:everyone|ABCDEFAB-CDEF-ABCD-EFAB-CDEF0000000C) deny delete([[:space:]]|$)'; then
      STANDARD_DIRS+=("$rel")
    fi
  done < <(find "$ROOT/Users/$sample" -maxdepth 3 -type d -print0)
  return 0
}
restore_standard_acl() {
  local rel
  ACL_RESTORED=0
  for rel in "${STANDARD_DIRS[@]+"${STANDARD_DIRS[@]}"}"; do
    if [[ -d $DEST$rel && ! -L $DEST$rel ]]; then
      chmod +a 'group:everyone deny delete' "$DEST$rel" || return 1
      ACL_RESTORED=$((ACL_RESTORED + 1))
    fi
  done
  return 0
}
scan_tm_acl() {
  local target=$1 report=$2
  [[ -e $target || -L $target ]] || return 0
  find "$target" -exec ls -lde {} + | awk '
    /^[dlbcps-]/ { path=$0; next }
    /(group:everyone|ABCDEFAB-CDEF-ABCD-EFAB-CDEF0000000C) deny write,delete,append,writeattr,writeextattr,chown([[:space:]]|$)/ ||
    /(group:everyone|ABCDEFAB-CDEF-ABCD-EFAB-CDEF0000000C) deny add_file,delete,add_subdirectory,delete_child,writeattr,writeextattr,chown([[:space:]]|$)/ {print path; print $0}
  ' >> "$report"
}
restore_local() {
  local dir src rel dst owner
  LOCAL_COPIED=0
  LOCAL_COPIED_PATHS=()
  LOCAL_SKIPPED=()
  [[ $USR_LOCAL == 1 && -d $DATA_ROOT/usr/local ]] || return 0
  [[ ! -L $ROOT/usr/local ]] || die '拒絕符號連結 /usr/local'
  for dir in bin Caskroom Cellar etc Frameworks Homebrew include lib opt sbin share var; do
    src="$DATA_ROOT/usr/local/$dir"
    [[ -e $src && ! -L $src ]] || continue
    dst="$ROOT/usr/local/$dir"
    [[ ! -L $dst ]] || die "拒絕符號連結目的目錄：$dst"
    if [[ ! -e $dst ]]; then
      # 目的地沒有這個目錄：整個目錄一次 ditto，再把原 UID 改成新 UID
      # （逐項搬每項都要起 ditto／stat／chown，Homebrew 7,000 項可能耗時很久）
      safe_ditto "$src" "$dst" || die "複製失敗：$src"
      find "$dst" -user "$OLD_UID" -exec chown -h "$NEW_UID:admin" {} +
      LOCAL_COPIED=$((LOCAL_COPIED + $(find "$dst" -mindepth 1 | wc -l)))
      LOCAL_COPIED_PATHS+=("$dst")
      chown "$NEW_UID:admin" "$dst"
      chmod "$(stat -f %Lp "$src")" "$dst"
      continue
    fi
    while IFS= read -r -d '' item; do
      rel=${item#"$src"}; dst="$ROOT/usr/local/$dir$rel"
      if [[ -d $item && ! -L $item ]]; then
        [[ ! -L $dst ]] || die "拒絕符號連結目的目錄：$dst"
        if [[ ! -d $dst ]]; then
          mkdir -p "$dst"
          owner=$(stat -f %u "$item")
          if [[ $owner == "$OLD_UID" ]]; then chown "$NEW_UID:admin" "$dst"; fi
          chmod "$(stat -f %Lp "$item")" "$dst"
        fi
      elif [[ -e $dst || -L $dst ]]; then
        LOCAL_SKIPPED+=("$dst")
      else
        safe_ditto "$item" "$dst" || die "複製失敗：$item"
        owner=$(stat -f %u "$item")
        if [[ $owner == "$OLD_UID" ]]; then chown -h "$NEW_UID:admin" "$dst"; fi
        LOCAL_COPIED=$((LOCAL_COPIED + 1))
        LOCAL_COPIED_PATHS+=("$dst")
      fi
    done < <(find "$src" -mindepth 1 -print0)
    chown "$NEW_UID:admin" "$ROOT/usr/local/$dir"
    chmod "$(stat -f %Lp "$src")" "$ROOT/usr/local/$dir"
  done
  return 0
}

PLIST_DIR="$DATA_ROOT/private/var/db/dslocal/nodes/Default/users"
declare -a CANDIDATES=()
while IFS= read -r -d '' home; do
  name=${home##*/}
  [[ $name == Shared || $name == Guest || $name == "${SUDO_USER:-tempadmin}" || $name == .* ]] && continue
  [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || continue
  [[ -L $home ]] && continue
  uid=$(stat -f %u "$home"); full=$name
  [[ -z $uid || $uid =~ ^[0-9]+$ ]] || continue
  [[ -z $uid || $uid -ge 500 ]] || continue
  CANDIDATES+=("$name")
  printf '帳號：%s｜全名：%s｜原 UID：%s｜家目錄：%s 位元組\n' "$name" "$full" "${uid:-未知}" "$(size_bytes "$home")"
done < <(find "$DATA_ROOT/Users" -mindepth 1 -maxdepth 1 -type d -print0)
((${#CANDIDATES[@]} > 0)) || die '找不到一般使用者家目錄'
if [[ -n $USER_OPT ]]; then
  USER_NAME=''; for name in "${CANDIDATES[@]}"; do [[ $name == "$USER_OPT" ]] && USER_NAME=$name; done
  [[ -n $USER_NAME ]] || die '--user 不在候選帳號中'
elif ((${#CANDIDATES[@]} == 1)); then USER_NAME=${CANDIDATES[0]}
elif [[ $MODE == list ]]; then USER_NAME=''
else
  printf '多個帳號，請輸入要還原的短名稱：'
  prompt_read; USER_NAME=$REPLY
  found=0; for name in "${CANDIDATES[@]}"; do [[ $name == "$USER_NAME" ]] && found=1; done
  [[ $found == 1 ]] || die '選取帳號不在候選清單中'
fi
[[ $MODE != list ]] || { say '僅列出快照及帳號；未建立帳號或還原資料'; exit 0; }
SRC="$DATA_ROOT/Users/$USER_NAME"
count_keychain_exclusions
collect_standard_acl
for protected in "$SRC/Library/Mail" "$SRC/Library/Safari" "$SRC/Library/Keychains"; do
  [[ -d $protected ]] || continue
  probe_error=$(ls "$protected" 2>&1 >/dev/null) || {
    [[ $probe_error != *'Operation not permitted'* ]] || die '完整取用磁碟不足：系統設定 → 隱私權與安全性 → 完整取用磁碟 → SSH 加入 /usr/libexec/sshd-keygen-wrapper；本機加入「終端機」。重新連線後重跑。'
    die "無法讀取受保護資料：$probe_error"
  }
done
FULL_NAME=$USER_NAME
# 只讀 realname（顯示名稱）；其他屬性一律不讀
if [[ -f $PLIST_DIR/$USER_NAME.plist ]]; then
  FULL_NAME=$(plutil -extract realname.0 raw -o - "$PLIST_DIR/$USER_NAME.plist" 2>/dev/null || printf '%s' "$USER_NAME")
  [[ -n $FULL_NAME ]] || FULL_NAME=$USER_NAME
fi
OLD_UID=$(stat -f %u "$DATA_ROOT/Users/$USER_NAME")
[[ $USER_NAME != "${SUDO_USER:-tempadmin}" && $USER_NAME =~ ^[A-Za-z0-9._-]+$ ]] || die '拒絕此短名稱'
DEST="$ROOT/Users/$USER_NAME"
SRC_BYTES=$(size_bytes "$SRC")
APPS_BYTES=0
declare -a APP_SOURCES=()
if [[ $APPS == 1 && -d $DATA_ROOT/Applications ]]; then
  while IFS= read -r -d '' app; do
    base=${app##*/}
    [[ -e $ROOT/Applications/$base || -L $ROOT/Applications/$base ]] && continue
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true)
    [[ $bundle_id == com.apple.* || $bundle_id == com.apple || $base == Safari.app || $base == Mail.app || $base == Photos.app || $base == App\ Store.app || $base == System\ Settings.app ]] && continue
    APP_SOURCES+=("$app")
    APPS_BYTES=$((APPS_BYTES + $(size_bytes "$app")))
  done < <(find "$DATA_ROOT/Applications" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print0)
fi
LOCAL_BYTES=0
if [[ $USR_LOCAL == 1 ]]; then
  for dir in bin Caskroom Cellar etc Frameworks Homebrew include lib opt sbin share var; do
    [[ -d $DATA_ROOT/usr/local/$dir ]] || continue
    LOCAL_BYTES=$((LOCAL_BYTES + $(size_bytes "$DATA_ROOT/usr/local/$dir")))
  done
fi
need_space "$((SRC_BYTES + APPS_BYTES + LOCAL_BYTES))"
LOCAL_PREVIEW=()
if [[ $USR_LOCAL == 1 && -d $DATA_ROOT/usr/local ]]; then
  for dir in bin Caskroom Cellar etc Frameworks Homebrew include lib opt sbin share var; do
    [[ -d $DATA_ROOT/usr/local/$dir ]] && LOCAL_PREVIEW+=("$dir")
  done
fi
MISSING_HELPERS=()
for dir in LaunchDaemons LaunchAgents PrivilegedHelperTools; do
  [[ -d $DATA_ROOT/Library/$dir ]] || continue
  while IFS= read -r -d '' helper; do
    base=${helper##*/}
    [[ -e $ROOT/Library/$dir/$base || -L $ROOT/Library/$dir/$base ]] || MISSING_HELPERS+=("/Library/$dir/$base")
  done < <(find "$DATA_ROOT/Library/$dir" -mindepth 1 -maxdepth 1 -print0)
done
say "計畫：${USER_NAME}（${FULL_NAME}），原 UID=${OLD_UID:-未知}，家目錄=${SRC_BYTES} 位元組，新增應用程式=${#APP_SOURCES[@]} 個／${APPS_BYTES} 位元組"
if ((${#APP_SOURCES[@]})); then for app in "${APP_SOURCES[@]}"; do say "  將還原：${app##*/}（$(($(size_bytes "$app") / 1048576)) MB）"; done; fi
say "Keychains 排除 $KEY_EXCLUDED 項；舊 login.keychain-db：$([[ -f $SRC/Library/Keychains/login.keychain-db ]] && echo 將改名 || echo 無)"
say "標準資料夾預計補回 deny delete：${#STANDARD_DIRS[@]} 個"
say "/usr/local 預計處理：${LOCAL_PREVIEW[*]:-無}；衝突會列出並跳過"
if [[ $MODE == dry && $USR_LOCAL == 1 ]]; then
  for dir in "${LOCAL_PREVIEW[@]+"${LOCAL_PREVIEW[@]}"}"; do
    while IFS= read -r -d '' item; do
      [[ -d $item && ! -L $item ]] && continue
      rel=${item#"$DATA_ROOT/usr/local/$dir"}
      target="$ROOT/usr/local/$dir$rel"
      [[ -e $target || -L $target ]] && say "  將跳過既有項目：$target"
    done < <(find "$DATA_ROOT/usr/local/$dir" -mindepth 1 -print0)
  done
fi
say "只列出、不安裝的 helper：${#MISSING_HELPERS[@]} 項"
for helper in "${MISSING_HELPERS[@]+"${MISSING_HELPERS[@]}"}"; do say "  $helper"; done
[[ -f $PLIST_DIR/$USER_NAME.plist ]] && say '頭貼：僅檢查 jpegphoto、picture'
[[ $MODE != dry ]] || { say '模擬完成；未建立帳號或寫入目標資料'; exit 0; }
printf '確認來源、帳號、大小及目的地後，輸入 yes 才開始：'
prompt_read; answer=$REPLY
[[ $answer == yes ]] || die '使用者未輸入 yes'

# --apps-only：家目錄已還原（例如上次中途停在應用程式前），只補應用程式。
if [[ $APPS_ONLY == 1 ]]; then
  [[ $APPS == 1 ]] || die "--apps-only 不能和 --no-apps 一起用"
  dscl . -read "/Users/$USER_NAME" >/dev/null 2>&1 || die "--apps-only 需要帳號 $USER_NAME 已存在"
  [[ -d $DEST ]] || die "--apps-only 需要家目錄 $DEST 已存在"
  NEW_UID=$(id -u "$USER_NAME")
  NEW_GID=$(id -g "$USER_NAME")
  say "只補應用程式；不動帳號與家目錄"
else
if dscl . -read "/Users/$USER_NAME" >/dev/null 2>&1; then
  say "帳號已存在：${USER_NAME}；不重建"
else
  UID_ARGS=()
  if [[ $OLD_UID =~ ^[0-9]+$ ]] && ! dscl . -search /Users UniqueID "$OLD_UID" 2>/dev/null | grep -q .; then UID_ARGS=(-UID "$OLD_UID"); fi
  say "建立管理員帳號：${USER_NAME}；密碼由 sysadminctl 自行隱藏提示"
  if ((${#UID_ARGS[@]})); then
    sysadminctl -addUser "$USER_NAME" -fullName "$FULL_NAME" -admin "${UID_ARGS[@]+"${UID_ARGS[@]}"}" -password - || die '建立帳號失敗'
  else
    sysadminctl -addUser "$USER_NAME" -fullName "$FULL_NAME" -admin -password - || die '建立帳號失敗'
  fi
fi
NEW_UID=$(id -u "$USER_NAME") || die '無法查詢新 UID'
NEW_GID=$(id -g "$USER_NAME") || die '無法查詢新 GID'
say "新 UID=${NEW_UID}；GID=${NEW_GID}"
if [[ -e $DEST || -L $DEST ]]; then
  [[ -d $DEST && ! -L $DEST ]] || die '目的家目錄不是一般目錄'
  # sysadminctl 會從 User Template 建骨架，系統服務（cfprefsd 等）也會在 Library 下自動生檔；
  # Library 以外只准範本檔，整個目錄不得超過 20 MB，否則視為有使用者資料。
  unexpected=''
  while IFS= read -r -d '' f; do
    rel=${f#"$DEST"/}; base=${f##*/}
    [[ $base == .localized || $base == .CFUserTextEncoding || $base == .DS_Store ]] && continue
    [[ $rel == Library/* ]] && continue
    in_tpl=0
    for tpl in "$ROOT/System/Library/User Template"/*/; do [[ -e $tpl$rel ]] && { in_tpl=1; break; }; done
    [[ $in_tpl == 1 ]] || { unexpected=$f; break; }
  done < <(find "$DEST" -mindepth 1 ! -type d -print0)
  tpl_kb=$(du -sk "$DEST" | awk '{print $1}')
  [[ -n $unexpected || $tpl_kb -le 20480 ]] || unexpected="骨架超過 20 MB（${tpl_kb} KB）"
  [[ -z $unexpected ]] || die "目的家目錄已有資料，拒絕覆蓋：${DEST}（${unexpected}）"
  HOLD="$ROOT/Users/.$USER_NAME.empty-$(date +%Y%m%d-%H%M%S)-$$"
  [[ ! -e $HOLD ]] || die '空家目錄保留路徑已存在'
  mv "$DEST" "$HOLD"
  say "空家目錄保留在：$HOLD"
fi
[[ ! -e $DEST && ! -L $DEST ]] || die '目的地已存在'
say '還原家目錄（ditto 保留延伸屬性及檔案硬連結，排除來源 ACL）'
copy_home || die '家目錄複製失敗；請檢查目的地，重跑不會覆蓋'
chown -hR "$NEW_UID:$NEW_GID" "$DEST" || die '調整家目錄擁有者失敗'
restore_standard_acl || die '補回標準資料夾 ACL 失敗'
fi
KEY_RESULT='無舊登入鑰匙圈'
[[ $APPS_ONLY == 0 ]] || KEY_RESULT='未處理（--apps-only）'
if [[ $APPS_ONLY == 0 && -f $DEST/Library/Keychains/login.keychain-db ]]; then
  stamp=${SNAP_NAME#com.apple.TimeMachine.}; stamp=${stamp%.backup}
  key_new="$DEST/Library/Keychains/login-old-$stamp.keychain-db"
  [[ ! -e $key_new ]] || die "舊鑰匙圈改名目標已存在：$key_new"
  mv "$DEST/Library/Keychains/login.keychain-db" "$key_new"
  KEY_RESULT="已改名為 ${key_new##*/}"
fi
PHOTO_RESULT='來源沒有可用頭貼'
[[ $APPS_ONLY == 0 ]] || PHOTO_RESULT='未處理（--apps-only）'
if [[ $APPS_ONLY == 0 && -f $PLIST_DIR/$USER_NAME.plist ]]; then
  picture=$(plutil -extract picture.0 raw -o - "$PLIST_DIR/$USER_NAME.plist" 2>/dev/null || plutil -extract picture raw -o - "$PLIST_DIR/$USER_NAME.plist" 2>/dev/null || true)
  if [[ -n $picture && -f $picture ]]; then
    dscl . -delete "/Users/$USER_NAME" JPEGPhoto 2>/dev/null || true
    if dscl . -create "/Users/$USER_NAME" Picture "$picture"; then PHOTO_RESULT="已採用目標現存圖片：$picture"
    else PHOTO_RESULT='警告：設定 Picture 失敗，請手動換頭貼'; fi
  else
    jpeg_b64=$(plutil -extract jpegphoto.0 raw -o - "$PLIST_DIR/$USER_NAME.plist" 2>/dev/null || true)
    if [[ -n $jpeg_b64 ]]; then
      photo="$ROOT/Library/User Pictures/Custom/$USER_NAME.jpg"
      mkdir -p "$(dirname "$photo")"
      PHOTO_RESULT='警告：頭貼匯入失敗，請手動換頭貼'
      if printf '%s' "$jpeg_b64" | base64 -D > "$photo"; then
        chown root:wheel "$photo"; chmod 644 "$photo"
        import_file=$(mktemp /private/tmp/oclp-notes-photo.XXXXXX)
        printf '0x0A 0x5C 0x3A 0x2C dsRecTypeStandard:Users 2 dsAttrTypeStandard:RecordName externalbinary:dsAttrTypeStandard:JPEGPhoto\n%s:%s\n' "$USER_NAME" "$photo" > "$import_file"
        dscl . -delete "/Users/$USER_NAME" JPEGPhoto 2>/dev/null || true
        if dsimport "$import_file" /Local/Default M && dscl . -create "/Users/$USER_NAME" Picture "$photo"; then
          PHOTO_RESULT="已匯入 JPEGPhoto：$photo"
        fi
        rm -f "$import_file"
      fi
      unset jpeg_b64
    fi
  fi
fi
APP_RESTORED=()
if ((${#APP_SOURCES[@]})); then
  for app in "${APP_SOURCES[@]}"; do
    base=${app##*/}
    [[ ! -e $ROOT/Applications/$base && ! -L $ROOT/Applications/$base ]] || continue
    say "還原應用程式：$base"
    safe_ditto "$app" "$ROOT/Applications/$base" || die "應用程式複製失敗：$base"
    # 備份裡的 app 擁有者是舊 UID（可能與臨時管理員相同）；改給正式帳號，Sparkle 類自動更新才寫得進去
    chown -hR "$(id -u "$USER_NAME"):admin" "$ROOT/Applications/$base" || die "調整應用程式擁有者失敗：$base"
    APP_RESTORED+=("$ROOT/Applications/$base")
  done
fi
restore_local
# 逐檔比對：類型、檔案大小、符號連結目標（目錄只比類型）；全文存到紀錄旁，畫面只列前 20 筆。
VERIFY_BASE="/var/log/oclp-notes-restore-verify-$(date +%Y%m%d-%H%M%S)"
[[ $TEST == 0 ]] || VERIFY_BASE="$ROOT/verify"
say "逐檔比對家目錄（可能要幾分鐘）"
verify_tree_filtered() {
  local src=$1 dst=$2 out=$3 side file
  for side in src dst; do
    if [[ $side == src ]]; then file=$src; else file=$dst; fi
    ( cd "$file" && find . -print0 | xargs -0 stat -f '%HT|%z|%Y|%N' ) > "$out.$side.raw" 2>"$out.$side.err" || die "逐檔列舉失敗：${file}；見 $out.$side.err"
    [[ ! -s $out.$side.err ]] || die "逐檔列舉有錯誤：${file}；見 $out.$side.err"
    awk -F'|' -v stamp="$stamp" -v side="$side" '
      BEGIN {OFS="|"}
      $1=="Directory" {$2=""; $3=""}
      side=="src" {
        if ($4 ~ /^\.\/Library\/Keychains\/login\.keychain-db\.sb-/) next
        if ($4 ~ /^\.\/Library\/Keychains\//) {
          t=$4; sub(/^\.\/Library\/Keychains\//,"",t); split(t,a,"/")
          u=a[1]
          if (length(u)==36 && u ~ /^[0-9A-Fa-f-]+$/ &&
              substr(u,9,1)=="-" && substr(u,14,1)=="-" &&
              substr(u,19,1)=="-" && substr(u,24,1)=="-") next
        }
        if ($4=="./Library/Keychains/login.keychain-db")
          $4="./Library/Keychains/login-old-" stamp ".keychain-db"
      }
      {print}
    ' "$out.$side.raw" | sort > "$out.$side"
    rm -f "$out.$side.raw"
  done
  comm -23 "$out.src" "$out.dst" > "$out.missing"
  comm -13 "$out.src" "$out.dst" > "$out.extra"
  VERIFY_ITEMS=$(wc -l < "$out.src" | tr -d ' ')
  VERIFY_DIFFS=$(( $(wc -l < "$out.missing") + $(wc -l < "$out.extra") ))
  say "逐檔比對：來源 $VERIFY_ITEMS 項；差異 $VERIFY_DIFFS 項，清單：$out.missing、$out.extra"
  head -20 "$out.missing" | while IFS= read -r line; do say "  缺／異：$line"; done
}
stamp=${SNAP_NAME#com.apple.TimeMachine.}; stamp=${stamp%.backup}
verify_tree_filtered "$SRC" "$DEST" "$VERIFY_BASE"
ACL_REPORT="$VERIFY_BASE.tm-acl"
: > "$ACL_REPORT"
scan_tm_acl "$DEST" "$ACL_REPORT"
for app in "${APP_RESTORED[@]+"${APP_RESTORED[@]}"}"; do scan_tm_acl "$app" "$ACL_REPORT"; done
for item in "${LOCAL_COPIED_PATHS[@]+"${LOCAL_COPIED_PATHS[@]}"}"; do scan_tm_acl "$item" "$ACL_REPORT"; done
ACL_BAD=$(wc -l < "$ACL_REPORT" | awk '{print int($1/2)}')
say "ACL 檢查：TM 保護 ACE 殘留 $ACL_BAD 項；標準資料夾 deny delete 補回 ${ACL_RESTORED:-0} 個"
if [[ $ACL_BAD -gt 0 ]]; then head -40 "$ACL_REPORT" | while IFS= read -r line; do say "  $line"; done; fi
say "帳號：$(id "$USER_NAME")"
dscl . -read "/Users/$USER_NAME" UniqueID PrimaryGroupID NFSHomeDirectory RealName | while IFS= read -r line; do say "dscl：$line"; done
say "來源家目錄：$SRC_BYTES 位元組；目的家目錄：$(size_bytes "$DEST") 位元組"
if [[ $TEST == 0 ]]; then
  find "$DEST" ! -user "$USER_NAME" -print | head -20 | while IFS= read -r line; do say "擁有者抽查異常：$line"; done
else
  say '測試模式：擁有者抽查由假 id/chown 呼叫紀錄驗證'
fi
if [[ -d $DEST/Library/Keychains ]]; then say 'Keychains 資料夾存在'; else say '注意：來源沒有 Keychains 資料夾'; fi
say "摘要：帳號=${USER_NAME} UID=${NEW_UID}；家目錄還原 ${VERIFY_ITEMS} 項、差異 ${VERIFY_DIFFS} 項"
say "摘要：Keychains 排除 ${KEY_EXCLUDED} 項；舊鑰匙圈：${KEY_RESULT}；頭貼：${PHOTO_RESULT}"
say "摘要：/usr/local 搬入 ${LOCAL_COPIED:-0} 項；衝突跳過 ${#LOCAL_SKIPPED[@]} 項"
for item in "${LOCAL_COPIED_PATHS[@]+"${LOCAL_COPIED_PATHS[@]}"}"; do say "  搬入：$item"; done
for item in "${LOCAL_SKIPPED[@]+"${LOCAL_SKIPPED[@]}"}"; do say "  跳過：$item"; done
say "摘要：helper 缺少 ${#MISSING_HELPERS[@]} 項（只列出，未安裝）"
for helper in "${MISSING_HELPERS[@]+"${MISSING_HELPERS[@]}"}"; do say "  $helper"; done
say "摘要：ACL 殘留 $ACL_BAD 項；標準資料夾補回 ${ACL_RESTORED:-0} 個"
[[ $VERIFY_DIFFS == 0 && $ACL_BAD == 0 ]] || die '驗證發現差異或 TM ACL 殘留'
SUCCESS=1
say '還原完成。首次登入前不要讓別的程序登入該帳號；請登出臨時管理員，再用正式帳號登入。'
