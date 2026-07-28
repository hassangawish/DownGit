#!/bin/bash
# ============================================================
# BEST STORE PRO MAX - Final Full Dynamic & Permissions Version
# All sections updated with consistent permissions + Dynamic Subfolders
# ============================================================

if [ -n "$ZSH_VERSION" ]; then
  emulate -L zsh 2>/dev/null || true
fi

if [ -n "$BASH_VERSION" ]; then
  shopt -s nullglob
fi

clear

# Resize Terminal to 65 columns × 30 rows
printf '\e[8;30;64t'

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR" 2>/dev/null || true

USER_HOME="$HOME"
DESKTOP_APK="$USER_HOME/Desktop/apk"

echo "📍 Working directory: $(pwd)"
echo "📁 Using Desktop path: $DESKTOP_APK"
echo ""

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
  ADB_CMD shell pm list users 2>/dev/null | sed -n 's/.*{\([0-9]*\):.*/\1/p'
}

select_device() {
  echo "🔍 Checking devices..."
  local devices=$($ADB devices | grep -w "device" | awk '{print $1}')
  local count=$(echo "$devices" | sed '/^$/d' | wc -l | tr -d ' ')

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
    local output=""

    echo "📦 Installing: $(basename "$apk")"

    pkg=$(get_package_name "$apk")

    # ===== Super Mode (Install for every user) =====
    if [[ "$USE_ALL_USERS" == true ]]; then

        for user in $(get_all_users); do

            output=$(ADB_CMD install -r -d -g --user "$user" "$apk" 2>&1)

            # Success
            if echo "$output" | grep -q "Success"; then
                printf "   👤 User %-3s ✅ Installed\n" "$user"
                continue
            fi

            # Geely Clone User
            if echo "$output" | grep -qi "geely can't only install on clone user"; then
                if [[ -n "$pkg" ]]; then
                    ADB_CMD shell cmd package install-existing --user "$user" "$pkg" >/dev/null 2>&1 || true
                    printf "   👤 User %-3s ✅ Clone Linked\n" "$user"
                else
                    printf "   👤 User %-3s ❌ Package Unknown\n" "$user"
                fi
                continue
            fi

            # Any other error
            printf "   👤 User %-3s ❌ Failed\n" "$user"
            echo "$output"

        done

        return
    fi

    # ===== Normal Install =====
    output=$(ADB_CMD install -r -d -g "$apk" 2>&1)

    if echo "$output" | grep -q "Success"; then
        echo "   ✅ Installed"
        return
    fi

    # Signature / Downgrade conflict
    if echo "$output" | grep -q -E "INSTALL_FAILED_UPDATE_INCOMPATIBLE|INSTALL_FAILED_VERSION_DOWNGRADE|INSTALL_FAILED_SIGNATURE_MISMATCH"; then

        echo "🔄 Existing version detected..."

        if [[ -n "$pkg" ]]; then

            for user in $(get_all_users); do
                ADB_CMD shell pm uninstall --user "$user" "$pkg" >/dev/null 2>&1 || true
            done

            output=$(ADB_CMD install -r -d -g "$apk" 2>&1)

            if echo "$output" | grep -q "Success"; then
                echo "   ✅ Reinstalled"
            else
                echo "   ❌ Failed"
                echo "$output"
            fi

        else
            echo "❌ Couldn't detect package name."
        fi

    else
        echo "$output"
    fi
}

