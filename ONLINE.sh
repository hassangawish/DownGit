#!/usr/bin/env zsh
#!/bin/zsh
# أو
#!/usr/bin/env zsh
emulate -L zsh   # أضف هذا السطر بعد الـ shebang مباشرة
clear
set +e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

USER_HOME="$HOME"
DESKTOP_APK="$USER_HOME/Desktop/apk"
echo "📁 Using Desktop path: $DESKTOP_APK"

ADB="${ADB:-adb}"
TARGET_DEVICE=""

export SKIP_JDK_VERSION_CHECK=true

# =========================
# HELPER FUNCTIONS
# =========================

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
    return 0
  elif [[ "$count" -gt 1 ]]; then
    TARGET_DEVICE=$(echo "$devices" | head -n1)
    echo "⚠️ Multiple devices → using: $TARGET_DEVICE"
    return 0
  else
    echo "❌ No USB device"
    echo -n "📡 Enter Wireless ADB IP: "
    read -r ip

    if [[ -z "$ip" ]]; then
      echo "❌ No IP entered. Returning to menu..."
      return 1
    fi

    $ADB connect "$ip"
    sleep 2

    if [[ "$ip" != *":"* ]]; then
      TARGET_DEVICE="$ip:5555"
    else
      TARGET_DEVICE="$ip"
    fi

    if $ADB devices | grep -q "$TARGET_DEVICE"; then
      echo "✅ Connected: $TARGET_DEVICE"
      return 0
    else
      echo "❌ Connection failed. Returning to menu..."
      return 1
    fi
  fi
}

ADB_CMD() {
  $ADB -s "$TARGET_DEVICE" "$@" || true
}

disconnect_if_wireless() {
  if [[ "$TARGET_DEVICE" == *":"* ]]; then
    echo "🔌 Disconnecting $TARGET_DEVICE"
    $ADB disconnect "$TARGET_DEVICE" || true
  fi
}

wait_for_adb() {
  echo "⏳ Waiting for device..."
  $ADB -s "$TARGET_DEVICE" wait-for-device || true
}

install_apk_safe() {
  local apk="$1"
  local pkg=""

  echo "📦 Installing: $(basename "$apk")"

  pkg=$(get_package_name "$apk")

  if [[ "$USE_ALL_USERS" == true ]]; then
    echo "🚀 Super Mode → install per user"
    for user in $(get_all_users); do
      echo "👤 User: $user"
      ADB_CMD install -r -d -g --user "$user" "$apk" || true
    done
    return
  fi

  output=$(ADB_CMD install -r -d -g "$apk" 2>&1)
  echo "$output"

  if echo "$output" | grep -q -E "INSTALL_FAILED_UPDATE_INCOMPATIBLE|INSTALL_FAILED_VERSION_DOWNGRADE|INSTALL_FAILED_SIGNATURE_MISMATCH"; then
    echo "💣 Conflict detected..."

    if [[ -n "$pkg" ]]; then
      echo "🗑 Removing old version: $pkg"
      for user in $(get_all_users); do
        ADB_CMD shell pm uninstall --user "$user" "$pkg" || true
      done
      ADB_CMD install -r -d -g "$apk" || true
    else
      echo "❌ Couldn't detect package"
    fi
  fi
}

