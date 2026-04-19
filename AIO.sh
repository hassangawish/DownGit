#!/usr/bin/env zsh
clear
set +e

# =========================
# AUTO UPDATE SYSTEM
# =========================

VERSION="1.0"

REPO_RAW="https://raw.githubusercontent.com/hassangawish/DownGit/master"
DRIVE_FILE_ID="1AUX2K1xPMq7rgo7iS26_eLHpGv_wHYWw"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

check_for_update() {

  echo "🔍 Checking for updates..."

  latest=$(curl -s "$REPO_RAW/version.txt?$(date +%s)")

  if [[ -z "$latest" ]] || [[ "$latest" == *"404"* ]]; then
    echo "❌ Version check failed: $latest"
    return
  fi

  if [[ -f ".local_version" ]]; then
    current=$(cat .local_version)
  else
    current="$VERSION"
  fi

  echo "📌 Current: $current | Latest: $latest"

  if [[ "$latest" != "$current" ]]; then
    echo "🚀 New update found ($latest)"
    update_system "$latest"
  else
    echo "✅ Up to date"
  fi
}

download_apps() {
  echo "⬇️ Downloading apps..."

  # ✅ Check gdown installed
  if ! command -v gdown >/dev/null 2>&1; then
    echo "❌ gdown not installed. Install it with: pip3 install gdown"
    return 1
  fi

  URL="https://drive.google.com/uc?id=${DRIVE_FILE_ID}"

  gdown "$URL" -O apps.zip

  if [[ $? -ne 0 ]]; then
    echo "❌ gdown failed"
    return 1
  fi
}

update_system() {

  new_version="$1"

  cd "$SCRIPT_DIR" || exit

  echo "⬇️ Updating script..."
  curl -s "$REPO_RAW/AIO.sh" -o AIO.sh
  chmod +x AIO.sh

  echo "📦 Updating apps..."
  rm -rf apk apps.zip

  download_apps

if [[ ! -f apps.zip ]] || [[ $(stat -f%z apps.zip) -lt 1000000 ]]; then
  echo "❌ Download failed"
  return 1
fi

  unzip -o apps.zip > /dev/null
  rm -rf apps.zip

  # 💥 أهم سطر
  echo "$new_version" > .local_version

  echo "✅ Update complete"
  echo "♻️ Restarting..."

  exec "$SCRIPT_DIR/AIO.sh"
}

# شغّل التحديث أول ما يفتح
check_for_update

# =========================
# ORIGINAL SCRIPT (بدون حذف)
# =========================

cd "$SCRIPT_DIR"

ADB="${ADB:-adb}"
TARGET_DEVICE=""

export SKIP_JDK_VERSION_CHECK=true

USE_ALL_USERS=false

get_package_name() {
  local apk="$1"
  aapt dump badging "$apk" 2>/dev/null | grep "package: name=" | awk -F"'" '{print $2}'
}

get_all_users() {
  ADB_CMD shell pm list users | sed -n 's/.*{\([0-9]*\):.*/\1/p'
}

install_for_all_users() {
  local apk="$1"
  local pkg="$2"

  local users
  users=$(get_all_users)

  for user in $users; do
    echo "👤 Installing for user: $user"
    ADB_CMD install -r -g --user "$user" "$apk" || true
  done
}

select_device() {
  echo "🔍 Checking devices..."

  local devices
  devices=$($ADB devices | grep -w "device" | awk '{print $1}')

  local count
  count=$(echo "$devices" | sed '/^$/d' | wc -l | tr -d ' ')

  if [[ "$count" -eq 1 ]]; then
    TARGET_DEVICE="$devices"
    echo "✅ Using device: $TARGET_DEVICE"

  elif [[ "$count" -gt 1 ]]; then
    TARGET_DEVICE=$(echo "$devices" | head -n1)
    echo "⚠️ Multiple devices → using: $TARGET_DEVICE"

  else
    echo "❌ No USB device"
    echo -n "📡 Enter Wireless ADB IP: "
    read ip

    $ADB connect "$ip"
    sleep 2

    [[ "$ip" != *":"* ]] && TARGET_DEVICE="$ip:5555" || TARGET_DEVICE="$ip"
  fi
}

ADB_CMD() {
  $ADB -s "$TARGET_DEVICE" "$@"
}

disconnect_if_wireless() {
  [[ "$TARGET_DEVICE" == *":"* ]] && $ADB disconnect "$TARGET_DEVICE"
}

wait_for_adb() {
  echo "⏳ Waiting for device..."
  $ADB -s "$TARGET_DEVICE" wait-for-device
}

install_apk_safe() {
  local apk="$1"
  local pkg=""

  echo "📦 Installing: $(basename "$apk")"

  pkg=$(get_package_name "$apk")

  output=$(ADB_CMD install -r -d -g "$apk" 2>&1)
  echo "$output"

  if echo "$output" | grep -q -E "INSTALL_FAILED_UPDATE_INCOMPATIBLE|INSTALL_FAILED_VERSION_DOWNGRADE"; then
    echo "💣 Conflict detected..."

    if [[ -n "$pkg" ]]; then
      for user in $(get_all_users); do
        ADB_CMD shell pm uninstall --user "$user" "$pkg" || true
      done

      ADB_CMD install -r -g "$apk" || true
    fi
  fi
}