install_apks_in_folder() {
  local folder="$1"
  if [[ ! -d "$folder" ]]; then
    echo "❌ Folder not found: $folder"
    return 1
  fi
  local found=0
  local apks=("$folder"/*.apk)
  for apk in "${apks[@]}"; do
    [[ -f "$apk" ]] || continue
    found=1
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    install_apk_safe "$apk"
  done
  if [[ $found -eq 0 ]]; then
    echo "⚠️ No APK files found in: $folder"
  fi
}

# === Dynamic Subfolders (Auto ALL) ===
install_from_subfolders() {
    local base_dir="$1"
    local section="$2"

    echo ""
    echo "📂 [$section] Installing from ALL subfolders automatically..."

    local found_any=0

    for sub in "$base_dir"/*/; do
        [[ -d "$sub" ]] || continue

        found_any=1
        local subname
        subname=$(basename "$sub")

        echo "📦 Subfolder: $subname"

        # استخراج اسم الباكدج من أول APK داخل الفولدر
        local first_apk
        first_apk=$(find "$sub" -maxdepth 1 -name "*.apk" | head -n 1)

        local pkg=""
        if [[ -n "$first_apk" ]]; then
            pkg=$(get_package_name "$first_apk")
        fi

        for user in "${USERS[@]}"; do

            output=$(ADB_CMD install-multiple -r -d -g --user "$user" "$sub"*.apk 2>&1)

            # نجاح
            if echo "$output" | grep -q "Success"; then
                printf "   👤 User %-3s ✅ Installed\n" "$user"
                continue
            fi

            # Clone User (Geely)
            if echo "$output" | grep -qi "geely can't only install on clone user"; then

                if [[ -n "$pkg" ]]; then
                    ADB_CMD shell cmd package install-existing --user "$user" "$pkg" >/dev/null 2>&1 || true
                    printf "   👤 User %-3s ✅ Clone Linked\n" "$user"
                else
                    printf "   👤 User %-3s ❌ Package Unknown\n" "$user"
                fi

                continue
            fi

            # Signature conflict
            if echo "$output" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then
                printf "   👤 User %-3s ⚠️ Signature Mismatch\n" "$user"
                continue
            fi

            # Version downgrade
            if echo "$output" | grep -q "INSTALL_FAILED_VERSION_DOWNGRADE"; then
                printf "   👤 User %-3s ⚠️ Version Downgrade\n" "$user"
                continue
            fi

            # Shared library missing
            if echo "$output" | grep -q "INSTALL_FAILED_MISSING_SHARED_LIBRARY"; then
                printf "   👤 User %-3s ⚠️ Missing Library\n" "$user"
                continue
            fi

            # أي خطأ آخر
            printf "   👤 User %-3s ❌ Failed\n" "$user"
            echo "$output"

        done

        echo "━━━━━━━━━━━━━━━━━━━━━━"

    done

    if [[ $found_any -eq 0 ]]; then
        echo "⚠️ No subfolders found in $base_dir"
    fi
}

# === Reusable Permissions Function (Full Feedback) ===
set_permissions() {
    echo "🔧 Setting permissions for User(s)..."

    local installer_pkgs=(
        com.esaba.downloader
        com.apkpure.aegon
        com.revanced.net.revancedmanager
        cm.aptoide.pt
        qa.essa.elauncher
    )

    local nav_pkgs=(
        app.revanced.android.apps.maps
        ru.yandex.yandexnavi
        com.waze
        com.huawei.maps.app
    )

    local runtime_perms=(
        android.permission.ACCESS_FINE_LOCATION
        android.permission.ACCESS_COARSE_LOCATION
        android.permission.ACCESS_BACKGROUND_LOCATION
        android.permission.POST_NOTIFICATIONS
    )

    local appops_perms=(
        ACCESS_FINE_LOCATION
        ACCESS_COARSE_LOCATION
        ACCESS_BACKGROUND_LOCATION
        RUN_IN_BACKGROUND
        RUN_ANY_IN_BACKGROUND
        WAKE_LOCK
    )

    for user in "${USERS[@]}"; do

        echo "   Processing User: $user"

        installed_pkgs="$(ADB_CMD shell pm list packages --user "$user" 2>/dev/null)"

        ############################################################
        # REQUEST_INSTALL_PACKAGES
        ############################################################
        for pkg in "${installer_pkgs[@]}"; do

            if echo "$installed_pkgs" | grep -q "^package:$pkg$"; then
                echo "     → $pkg (found)"
                ADB_CMD shell appops set --user "$user" "$pkg" REQUEST_INSTALL_PACKAGES allow >/dev/null 2>&1 || true
            else
                echo "     → $pkg (not installed, skipped)"
            fi

        done

        ############################################################
        # Google Keyboard + Accessibility
        ############################################################
        echo "     → Setting Google Keyboard"

        if echo "$installed_pkgs" | grep -q "^package:com.google.android.inputmethod.latin$"; then

            ADB_CMD shell ime enable --user "$user" \
                com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME \
                >/dev/null 2>&1 || true

            ADB_CMD shell ime set --user "$user" \
                com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME \
                >/dev/null 2>&1 || true

            ADB_CMD shell settings --user "$user" put secure accessibility_enabled 1 \
                >/dev/null 2>&1 || true

            ADB_CMD shell settings --user "$user" put secure enabled_accessibility_services \
                "nu.back.button/.service.BackButtonService:com.appspot.app58us.backkey/.BackkeyService" \
                >/dev/null 2>&1 || true

            echo "       ✓ Keyboard & Accessibility Ready"

        else
            echo "       → Gboard not installed"
        fi

        ############################################################
        # Navigation Apps
        ############################################################
        for pkg in "${nav_pkgs[@]}"; do

            if echo "$installed_pkgs" | grep -q "^package:$pkg$"; then

                echo "     → $pkg"

                # Runtime Permissions
                for perm in "${runtime_perms[@]}"; do
                    ADB_CMD shell pm grant --user "$user" "$pkg" "$perm" >/dev/null 2>&1 || true
                done

                # AppOps
                for op in "${appops_perms[@]}"; do
                    ADB_CMD shell cmd appops set --user "$user" "$pkg" "$op" allow >/dev/null 2>&1 || true
                done

                # Battery Optimization
                ADB_CMD shell dumpsys deviceidle whitelist +"$pkg" >/dev/null 2>&1 || true
                ADB_CMD shell cmd deviceidle whitelist +"$pkg" >/dev/null 2>&1 || true

                echo "       ✓ Permissions Applied"

            else
                echo "     → $pkg (not installed)"
            fi

        done

        ############################################################
        # microG Permissions
        ############################################################
        if echo "$installed_pkgs" | grep -q "^package:app.revanced.android.gms$"; then

            pkg="app.revanced.android.gms"

            echo "     → $pkg"

            # Runtime Permissions
            for perm in \
                android.permission.ACCESS_FINE_LOCATION \
                android.permission.ACCESS_COARSE_LOCATION \
                android.permission.ACCESS_BACKGROUND_LOCATION \
                android.permission.READ_PHONE_STATE \
                android.permission.GET_ACCOUNTS \
                android.permission.READ_CONTACTS \
                android.permission.CAMERA \
                android.permission.BODY_SENSORS \
                android.permission.RECEIVE_SMS \
                android.permission.READ_EXTERNAL_STORAGE \
                android.permission.WRITE_EXTERNAL_STORAGE \
                android.permission.BLUETOOTH_CONNECT \
                android.permission.BLUETOOTH_SCAN \
                android.permission.BLUETOOTH_ADVERTISE \
                android.permission.POST_NOTIFICATIONS
            do
                ADB_CMD shell pm grant --user "$user" "$pkg" "$perm" >/dev/null 2>&1 || true
            done

            # AppOps
            for op in \
                ACCESS_FINE_LOCATION \
                ACCESS_COARSE_LOCATION \
                ACCESS_BACKGROUND_LOCATION \
                RUN_IN_BACKGROUND \
                RUN_ANY_IN_BACKGROUND \
                WAKE_LOCK \
                BLUETOOTH_CONNECT \
                POST_NOTIFICATION
            do
                ADB_CMD shell cmd appops set --user "$user" "$pkg" "$op" allow >/dev/null 2>&1 || true
            done

            # Disable Auto Revoke (if supported)
            ADB_CMD shell cmd appops set --user "$user" "$pkg" AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore >/dev/null 2>&1 || true
            ADB_CMD shell cmd appops set --user "$user" "$pkg" AUTO_REVOKE_MANAGED_BY_INSTALLER allow >/dev/null 2>&1 || true

            # Battery Optimization
            ADB_CMD shell dumpsys deviceidle whitelist +"$pkg" >/dev/null 2>&1 || true
            ADB_CMD shell cmd deviceidle whitelist +"$pkg" >/dev/null 2>&1 || true

            echo "       ✓ microG Permissions Applied"

        else
            echo "     → app.revanced.android.gms (not installed)"
        fi

    done
}

# =========================
# MAIN FUNCTIONS
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

  install_from_subfolders "$DESKTOP_APK/apk" "BYD"

  set_permissions

  ADB_CMD push "$DESKTOP_APK/apk/VIP.conf" /sdcard || true
  ADB_CMD shell am start -a android.intent.action.BYD_APPSTARTMANAGEMENT 2>/dev/null || echo "   (BYD Intent skipped - normal)"

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
  sleep 2
  ADB_CMD shell pm enable com.byd.autovoice || true
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

  install_from_subfolders "$DESKTOP_APK/Rox" "ROX"

  for user in "${USERS[@]}"; do
    ADB_CMD install -t -g --user "$user" "$DESKTOP_APK/rox/Launcher"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/Ayah"/*.apk || true
    ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/Downloader"/*.apk || true
  done

  for user in "${USERS[@]}"; do
    ADB_CMD shell am start --user "$user" -n com.roxmotor.nonpreinstallapp/com.roxmotor.nonpreinstallapp.MainActivity2 || true
  done

  set_permissions

  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

Rox-Unlock() {
    clear
    select_device || { echo "Returning to main menu..."; return; }
    wait_for_adb

    echo "======================================"
    echo "      ROX Screen Unlock Utility"
    echo "======================================"
    echo

    echo "[1/5] Current Lock Status:"
    ADB_CMD shell getprop vnrpst.engineermode.geofenceLock
    echo

    echo "[2/5] Clearing Geofence Lock..."
    ADB_CMD -d shell 'setprop vnrpst.engineermode.geofenceLock "{\"geofenceLock_state\":0,\"geofenceLock_time\":0}"'
    sleep 1

    echo "[3/5] Verifying Lock Status..."
    ADB_CMD shell getprop vnrpst.engineermode.geofenceLock
    echo

    echo "[4/5] Clearing SceneEditApp data for all users..."

    USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2))

    for user in "${USERS[@]}"; do
        echo "   → User $user"

        ADB_CMD -d shell pm clear --user 0 com.roxmotor.sceneeditapp
        ADB_CMD -d shell pm disable-user --user 0 com.roxmotor.sceneeditapp

        echo "      ✓ Done"
    done

    echo
    echo "[5/5] Rebooting device..."
    sleep 1
    ADB_CMD reboot

    wait_for_adb
 
    echo "[1/5] Current Lock Status:"
    ADB_CMD shell getprop vnrpst.engineermode.geofenceLock
    echo


    disconnect_if_wireless
}