install_apks_in_folder() {
  local folder="$1"

  if [[ ! -d "$folder" ]]; then
    echo "❌ Folder not found: $folder"
    return 1
  fi

  local found=0

  for apk in "$folder"/*.apk; do
    [[ -f "$apk" ]] || continue
    found=1
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    install_apk_safe "$apk"
  done

  if [[ $found -eq 0 ]]; then
    echo "⚠️ No APK files found in: $folder"
  fi
}

# =========================
# MAIN FUNCTIONS (مع حماية من الكراش)
# =========================

central() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb

  echo "🚀 Installing Apps on BYD"

  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)

  echo "👥 Users: ${USERS[*]}"

  USE_ALL_USERS=true
  install_apks_in_folder "$DESKTOP_APK/apk"
  USE_ALL_USERS=false

  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/apk/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/apk/Downloader"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/apk/Yandex"/*.apk || true
  done

  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.t4w.ostora516 REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true

    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true

    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true

    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
  done

  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true

  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done

  ADB_CMD push "$DESKTOP_APK/apk/VIP.conf" /sdcard || true
  ADB_CMD shell am start -a android.intent.action.BYD_APPSTARTMANAGEMENT || true

  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

voice() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
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
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "Sim-Card Enable..Process (BYD)"
  ADB_CMD shell pm disable-user "com.byd.trafficmonitor" || true
  echo "Done"
  disconnect_if_wireless
}

ROX() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on ROX"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  USE_ALL_USERS=true
  install_apks_in_folder "$DESKTOP_APK/Rox"
  USE_ALL_USERS=false
  for user in "${USERS[@]}"; do
    ADB_CMD install -t -g --user "$user" "$DESKTOP_APK/rox/Launcher"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/Downloader"/*.apk || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell am start --user "$user" -n com.roxmotor.nonpreinstallapp/com.roxmotor.nonpreinstallapp.MainActivity2 || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" org.telegram.messenger.web REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService || true
    ADB_CMD shell settings --user "$user" put secure accessibility_enabled 1 || true
  done
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  ADB_CMD shell wm density 160 || true
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

Rox-Unlock() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "Unlocking Screen (rox)"
  ADB_CMD shell getprop vnrpst.engineermode.geofenceLock
  ADB_CMD shell setprop vnrpst.engineermode.geofenceLock '{"geofenceLock_state":0,"geofenceLock_time":0}'
  ADB_CMD shell setprop vnrpst.engineermode.geofenceLock '{"geofenceLock_state":0,"geofenceLock_time":0}'
  ADB_CMD shell 'setprop vnrpst.engineermode.geofenceLock "{\"geofenceLock_state\":0,\"geofenceLock_time\":0}"'
  ADB_CMD shell pm disable-user --user 0 com.roxmotor.sceneeditapp
  ADB_CMD reboot
  disconnect_if_wireless
}

zeekr() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Zeekr"
  ADB_CMD root || true
  ADB_CMD shell su -c "pm disable com.ecarx.xsfinstallverifier" || true
  ADB_CMD shell su -c "settings put global package_verifier_enable 0" || true
  ADB_CMD shell su -c "settings put global verifier_verify_adb_installs 0" || true
  install_apks_in_folder "$DESKTOP_APK/Zeekr"
  ADB_CMD install -g "zeekr/simplecontrol.apk" || true
  ADB_CMD shell settings put global auto_time 1 || true
  ADB_CMD shell settings put global auto_time_zone 1 || true
  ADB_CMD shell settings put global time_zone Asia/Karachi || true
  ADB_CMD shell service call alarm 3 s16 "Asia/Karachi" || true
  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  ADB_CMD shell pm grant jp.co.c_lis.ccl.morelocale android.permission.CHANGE_CONFIGURATION || true
  ADB_CMD shell pm grant app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
  ADB_CMD shell pm grant app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
  ADB_CMD shell pm grant app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
  ADB_CMD shell appops set --user 0 ace.jun.simplecontrol BIND_ACCESSIBILITY_SERVICE allow || true
  ADB_CMD shell settings put secure enabled_accessibility_services ace.jun.simplecontrol/ace.jun.simplecontrol.service.AccService || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd appops set app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
  ADB_CMD shell cmd appops set app.revanced.android.gms WAKE_LOCK allow || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps WAKE_LOCK allow || true
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

dashing() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Dashing"
  install_apks_in_folder "$DESKTOP_APK/Dashing"
  ADB_CMD shell am start -n com.appindustry.everywherelauncher/com.michaelflisar.everywherelauncher.ui.activitiesandfragments.MainActivity || true
  ADB_CMD install -g "dashing/simplecontrol.apk" || true
  ADB_CMD shell settings put global auto_time 1 || true
  ADB_CMD shell settings put global auto_time_zone 1 || true
  ADB_CMD shell settings put global time_zone Asia/Karachi || true
  ADB_CMD shell service call alarm 3 s16 "Asia/Karachi" || true
  ADB_CMD shell ime enable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  ADB_CMD shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  ADB_CMD shell pm grant jp.co.c_lis.ccl.morelocale android.permission.CHANGE_CONFIGURATION || true
  ADB_CMD shell pm grant app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
  ADB_CMD shell pm grant app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
  ADB_CMD shell pm grant app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
  ADB_CMD shell appops set --user 0 ace.jun.simplecontrol BIND_ACCESSIBILITY_SERVICE allow || true
  ADB_CMD shell settings put secure enabled_accessibility_services ace.jun.simplecontrol/ace.jun.simplecontrol.service.AccService || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd appops set app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
  ADB_CMD shell cmd appops set app.revanced.android.gms WAKE_LOCK allow || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
  ADB_CMD shell cmd appops set app.revanced.android.apps.maps WAKE_LOCK allow || true
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

lixiang() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Li Auto"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  USE_ALL_USERS=true
  install_apks_in_folder "$DESKTOP_APK/LIAUTO"
  USE_ALL_USERS=false
  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/Downloader"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/video"/*.apk || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.t4w.ostora516 REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService || true
    ADB_CMD shell settings --user "$user" put secure accessibility_enabled 1 || true
  done
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

Haval() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Haval"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  USE_ALL_USERS=true
  install_apks_in_folder "$DESKTOP_APK/Haval"
  USE_ALL_USERS=false
  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Downloader"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Yandex"/*.apk || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  done
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

Jetout() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Jetour"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  ADB_CMD push Jetout /data/local/tmp/ >/dev/null || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell "
      cd /data/local/tmp/Jetout
      for f in *.apk; do
        pm install --user $user \"\$f\" || true
      done
    " || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
    ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService || true
    ADB_CMD shell settings --user "$user" put secure accessibility_enabled 1 || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  done
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

G700() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on G700"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  USE_ALL_USERS=true
  install_apks_in_folder "$DESKTOP_APK/G700"
  USE_ALL_USERS=false
  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Downloader"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Yandex"/*.apk || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell appops set --user "$user" ace.jun.simplecontrol BIND_ACCESSIBILITY_SERVICE allow || true
    ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services ace.jun.simplecontrol/ace.jun.simplecontrol.service.AccService || true
  done
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

LYNK() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on LYNK&CO"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  USE_ALL_USERS=true
  install_apks_in_folder "$DESKTOP_APK/LYNK"
  USE_ALL_USERS=false
  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Downloader"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Haval/Yandex"/*.apk || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  done
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

Zeekr9x() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Zeekr 9X"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  USE_ALL_USERS=true
  install_apks_in_folder "$DESKTOP_APK/9X"
  USE_ALL_USERS=false
  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/9X/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/9X/Downloader"/*.apk || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.uptodown REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.aurora.store REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
    ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService || true
    ADB_CMD shell settings --user "$user" put secure accessibility_enabled 1 || true
  done
  ADB_CMD shell ime enable --user 0 com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  ADB_CMD shell ime set --user 0 com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  ADB_CMD shell ime enable --user 10 com.touchtype.swiftkez/com.touchtype.KeyboardService >/dev/null 2>&1 || true
  ADB_CMD shell ime set --user 10 com.touchtype.swiftkez/com.touchtype.KeyboardService >/dev/null 2>&1 || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD -d shell pm clear --user 0 com.zeekr.housekeeper || true
  ADB_CMD -d shell pm disable-user --user 0 com.zeekr.housekeeper || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  ADB_CMD shell settings put global auto_time 1 || true
  ADB_CMD shell settings put global auto_time_zone 1 || true
  ADB_CMD shell settings put global time_zone Asia/Dubai || true
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

Premissions() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🔧 Fixing Zeekr Permissions..."
  ADB_CMD shell settings put system system_locales en || true
  sleep 2
  ADB_CMD shell pm uninstall --user 0 com.ecarx.xsfinstallverifier || true
  ADB_CMD shell pm clear --user 0 com.zeekr.carlauncher3d || true
  ADB_CMD reboot
  wait_for_adb
  sleep 15
  ADB_CMD shell pm clear ecarx.notificationcenterui || true
  ADB_CMD shell settings put system system_locales en || true
  ADB_CMD shell pm uninstall --user 0 com.ecarx.xsfinstallverifier || true
  ADB_CMD shell pm clear --user 0 com.zeekr.carlauncher3d || true
  ADB_CMD shell pm disable-user com.zeekr.fwk.common || true
  ADB_CMD shell pm disable-user --user 0 com.zeekr.fwk.common || true
  ADB_CMD shell settings put global auto_time 1 || true
  ADB_CMD shell settings put global auto_time_zone 1 || true
  ADB_CMD shell settings put global time_zone Asia/Dubai || true
  echo "✅ Zeekr Permissions Fixed"
  read -p "Press Enter to continue..."
  disconnect_if_wireless
}

Leapmotor() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Leapmotor"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  setopt nullglob
  for apk in Leep/*.apk; do
    [[ -e "$apk" ]] || continue
    echo "📦 Installing: $(basename "$apk")"
    for user in "${USERS[@]}"; do
      ADB_CMD install -g -r -t -d --install-reason 64 --user "$user" "$apk" || true
    done
  done
  unsetopt nullglob
  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Leep/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/Leep/Downloader"/*.apk || true
  done
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
    ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService || true
    ADB_CMD shell settings --user "$user" put secure accessibility_enabled 1 || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
  done
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

BYD_OLD() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on BYD OLD"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"
  USE_ALL_USERS=true
  install_apks_in_folder "$DESKTOP_APK/BYD_Old"
  USE_ALL_USERS=false
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.t4w.ostora516 REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
  done
  ADB_CMD push "$DESKTOP_APK/apk/VIP.conf" /sdcard || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.apps.maps || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.apps.maps || true
  for user in "${USERS[@]}"; do
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps WAKE_LOCK allow || true
  done
  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

AVATR() {
  clear
  select_device
  wait_for_adb

  echo "🚀 Installing Apps on AVATR 11 (Fixed Method)"

  # Detect users
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)

  echo "👥 Found Users: ${USERS[*]}"

  # Disable verifier & package installer temporarily
  for user in "${USERS[@]}"; do
    ADB_CMD shell pm disable-user --user "$user" com.android.packageinstaller 2>/dev/null || true
  done

  ADB_CMD shell settings put global package_verifier_enable 0 2>/dev/null || true
  ADB_CMD shell settings put global verifier_verify_adb_installs 0 2>/dev/null || true
  ADB_CMD shell pm disable-user --user 0 com.ecarx.xsfinstallverifier 2>/dev/null || true

  sleep 2

  echo "📦 Installing AVATR APKs..."

  # Main APKs
  for apk in AVATR/*.apk; do
    [[ -f "$apk" ]] || continue
    echo "   → $(basename "$apk")"
    
    for user in "${USERS[@]}"; do
        echo "   👤 User $user"
        ADB_CMD install -r -d -g --user "$user" -i com.huawei.appinstaller.car "$apk" || \
        ADB_CMD install -r -d -g --user "$user" -i com.huawei.appmarket.vehicle "$apk" || true
    done
  done

  # Ayah & Downloader
  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r -d -g --user "$user" -i com.huawei.appmarket.vehicle "$DESKTOP_APK/AVATR/Ayah"/*.apk || true
    ADB_CMD install-multiple -r -d -g --user "$user" -i com.huawei.appinstaller.car "$DESKTOP_APK/AVATR/Downloader"/*.apk || true
  done

  # Permissions
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true

    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true

    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true

    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true

    ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services \
      nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService || true
    ADB_CMD shell settings --user "$user" put secure accessibility_enabled 1 || true

    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
  done

  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true

  # Re-enable package installer
  for user in "${USERS[@]}"; do
    ADB_CMD shell pm enable --user "$user" com.android.packageinstaller 2>/dev/null || true
  done

  echo "🎉 AVATR Installation Completed!"
  disconnect_if_wireless
}

AIOPPREMISSION() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Apps Premissions on AVATR (ALL)"
  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  for user in "${USERS[@]}"; do
    ADB_CMD shell appops set --user "$user" com.esaba.downloader REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.apkpure.aegon REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" com.revanced.net.revancedmanager REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell appops set --user "$user" cm.aptoide.pt REQUEST_INSTALL_PACKAGES allow || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
    ADB_CMD shell pm grant --user "$user" app.revanced.android.apps.maps android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_FINE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_COARSE_LOCATION allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.apps.maps ACCESS_BACKGROUND_LOCATION allow || true
    ADB_CMD shell ime enable --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell ime set --user "$user" com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME >/dev/null 2>&1 || true
    ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService || true
    ADB_CMD shell settings --user "$user" put secure accessibility_enabled 1 || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms RUN_ANY_IN_BACKGROUND allow || true
    ADB_CMD shell cmd appops set --user "$user" app.revanced.android.gms WAKE_LOCK allow || true
  done
  ADB_CMD shell dumpsys deviceidle whitelist +app.revanced.android.gms || true
  ADB_CMD shell cmd deviceidle whitelist +app.revanced.android.gms || true
  echo "🚀 Apps Premissions on AVATR (DONE)"
  disconnect_if_wireless
}

# =========================
# MENU
# =========================

menu() {
  while true; do
    clear
    echo "=============================="
    echo "  💀 BEST STORE PRO MAX 💀"
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
    echo "13. Install Apps (Zeeker9X)"
    echo "14. Zeekr 9X Install Premission"
    echo "15. Install Apps (Leepmotor)"
    echo "16. Install Apps (BYD_OLD)"
    echo "17. Install Apps (AVATR)"
    echo "18. AIO Premission (AIO)"
    echo "0.  Exit & Close Terminal"
    echo "-------------------------------------------------"
    echo -n "CHOOSE: "

    read -r opt

    case "$opt" in
      1) central ;;
      2) voice ;;
      3) simcard ;;
      4) ROX ;;
      5) zeekr ;;
      6) dashing ;;
      7) lixiang ;;
      8) Haval ;;
      9) Rox-Unlock ;;
      10) Jetout ;;
      11) G700 ;;
      12) LYNK ;;
      13) Zeekr9x ;;
      14) Premissions ;;
      15) Leapmotor ;;
      16) BYD_OLD ;;
      17) AVATR ;;
      18) AIOPPREMISSION ;;
      0)
        echo "👋 Closing Terminal..."
        sleep 0.6
        # طريقة قوية جداً لإغلاق الترمنل
        osascript -e 'tell application "Terminal" to close (front window)' 2>/dev/null || true
        kill -9 $PPID 2>/dev/null || kill -9 $$ 2>/dev/null || exit 0
        ;;
      *) echo "❌ Invalid option! Returning to menu..." ;;
    esac

    echo -e "\nPress Enter to return to main menu..."
    read -r
  done
}

menu