install_apks_in_folder() {
  local folder="$1"

  [[ ! -d "$folder" ]] && echo "❌ Folder not found: $folder" && return

  setopt nullglob
  for apk in "$folder"/*.apk; do
    [[ -e "$apk" ]] || continue
    install_apk_safe "$apk"
  done
  unsetopt nullglob
}

# =========================
# ORIGINAL FUNCTIONS (UNCHANGED)
# =========================

central() {
  clear
  select_device
  wait_for_adb

  echo "Installing Apps on Both Screens (BYD)"

  install_apks_in_folder "apk"

  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/apk/Ayah/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/apk/Downloader/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/apk/Netflix/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/apk/Yandex/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/apk/video/*.apk || true

  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME

  ADB_CMD shell appops set --user 0 com.t4w.ostora516 REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD push /Users/hassan/Desktop/apk/apk/VIP.conf /sdcard

  echo "Installed Success"
  disconnect_if_wireless
}

voice() {
  clear
  select_device
  wait_for_adb

  echo "Disable Chinese Voice (BYD)"

  ADB_CMD shell pm disable-user "com.android.voicereminder" || true
  ADB_CMD shell pm disable-user "com.byd.autovoice" || true
  ADB_CMD shell pm disable-user "com.byd.autovoice.tts" || true
  ADB_CMD shell pm disable-user "com.byd.autovoice.engine" || true

  echo "Done"
  disconnect_if_wireless
}

simcard() {
  clear
  select_device
  wait_for_adb

  echo "Sim-Card Enable..Process (BYD)"

  ADB_CMD shell pm disable-user "com.byd.trafficmonitor" || true

  echo "Done"
  disconnect_if_wireless
}

ROX() {
  clear
  select_device
  wait_for_adb

  echo "Install apps on Both Screen (rox)"

  install_apks_in_folder "Rox"

  ADB_CMD install -t -g --user 0 /Users/hassan/Desktop/apk/rox/Launcher/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/rox/Ayah/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/rox/Downloader/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/rox/video/*.apk || true

  ADB_CMD shell am start -n com.roxmotor.nonpreinstallapp/com.roxmotor.nonpreinstallapp.MainActivity2

  ADB_CMD shell appops set --user 0 com.t4w.ostora516 REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true

  ADB_CMD shell settings put secure enabled_accessibility_services nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService
  ADB_CMD shell settings put secure accessibility_enabled 1

  disconnect_if_wireless
}

Rox-Unlock() {
  clear
  select_device
  wait_for_adb

  echo "Unlocking Screen (rox)"

  ADB_CMD shell getprop vnrpst.engineermode.geofenceLock
  ADB_CMD shell setprop vnrpst.engineermode.geofenceLock '{"geofenceLock_state":0,"geofenceLock_time":0}'
  ADB_CMD shell pm disable-user --user 0 com.roxmotor.sceneeditapp

  ADB_CMD reboot
  disconnect_if_wireless
}

zeekr() {
  clear
  select_device
  wait_for_adb

  echo "Installing Apps on Zeekr Screens"

  ADB_CMD root || true

  ADB_CMD shell su -c "pm disable com.ecarx.xsfinstallverifier" || true
  ADB_CMD shell su -c "settings put global package_verifier_enable 0" || true
  ADB_CMD shell su -c "settings put global verifier_verify_adb_installs 0" || true

  install_apks_in_folder "Zeekr"

  ADB_CMD shell settings put global time_zone Asia/Karachi || true
  ADB_CMD shell service call alarm 3 s16 "Asia/Karachi" || true

  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true

  ADB_CMD install -g "zeekr/simplecontrol.apk" || true

  ADB_CMD shell pm grant jp.co.c_lis.ccl.morelocale android.permission.CHANGE_CONFIGURATION || true
  ADB_CMD shell appops set --user 0 ace.jun.simplecontrol BIND_ACCESSIBILITY_SERVICE allow || true
  ADB_CMD shell settings put secure enabled_accessibility_services ace.jun.simplecontrol/ace.jun.simplecontrol.service.AccService || true

  echo "Installed Success"
  disconnect_if_wireless
}

dashing() {
  clear
  select_device
  wait_for_adb

  echo "Installing Apps on Dashing Screens"

  install_apks_in_folder "Dashing"

  ADB_CMD shell am start -n com.appindustry.everywherelauncher/com.michaelflisar.everywherelauncher.ui.activitiesandfragments.MainActivity || true

  ADB_CMD shell settings put global time_zone Asia/Karachi || true
  ADB_CMD shell service call alarm 3 s16 "Asia/Karachi" || true

  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true

  ADB_CMD install -g "dashing/simplecontrol.apk" || true

  ADB_CMD shell pm grant jp.co.c_lis.ccl.morelocale android.permission.CHANGE_CONFIGURATION || true
  ADB_CMD shell appops set --user 0 ace.jun.simplecontrol BIND_ACCESSIBILITY_SERVICE allow || true
  ADB_CMD shell settings put secure enabled_accessibility_services ace.jun.simplecontrol/ace.jun.simplecontrol.service.AccService || true

  echo "Installed Success"
  disconnect_if_wireless
}

lixiang() {
  clear
  select_device
  wait_for_adb

  echo "Installing Apps on Lixiang Screens"

  install_apks_in_folder "LIAUTO"

  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/rox/Ayah/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/rox/Downloader/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/rox/video/*.apk || true

  ADB_CMD shell appops set --user 0 com.t4w.ostora516 REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 6174 com.t4w.ostora516 REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 21473 com.t4w.ostora516 REQUEST_INSTALL_PACKAGES allow || true

  ADB_CMD shell appops set --user 0 com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 6174 com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 21473 com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true

  ADB_CMD shell appops set --user 0 com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 6174 com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 21473 com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true

  ADB_CMD shell appops set --user 0 com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 6174 com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 21473 com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true

  ADB_CMD shell appops set --user 0 cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 6174 cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 21473 cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true

  ADB_CMD shell ime enable --user 0 com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true
  ADB_CMD shell ime enable --user 0 com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true

  ADB_CMD shell ime enable --user 6174 com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true
  ADB_CMD shell ime enable --user 6174 com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true

  ADB_CMD shell ime enable --user 21473 com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true
  ADB_CMD shell ime enable --user 21473 com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true

  ADB_CMD shell settings put secure enabled_accessibility_services nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService
  ADB_CMD shell settings put secure accessibility_enabled 1

  echo "Installed Success"
  disconnect_if_wireless
}

haval() {
  clear
  select_device
  wait_for_adb

  echo "Installing Apps on Haval"

  install_apks_in_folder "Haval"

  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Ayah/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Downloader/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Yandex/*.apk || true

  ADB_CMD shell appops set --user 0 com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true

  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true

  echo "Installed Successfully"
  disconnect_if_wireless
}

Jetout() {
  clear
  select_device
  wait_for_adb

  echo "Installing Apps on Jetour"

  ADB_CMD push Jetour /data/local/tmp/ > /dev/null

  ADB_CMD shell << 'EOF'
cd /data/local/tmp/Jetour
for f in *.apk; do pm install --user 0 "$f"; done
EOF

  ADB_CMD shell appops set --user 0 com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true

  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME || true

  echo "Installed Successfully"
  disconnect_if_wireless
}

G700() {
  clear
  select_device
  wait_for_adb

  echo "Installing Apps on G700"

install_apks_in_folder "G700"

  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Ayah/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Downloader/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Yandex/*.apk || true

  ADB_CMD shell appops set --user 0 com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
:: Keyboard
  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >nul 2>&1
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >nul 2>&1

  ADB_CMD shell appops set --user 0 ace.jun.simplecontrol BIND_ACCESSIBILITY_SERVICE allow || true
  ADB_CMD shell settings put secure enabled_accessibility_services ace.jun.simplecontrol/ace.jun.simplecontrol.service.AccService || true

  echo "Installed Successfully"
  disconnect_if_wireless
}

LYNK() {
  clear
  select_device
  wait_for_adb

  echo "Installing Apps on LYNK&CO"

  USE_ALL_USERS=true
  install_apks_in_folder "LYNK"
  USE_ALL_USERS=false

  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Ayah/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Downloader/*.apk || true
  ADB_CMD install-multiple -r /Users/hassan/Desktop/apk/Haval/Yandex/*.apk || true

  ADB_CMD shell appops set --user 0 com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
  ADB_CMD shell appops set --user 0 cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
:: Keyboard
  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >nul 2>&1
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >nul 2>&1

  echo "Installed Successfully"
  disconnect_if_wireless
}

# =========================
# MENU (زي ما هو)
# =========================

menu() {
  while true; do
    echo ""
    echo "=============================="
    echo "   BEST STORE PRO MAX 💀"
    echo "=============================="
    echo ""
    echo "1.  Install Apps (BYD)"
    echo "2.  Disable Chinese (BYD)"
    echo "3.  Activete Sim-Card (BYD)"
    echo "4.  Install Apps (rox)"
    echo "5.  Install Apps (Zeekr)"
    echo "6.  Install Apps (Dashing)"
    echo "7.  Install Apps (LiAuto)"
    echo "8.  Install Apps (Haval)"
    echo "9.  Unlock Screen(rox)"
    echo "10. Install Apps (Jetour)"
    echo "11. Install Apps (G700)"
    echo "12. Install Apps (LYNK&CO)"
    echo "-------------------------------------------------"

    echo -n "CHOOSE: "
    read opt

    case "$opt" in
      1) central ;;
      2) voice ;;
      3) simcard ;;
      4) ROX ;;
      5) zeekr ;;
      6) dashing ;;
      7) lixiang ;;
      8) haval ;;
      9) Rox-Unlock ;;
      10) Jetout ;;
      11) G700 ;;
      12) LYNK ;;
      *) echo "❌ ERROR!" ;;
    esac
  done
}

menu