zeekr() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Zeekr"

    USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"

  ADB_CMD root || true
  ADB_CMD shell su -c "pm disable com.ecarx.xsfinstallverifier" || true
  ADB_CMD shell su -c "settings put global package_verifier_enable 0" || true
  ADB_CMD shell su -c "settings put global verifier_verify_adb_installs 0" || true

  install_apks_in_folder "$DESKTOP_APK/Zeekr"
  ADB_CMD install -g "$DESKTOP_APK/Zeekr/simplecontrol.apk" || true

  ADB_CMD shell settings put global auto_time 1 || true
  ADB_CMD shell settings put global auto_time_zone 1 || true
  ADB_CMD shell settings put global time_zone Asia/Dubai || true
  ADB_CMD shell service call alarm 3 s16 "Asia/Dubai" || true

  set_permissions

  ADB_CMD shell appops set --user 0 ace.jun.simplecontrol BIND_ACCESSIBILITY_SERVICE allow || true
  ADB_CMD shell settings put secure enabled_accessibility_services ace.jun.simplecontrol/ace.jun.simplecontrol.service.AccService || true

  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

dashing() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing Apps on Dashing"

    USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"

  install_apks_in_folder "$DESKTOP_APK/Dashing"
  ADB_CMD shell am start -n com.appindustry.everywherelauncher/com.michaelflisar.everywherelauncher.ui.activitiesandfragments.MainActivity || true
  ADB_CMD install -g "$DESKTOP_APK/Dashing/simplecontrol.apk" || true

  set_permissions

  ADB_CMD shell appops set --user 0 ace.jun.simplecontrol BIND_ACCESSIBILITY_SERVICE allow || true
  ADB_CMD shell settings put secure enabled_accessibility_services ace.jun.simplecontrol/ace.jun.simplecontrol.service.AccService || true

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

  install_from_subfolders "$DESKTOP_APK/LiAuto" "LiAuto"

  set_permissions

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

  install_from_subfolders "$DESKTOP_APK/Haval" "Haval"

  set_permissions

  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

Jetour() {
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

  echo "📤 Preparing device..."
  ADB_CMD shell "rm -rf /data/local/tmp/Jetour && mkdir -p /data/local/tmp/Jetour"

  echo "📤 Pushing APKs..."
  ADB_CMD push "$DESKTOP_APK/Jetour/." /data/local/tmp/Jetour/ >/dev/null || {
    echo "❌ Failed to push APKs."
    return
  }

  echo "📦 Installing APKs..."

  ADB_CMD shell <<'EOF'
  for apk in /data/local/tmp/Jetour/*.apk; do
    [ -f "$apk" ] || continue

    echo "Installing: $(basename "$apk")"

    pm install -r -g "$apk"

    echo "-------------------------"
  done
EOF

  set_permissions

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

  install_from_subfolders "$DESKTOP_APK/G700" "G700"

  set_permissions

  ADB_CMD shell am start -n qa.essa.elauncher/.MainActivity

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

  install_from_subfolders "$DESKTOP_APK/LYNK" "LYNK"

  set_permissions

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

  install_from_subfolders "$DESKTOP_APK/9X" "Zeekr9X"

  set_permissions

  ADB_CMD shell ime enable --user 10 com.touchtype.swiftkez/com.touchtype.KeyboardService >/dev/null 2>&1 || true
  ADB_CMD shell ime set --user 10 com.touchtype.swiftkez/com.touchtype.KeyboardService >/dev/null 2>&1 || true

  ADB_CMD shell settings put global auto_time 1 || true
  ADB_CMD shell settings put global auto_time_zone 1 || true
  ADB_CMD shell settings put global time_zone Asia/Dubai || true
  ADB_CMD shell service call alarm 3 s16 "Asia/Dubai" || true

  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

Premissions() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🔧 Fixing Zeekr Permissions..."

  echo "Step 1: Setting system locale to English..."
  ADB_CMD shell settings put system system_locales en || true

  echo "Step 2: Removing installer verifier..."
  ADB_CMD shell pm uninstall --user 0 com.ecarx.xsfinstallverifier 2>/dev/null || true

  echo "Step 3: Clearing launcher cache..."
  ADB_CMD shell pm clear --user 0 com.zeekr.carlauncher3d 2>/dev/null || true

  echo "Step 4: Unlocking Sim-Card..."
  ADB_CMD shell pm disable-user --user 0 com.zeekr.housekeeper

  echo "Rebooting device to apply changes..."
  ADB_CMD reboot
  wait_for_adb
  sleep 15

  echo "Step 5: Post-reboot cleanup..."
  ADB_CMD shell pm clear ecarx.notificationcenterui 2>/dev/null || true
  ADB_CMD shell settings put system system_locales en 2>/dev/null || true
  ADB_CMD shell pm uninstall --user 0 com.ecarx.xsfinstallverifier 2>/dev/null || true
  ADB_CMD shell pm clear --user 0 com.zeekr.carlauncher3d 2>/dev/null || true

  echo "Step 6: Disabling unnecessary services..."
  ADB_CMD shell pm disable-user com.zeekr.fwk.common 2>/dev/null || true
  ADB_CMD shell pm disable-user --user 0 com.zeekr.fwk.common 2>/dev/null || true

  echo ""
  echo "🎉 Zeekr Permissions Fixed Successfully!"
  echo "Device is now optimized for Dubai/UAE usage."
  echo ""

  read -p "Press Enter to return to main menu..."
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

  # تثبيت الملفات الرئيسية
  for apk in "$DESKTOP_APK/Leep"/*.apk; do
    [[ -f "$apk" ]] || continue
    echo "📦 Installing: $(basename "$apk")"
    for user in "${USERS[@]}"; do
      ADB_CMD install -g -r -t -d --install-reason 64 --user "$user" "$apk" || true
    done
  done

  install_from_subfolders "$DESKTOP_APK/Leep" "Leapmotor"

  set_permissions

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

  ADB_CMD push "$DESKTOP_APK/apk/VIP.conf" /sdcard || true

  set_permissions

  echo "✅ Installed Successfully"
  disconnect_if_wireless
}

AVATR() {
  clear
  select_device
  wait_for_adb

  echo "🚀 Installing Apps on AVATR 11 (Fixed Method)"

  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))

  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi

  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi

  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=(0)
    echo "⚠️ Could not detect users, using User 0."
  fi

  echo "👥 Found Users: ${USERS[*]}"

  for user in "${USERS[@]}"; do
    ADB_CMD shell pm disable-user --user "$user" com.android.packageinstaller 2>/dev/null || true
  done

  sleep 2

  setopt nullglob

  for apk in AVATR/*.apk; do
    [[ -e "$apk" ]] || continue

    echo "   → $(basename "$apk")"

    for user in "${USERS[@]}"; do
      ADB_CMD install -r -d -g --user "$user" -i com.huawei.appmarket.vehicle "$apk" || \
      ADB_CMD install -r -d -g --user "$user" -i com.huawei.appinstaller.car "$apk" || true
    done
  done

  unsetopt nullglob

  for user in "${USERS[@]}"; do
    ADB_CMD install-multiple -r -d -g --user "$user" -i com.huawei.appmarket.vehicle "$DESKTOP_APK/AVATR/Ayah"/*.apk || true
    ADB_CMD install-multiple -r -d -g --user "$user" -i com.huawei.appinstaller.car "$DESKTOP_APK/AVATR/Downloader"/*.apk || true
  done

  set_permissions

  for user in "${USERS[@]}"; do
    ADB_CMD shell pm enable --user "$user" com.android.packageinstaller 2>/dev/null || true
  done

  echo "🎉 AVATR Installation Completed!"

  disconnect_if_wireless
}

VOYAH() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Installing VoyahTweaks"

  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
  echo "👥 Users: ${USERS[*]}"

  VOYAH_DIR="$DESKTOP_APK/Voyah"

  if [[ ! -d "$VOYAH_DIR" ]]; then
    echo "❌ Voyah folder not found: $VOYAH_DIR"
    echo "   Please place all Voyah files inside Desktop/apk/Voyah/"
    read -p "Press Enter to return to menu..."
    disconnect_if_wireless
    return
  fi

  echo "📤 Preparing adb for VoyahTweaks..."

  # Step 1: Prepare adb
  ADB_CMD wait-for-device
  ADB_CMD root
  ADB_CMD wait-for-device
  ADB_CMD disable-verity

  echo "The car will now reboot..."
  ADB_CMD reboot
  wait_for_adb
  ADB_CMD root
  ADB_CMD wait-for-device
  ADB_CMD remount

  echo "The car will now reboot again..."
  ADB_CMD reboot
  wait_for_adb
  ADB_CMD root
  ADB_CMD wait-for-device

  echo "✅ adb is ready"

  # Enable app resizing
  echo "Enabling app resizing support..."
  ADB_CMD shell settings put global enable_freeform_support 1
  ADB_CMD shell settings put global force_resizable_activities 1
  ADB_CMD shell settings put global hidden_api_policy_pre_p_apps 1
  ADB_CMD shell settings put global hidden_api_policy_p_apps 1
  ADB_CMD shell settings put global hidden_api_policy 1

  # Install VoyahTweaks
  echo "Installing VoyahTweaks APK..."
  if [[ -f "$VOYAH_DIR/VoyahTweaks.apk" ]]; then
    ADB_CMD install -r "$VOYAH_DIR/VoyahTweaks.apk" || true
  else
    echo "   ⚠️ VoyahTweaks.apk not found"
  fi

  # Remove old launcher
  echo "Removing old launcher..."
  ADB_CMD shell pm uninstall com.simplemobiletools.applauncher 2>/dev/null || true

  # Grant permissions
  echo "Granting permissions to VoyahTweaks..."
  ADB_CMD shell pm grant ru.kachalin.voyahtweaks android.permission.SYSTEM_ALERT_WINDOW 2>/dev/null || true
  ADB_CMD shell pm grant ru.kachalin.voyahtweaks android.permission.READ_LOGS 2>/dev/null || true
  ADB_CMD shell pm grant ru.kachalin.voyahtweaks android.permission.RECORD_AUDIO 2>/dev/null || true
  ADB_CMD shell pm grant ru.kachalin.voyahtweaks android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null || true
  ADB_CMD shell pm grant ru.kachalin.voyahtweaks android.permission.WRITE_SECURE_SETTINGS 2>/dev/null || true
  ADB_CMD shell appops set ru.kachalin.voyahtweaks REQUEST_INSTALL_PACKAGES allow 2>/dev/null || true

  # Launch
  echo "Launching VoyahTweaks..."
  ADB_CMD shell am start ru.kachalin.voyahtweaks/.android.activity.main.MainActivity

  read -p "Wait for VoyahTweaks to launch on screen and press any key..." -n1 -s

  echo "Rebooting the car..."
  ADB_CMD reboot
  wait_for_adb
  ADB_CMD root
  ADB_CMD wait-for-device
  ADB_CMD shell am start ru.kachalin.voyahtweaks/.android.activity.main.MainActivity

  echo "🎉 VoyahTweaks Installation Completed Successfully"
  disconnect_if_wireless
}

Dump_Apps() {
  clear
  select_device || { echo "Returning to main menu..."; return; }
  wait_for_adb
  echo "🚀 Dumping All Latest User Apps..."

  # إعداد المجلدات
  DESKTOP_DIR="$HOME/Desktop"
  DUMPED_DIR="$DESKTOP_DIR/Dumped_Apps"
  LATEST_DIR="$DUMPED_DIR/Latest"
  mkdir -p "$LATEST_DIR"

  echo "📁 الملفات هتتحفظ في: $LATEST_DIR"
  echo "=========================================="

  for pkg in $(ADB_CMD shell pm list packages -3 | sed 's/package://' 2>/dev/null); do
    path_output=$(ADB_CMD shell pm path "$pkg" 2>/dev/null)
    if [ -z "$path_output" ]; then
      echo "تخطي: $pkg"
      continue
    fi

    # جلب اسم التطبيق (للـ Split فقط)
    label=$(ADB_CMD shell dumpsys package "$pkg" 2>/dev/null | grep -m 1 "Application Label" | sed 's/.*Application Label: //')
    [ -z "$label" ] && label=$(echo "$pkg" | awk -F. '{print $NF}')
    safe_label=$(echo "$label" | tr -cd '[:alnum:]_ -' | tr ' ' '_' | tr -s '_')

    echo "سحب: $pkg"

    # تحويل المسارات
    apk_paths=()
    while IFS= read -r line; do
      cleaned=$(echo "$line" | sed 's/package://' | xargs)
      [ -n "$cleaned" ] && apk_paths+=("$cleaned")
    done <<< "$path_output"
    
    if [ ${#apk_paths[@]} -gt 1 ]; then
      # === Split APK → فولدر باسم التطبيق ===
      APP_FOLDER="$LATEST_DIR/$safe_label"
      mkdir -p "$APP_FOLDER"
      
      for apk_path in "${apk_paths[@]}"; do
        original_name=$(basename "$apk_path")
        target="$APP_FOLDER/$original_name"
        
        if ADB_CMD pull "$apk_path" "$target" 2>/dev/null; then
          echo "   ✓ $original_name"
        else
          echo "   ⚠️ فشل $original_name"
        fi
      done
      echo "   → فولدر: $safe_label/"
      
    else
      # === Normal APK → ملف باسم الـ Package ===
      apk_path="${apk_paths[0]}"
      target="$LATEST_DIR/${pkg}.apk"
      
      if ADB_CMD pull "$apk_path" "$target" 2>/dev/null; then
        echo "   ✓ ${pkg}.apk"
      else
        echo "   ⚠️ فشل ${pkg}.apk"
      fi
    fi
  done

  echo -e "\n✅ تم السحب بنجاح!"
  echo "كل التطبيقات في: $LATEST_DIR"
  ls -1 "$LATEST_DIR" | head -n 25
  echo ""
  disconnect_if_wireless
}

# =========================
# MENU
# =========================

menu() {
  while true; do
   clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║       💻 BEST STORE AIO Sript (BY: Hassan Gawish) 💻         ║"
    echo "║     Advanced ADB Installer for Chinese Car Head Units        ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  1. 📱 Install Apps (BYD)                                    ║"
    echo "║  2. 🔇 Disable Chinese (BYD)                                 ║"
    echo "║  3. 📶 Activate Sim-Card (BYD)                               ║"
    echo "║  4. 📱 Install Apps (rox)                                    ║"
    echo "║  5. 📱 Install Apps (Zeekr)                                  ║"
    echo "║  6. 📱 Install Apps (Dashing)                                ║"
    echo "║  7. 📱 Install Apps (LiAuto)                                 ║"
    echo "║  8. 📱 Install Apps (Haval)                                  ║"
    echo "║  9. 🔓 Unlock Screen (rox)                                   ║"
    echo "║ 10. 📱 Install Apps (Jetour)                                 ║"
    echo "║ 11. 📱 Install Apps (G700)                                   ║"
    echo "║ 12. 📱 Install Apps (LYNK&CO)                                ║"
    echo "║ 13. 📱 Install Apps (Zeeker9X)                               ║"
    echo "║ 14. 🔓 Unlock States (Zeeker9X)                              ║"
    echo "║ 15. 📱 Install Apps (Leepmotor)                              ║"
    echo "║ 16. 📱 Install Apps (BYD_OLD)                                ║"
    echo "║ 17. 📱 Install Apps (AVATR)                                  ║"
    echo "║ 18. 📱 Install Apps (VOYAH)                                  ║"
    echo "║ 99. 📦 Dump All Apps (Latest)                                ║"
    echo "║  0. 🚪 Exit & Close Terminal                                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
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
      10) Jetour ;;
      11) G700 ;;
      12) LYNK ;;
      13) Zeekr9x ;;
      14) Premissions ;;
      15) Leapmotor ;;
      16) BYD_OLD ;;
      17) AVATR ;;
      18) VOYAH ;;
      99) Dump_Apps ;;
      0)
        echo "👋 Closing Terminal..."
        sleep 0.6
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
