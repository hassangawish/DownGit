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
    local pkg=""

    # ============================================================
    # 1. apkanalyzer
    # ============================================================

    if command -v apkanalyzer >/dev/null 2>&1; then
        pkg=$(apkanalyzer manifest application-id "$apk" 2>/dev/null | tr -d '\r\n')

        if [[ "$pkg" =~ ^[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)+$ ]]; then
            echo "$pkg"
            return 0
        fi
    fi

    # ============================================================
    # 2. aapt
    # ============================================================

    if command -v aapt >/dev/null 2>&1; then
        pkg=$(aapt dump badging "$apk" 2>/dev/null |
              awk -F"'" '/package: name=/{print $2; exit}')

        if [[ "$pkg" =~ ^[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)+$ ]]; then
            echo "$pkg"
            return 0
        fi
    fi

    # ============================================================
    # 3. aapt2
    # ============================================================

    if command -v aapt2 >/dev/null 2>&1; then
        pkg=$(aapt2 dump packagename "$apk" 2>/dev/null |
              tr -d '\r\n')

        if [[ "$pkg" =~ ^[a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)+$ ]]; then
            echo "$pkg"
            return 0
        fi
    fi

    echo ""
    return 1
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

# install_apk_safe() {

#     local apk="$1"
#     local pkg=""
#     local output=""
#     local link_output=""

#     echo "📦 Installing: $(basename "$apk")"

#     # ============================================================
#     # GET PACKAGE NAME
#     # ============================================================

#     pkg=$(get_package_name "$apk")

#     # ============================================================
#     # ALL USERS MODE
#     # ============================================================

#     if [[ "$USE_ALL_USERS" == true ]]; then

#         # --------------------------------------------------------
#         # First install normally on the primary user.
#         # This makes sure the package exists on the device.
#         # --------------------------------------------------------

#         output=$(ADB_CMD install -r -d -g --user 0 "$apk" 2>&1)

#         if echo "$output" | grep -q "Success"; then
#             printf "   👤 User %-3s ✅ Installed\n" "0"
#         else
#             printf "   👤 User %-3s ⚠️ Install returned error\n" "0"
#         fi

#         # --------------------------------------------------------
#         # If package name wasn't detected from PC tools,
#         # try to detect it from installed packages.
#         # --------------------------------------------------------

#         if [[ -z "$pkg" ]]; then

#             if [[ -n "$apk" ]]; then

#                 # Try package name again after installation
#                 pkg=$(get_package_name "$apk")

#             fi
#         fi

#         # --------------------------------------------------------
#         # Show package
#         # --------------------------------------------------------

#         if [[ -n "$pkg" ]]; then
#             echo "   📦 Package: $pkg"
#         else
#             echo "   ⚠️ Could not determine package name."
#         fi

#         # --------------------------------------------------------
#         # Install / link for remaining users
#         # --------------------------------------------------------

#         for user in $(get_all_users); do

#             # Skip primary user because we already installed it
#             if [[ "$user" == "0" ]]; then
#                 continue
#             fi

#             # ====================================================
#             # Detect Clone User
#             # ====================================================

#             USER_INFO=$(
#                 ADB_CMD shell pm list users 2>/dev/null |
#                 grep "UserInfo{$user:"
#             )

#             IS_CLONE=false

#             if echo "$USER_INFO" | grep -qiE "clone|_clone"; then
#                 IS_CLONE=true
#             fi

#             # ====================================================
#             # Normal User
#             # ====================================================

#             if [[ "$IS_CLONE" == false ]]; then

#                 output=$(
#                     ADB_CMD install \
#                         -r \
#                         -d \
#                         -g \
#                         --user "$user" \
#                         "$apk" 2>&1
#                 )

#                 if echo "$output" | grep -q "Success"; then

#                     printf "   👤 User %-3s ✅ Installed\n" "$user"

#                 elif echo "$output" | grep -q "INSTALL_FAILED_UPDATE_INCOMPATIBLE"; then

#                     printf "   👤 User %-3s ⚠️ Signature Mismatch\n" "$user"

#                 elif echo "$output" | grep -q "INSTALL_FAILED_VERSION_DOWNGRADE"; then

#                     printf "   👤 User %-3s ⚠️ Version Downgrade\n" "$user"

#                 else

#                     printf "   👤 User %-3s ❌ Failed\n" "$user"

#                 fi

#                 continue
#             fi

#             # ====================================================
#             # CLONE USER
#             # ====================================================

#             echo "   👤 User $user 🔄 Clone detected"

#             if [[ -z "$pkg" ]]; then

#                 printf "   👤 User %-3s ❌ Package Unknown\n" "$user"
#                 continue

#             fi

#             # ----------------------------------------------------
#             # Check whether package already exists on device
#             # ----------------------------------------------------

#             PACKAGE_EXISTS=$(
#                 ADB_CMD shell pm list packages 2>/dev/null |
#                 grep -Fx "package:$pkg"
#             )

#             if [[ -z "$PACKAGE_EXISTS" ]]; then

#                 printf "   👤 User %-3s ❌ Package not available\n" "$user"
#                 continue

#             fi

#             # ----------------------------------------------------
#             # Link existing package to clone user
#             # ----------------------------------------------------

#             link_output=$(
#                 ADB_CMD shell cmd package install-existing \
#                     --user "$user" \
#                     "$pkg" 2>&1
#             )

#             if echo "$link_output" | grep -qiE \
#                 "installed for user|already installed"; then

#                 printf "   👤 User %-3s ✅ Clone Linked\n" "$user"

#             else

#                 # ------------------------------------------------
#                 # Second method: pm install-existing
#                 # ------------------------------------------------

#                 link_output=$(
#                     ADB_CMD shell pm install-existing \
#                         --user "$user" \
#                         "$pkg" 2>&1
#                 )

#                 if echo "$link_output" | grep -qiE \
#                     "installed for user|already installed"; then

#                     printf "   👤 User %-3s ✅ Clone Linked\n" "$user"

#                 else

#                     printf "   👤 User %-3s ❌ Clone Failed\n" "$user"

#                     echo "      Package: $pkg"
#                     echo "      Error: $link_output"

#                 fi

#             fi

#         done

#         return
#     fi

#     # ============================================================
#     # NORMAL INSTALL MODE
#     # ============================================================

#     output=$(ADB_CMD install -r -d -g "$apk" 2>&1)

#     if echo "$output" | grep -q "Success"; then

#         echo "   ✅ Installed"
#         return

#     fi

#     # ============================================================
#     # Existing Version / Signature / Downgrade
#     # ============================================================

#     if echo "$output" | grep -qE \
#         "INSTALL_FAILED_UPDATE_INCOMPATIBLE|INSTALL_FAILED_VERSION_DOWNGRADE|INSTALL_FAILED_SIGNATURE_MISMATCH"; then

#         echo "🔄 Existing version detected..."

#         if [[ -n "$pkg" ]]; then

#             for user in $(get_all_users); do

#                 ADB_CMD shell pm uninstall \
#                     --user "$user" \
#                     "$pkg" >/dev/null 2>&1 || true

#             done

#             output=$(ADB_CMD install -r -d -g "$apk" 2>&1)

#             if echo "$output" | grep -q "Success"; then
#                 echo "   ✅ Reinstalled"
#             else
#                 echo "   ❌ Failed"
#                 echo "$output"
#             fi

#         else

#             echo "❌ Couldn't detect package name."

#         fi

#     else

#         echo "$output"

#     fi
# }

install_apk_safe() {

    local apk="$1"
    local pkg=""
    local output=""
    local link_output=""
    local user_info=""
    local is_clone=false

    echo "📦 Installing: $(basename "$apk")"

    # ============================================================
    # GET PACKAGE NAME
    # ============================================================

    pkg=$(get_package_name "$apk")

    # ============================================================
    # ALL USERS MODE
    # ============================================================

    if [[ "$USE_ALL_USERS" == true ]]; then

        # --------------------------------------------------------
        # Process every Android user
        # --------------------------------------------------------

        for user in $(get_all_users); do

            # ====================================================
            # USER 0 / NORMAL USERS / CLONE DETECTION
            # ====================================================

            user_info=$(
                ADB_CMD shell pm list users 2>/dev/null |
                tr -d '\r' |
                grep "UserInfo{$user:" |
                head -n 1
            )

            is_clone=false

            if echo "$user_info" | grep -qiE "clone|_clone"; then
                is_clone=true
            fi

            # ====================================================
            # CLONE USER
            # ====================================================

            if [[ "$is_clone" == true ]]; then

                printf "   👤 User %-3s 🔄 Clone detected\n" "$user"

                # ------------------------------------------------
                # Package name is required
                # ------------------------------------------------

                if [[ -z "$pkg" ]]; then

                    printf "   👤 User %-3s ❌ Package Unknown\n" "$user"

                    continue
                fi

                # ------------------------------------------------
                # IMPORTANT:
                # Do NOT check "pm list packages" first.
                #
                # Some Clone implementations do not expose the
                # package through the normal package list even
                # though install-existing can still link it.
                # ------------------------------------------------

                # =================================================
                # METHOD 1
                # cmd package install-existing
                # =================================================

                link_output=$(
                    ADB_CMD shell cmd package install-existing \
                        --user "$user" \
                        "$pkg" 2>&1
                )

                if echo "$link_output" | grep -qiE \
                    "installed for user|already installed|success"; then

                    printf "   👤 User %-3s ✅ Clone Linked\n" "$user"

                    continue
                fi

                # =================================================
                # METHOD 2
                # pm install-existing
                # =================================================

                link_output=$(
                    ADB_CMD shell pm install-existing \
                        --user "$user" \
                        "$pkg" 2>&1
                )

                if echo "$link_output" | grep -qiE \
                    "installed for user|already installed|success"; then

                    printf "   👤 User %-3s ✅ Clone Linked\n" "$user"

                    continue
                fi

                # =================================================
                # CLONE FAILED
                # =================================================

                printf "   👤 User %-3s ❌ Clone Link Failed\n" "$user"

                if [[ -n "$link_output" ]]; then
                    echo "      $link_output"
                fi

                continue
            fi

            # ====================================================
            # NORMAL USER
            # ====================================================

            output=$(
                ADB_CMD install \
                    -r \
                    -d \
                    -g \
                    --user "$user" \
                    "$apk" 2>&1
            )

            # ====================================================
            # NORMAL INSTALL SUCCESS
            # ====================================================

            if echo "$output" | grep -q "Success"; then

                printf "   👤 User %-3s ✅ Installed\n" "$user"

                # Show package only once for primary user
                if [[ "$user" == "0" && -n "$pkg" ]]; then
                    echo "   📦 Package: $pkg"
                fi

                continue
            fi

            # ====================================================
            # GEELY CLONE FALLBACK
            #
            # Some devices may not expose "_clone" correctly in
            # UserInfo, but the package manager tells us that the
            # APK can only be installed on a Clone user.
            # ====================================================

            if echo "$output" |
                grep -qi "geely can't only install on clone user"; then

                printf "   👤 User %-3s 🔄 Clone restriction detected\n" "$user"

                if [[ -z "$pkg" ]]; then

                    printf "   👤 User %-3s ❌ Package Unknown\n" "$user"

                    continue
                fi

                # ------------------------------------------------
                # Try cmd package install-existing
                # ------------------------------------------------

                link_output=$(
                    ADB_CMD shell cmd package install-existing \
                        --user "$user" \
                        "$pkg" 2>&1
                )

                if echo "$link_output" | grep -qiE \
                    "installed for user|already installed|success"; then

                    printf "   👤 User %-3s ✅ Clone Linked\n" "$user"

                    continue
                fi

                # ------------------------------------------------
                # Try pm install-existing
                # ------------------------------------------------

                link_output=$(
                    ADB_CMD shell pm install-existing \
                        --user "$user" \
                        "$pkg" 2>&1
                )

                if echo "$link_output" | grep -qiE \
                    "installed for user|already installed|success"; then

                    printf "   👤 User %-3s ✅ Clone Linked\n" "$user"

                    continue
                fi

                # ------------------------------------------------
                # Clone fallback failed
                # ------------------------------------------------

                printf "   👤 User %-3s ❌ Clone Link Failed\n" "$user"

                if [[ -n "$link_output" ]]; then
                    echo "      $link_output"
                fi

                continue
            fi

            # ====================================================
            # NORMAL INSTALL FAILED
            # ====================================================

            printf "   👤 User %-3s ❌ Install Failed\n" "$user"

            if [[ -n "$output" ]]; then
                echo "      $output"
            fi

        done

        return
    fi

    # ============================================================
    # SINGLE USER / NORMAL INSTALL MODE
    # ============================================================

    output=$(
        ADB_CMD install \
            -r \
            -d \
            -g \
            "$apk" 2>&1
    )

    # ============================================================
    # SUCCESS
    # ============================================================

    if echo "$output" | grep -q "Success"; then

        echo "   ✅ Installed"

        return
    fi

    # ============================================================
    # SIGNATURE / VERSION CONFLICT
    # ============================================================

    if echo "$output" |
        grep -qE \
        "INSTALL_FAILED_UPDATE_INCOMPATIBLE|INSTALL_FAILED_VERSION_DOWNGRADE|INSTALL_FAILED_SIGNATURE_MISMATCH"; then

        echo "🔄 Existing version detected..."

        if [[ -n "$pkg" ]]; then

            # ----------------------------------------------------
            # Uninstall package for all users
            # ----------------------------------------------------

            for user in $(get_all_users); do

                ADB_CMD shell pm uninstall \
                    --user "$user" \
                    "$pkg" >/dev/null 2>&1 || true

            done

            # ----------------------------------------------------
            # Reinstall
            # ----------------------------------------------------

            output=$(
                ADB_CMD install \
                    -r \
                    -d \
                    -g \
                    "$apk" 2>&1
            )

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
                android.permission.POST_NOTIFICATIONS \
                android.permission.SYSTEM_ALERT_WINDOW
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
                POST_NOTIFICATION \
                SYSTEM_ALERT_WINDOW
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

  while true; do
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                         🚙 ROX TOOLS                         ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  1. 📱 Install Apps                                          ║"
    echo "║  2. 📥 Download & Install Display Mirror                     ║"
    echo "║  0. ↩️  Back                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    read -r -p "CHOOSE: " ROX_OPTION

    case "$ROX_OPTION" in

      1)
        clear
        select_device || { echo "Returning to ROX menu..."; continue; }
        wait_for_adb

        echo "🚀 Installing Apps on ROX"

        USERS=($(ADB_CMD shell pm list users 2>/dev/null | \
          grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))

        if [[ ${#USERS[@]} -eq 0 ]]; then
          USERS=($(ADB_CMD shell cmd user list 2>/dev/null | \
            grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
        fi

        if [[ ${#USERS[@]} -eq 0 ]]; then
          USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | \
            grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
        fi

        [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)
        echo "👥 Users: ${USERS[*]}"

        USE_ALL_USERS=true
        install_apks_in_folder "$DESKTOP_APK/Rox"
        install_apks_in_folder "$DESKTOP_APK/Rox/Mirror"
        USE_ALL_USERS=false

        install_from_subfolders "$DESKTOP_APK/Rox" "ROX"

        for user in "${USERS[@]}"; do
          ADB_CMD install -t -g --user "$user" "$DESKTOP_APK/rox/Launcher"/*.apk || true
          ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/Ayah"/*.apk || true
          ADB_CMD install-multiple -r --user "$user" "$DESKTOP_APK/rox/Downloader"/*.apk || true
        done

        ADB_CMD shell am start -n com.example.displaymirror/.MainActivity

        set_permissions

        echo "✅ Installed Successfully"
        disconnect_if_wireless
        read -r -p "Press ENTER to continue..."
        ;;

      2)
        clear

        MIRROR_DIR="$DESKTOP_APK/Rox/Mirror"
        MIRROR_APK="$MIRROR_DIR/Display_Mirror.apk"
        MIRROR_URL="https://github.com/hassangawish/DownGit/raw/refs/heads/master/Display_Mirror.apk"

        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║              📥 DISPLAY MIRROR DOWNLOADER                    ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo

        echo "📁 Target folder:"
        echo "   $MIRROR_DIR"
        echo

        # ============================================================
        # CHECK / CREATE ROX/Mirror FOLDER
        # ============================================================

        if [[ ! -d "$MIRROR_DIR" ]]; then
          echo "📁 Mirror folder not found."
          echo "📂 Creating:"
          echo "   $MIRROR_DIR"
          mkdir -p "$MIRROR_DIR" || {
            echo "❌ Failed to create Mirror folder."
            read -r -p "Press ENTER to continue..."
            continue
          }
        else
          echo "📁 Mirror folder already exists."
        fi

        # ============================================================
        # CHECK WHETHER Display_Mirror.apk ALREADY EXISTS
        # ============================================================

        if [[ -f "$MIRROR_APK" && -s "$MIRROR_APK" ]]; then
          echo
          echo "✅ Display_Mirror.apk already exists."
          echo "   Skipping download."
          echo "📄 Using:"
          echo "   $MIRROR_APK"
        else
          echo
          echo "📥 Display_Mirror.apk not found."
          echo "⬇️  Downloading..."

          if command -v curl >/dev/null 2>&1; then
            curl -L --fail --progress-bar \
              "$MIRROR_URL" \
              -o "$MIRROR_APK"
            DOWNLOAD_STATUS=$?
          elif command -v wget >/dev/null 2>&1; then
            wget -O "$MIRROR_APK" "$MIRROR_URL"
            DOWNLOAD_STATUS=$?
          else
            echo "❌ Neither curl nor wget is installed."
            read -r -p "Press ENTER to continue..."
            continue
          fi

          if [[ $DOWNLOAD_STATUS -ne 0 || ! -s "$MIRROR_APK" ]]; then
            echo
            echo "❌ Download failed."
            rm -f "$MIRROR_APK"
            read -r -p "Press ENTER to continue..."
            continue
          fi

          echo
          echo "✅ Download completed."
          echo "📄 Saved to:"
          echo "   $MIRROR_APK"
        fi

        echo

        echo "🔍 Checking connected device..."
        select_device || {
          echo "❌ No device selected. File was downloaded successfully."
          read -r -p "Press ENTER to continue..."
          continue
        }

        wait_for_adb

        echo "📦 Installing Display Mirror..."
        echo

        # Requested installation method: adb -d install -g
        if $ADB -d install -g "$MIRROR_APK"; then
          echo
          echo "✅ Display Mirror installed successfully."
        else
          echo
          echo "❌ Display Mirror installation failed."
          echo "📄 APK: $MIRROR_APK"
        fi

        echo
        disconnect_if_wireless
        read -r -p "Press ENTER to continue..."
        ;;

      0)
        return
        ;;

      *)
        echo
        echo "✗ Invalid option."
        sleep 1
        ;;

    esac
  done
}

Rox-Unlock() {
    clear
    select_device || { echo "Returning to main menu..."; return; }
    wait_for_adb

    echo "======================================"
    echo "      ROX Screen Unlock Utility"
    echo "======================================"
    echo

    echo "[1/6] Current Lock Status:"
    ADB_CMD shell getprop vnrpst.engineermode.geofenceLock
    echo

    echo "[2/6] Clearing Geofence Lock..."
    ADB_CMD shell 'setprop vnrpst.engineermode.geofenceLock "{\"geofenceLock_state\":0,\"geofenceLock_time\":0}"'
    sleep 1

    echo "[3/6] Verifying Lock Status..."
    ADB_CMD shell getprop vnrpst.engineermode.geofenceLock
    echo

    echo "[4/6] Clearing SceneEditApp data for all users..."

    USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2))

    for user in "${USERS[@]}"; do
        echo "   → User $user"

        ADB_CMD shell pm clear --user "$user" com.roxmotor.sceneeditapp >/dev/null 2>&1 || true
        ADB_CMD shell pm disable-user --user "$user" com.roxmotor.sceneeditapp >/dev/null 2>&1 || true

        echo "      ✓ Done"
    done

    echo
    echo "[5/6] Getting Disabled Packages..."
    ADB_CMD shell pm list packages -d
    echo

    echo "[6/6] Rebooting device..."
    sleep 1
    ADB_CMD reboot

    wait_for_adb

    echo
    echo "======================================"
    echo "      Current Lock Status"
    echo "======================================"

    STATUS=$(ADB_CMD shell getprop vnrpst.engineermode.geofenceLock | tr -d '\r')
    echo "$STATUS"
    echo
    if echo "$STATUS" | grep -q '"geofenceLock_state":0' && \
       echo "$STATUS" | grep -q '"geofenceLock_time":0'; then
        echo "======================================"
        echo "✓ Success"
        echo "======================================"
    else
        echo "======================================"
        echo "✗ Failed, Please Retry"
        echo "======================================"
    fi
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

# ============================================================
# G700 ONLINE CODE GENERATOR
# ============================================================

G700_GENERATE_CODE() {

    clear

    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                🔐 G700 CODE GENERATOR                        ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║              Powered by BEST-STORE algorithm                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # ============================================================
    # REGIONS
    # ============================================================

    echo "Select Region:"
    echo
    echo "  1. 🇦🇪 UAE"
    echo "  2. 🇸🇦 Saudi Arabia"
    echo "  3. 🇴🇲 Oman"
    echo "  4. 🇶🇦 Qatar"
    echo "  5. 🇰🇼 Kuwait"
    echo "  6. 🇧🇭 Bahrain"
    echo "  7. 🇪🇬 Egypt"
    echo "  0. ↩️  Back"
    echo

    read -r -p "Select region [0-7]: " G700_REGION

    case "$G700_REGION" in

        1)
            G700_REGION_NAME="UAE"
            G700_TZ="Asia/Dubai"
            ;;

        2)
            G700_REGION_NAME="Saudi Arabia"
            G700_TZ="Asia/Riyadh"
            ;;

        3)
            G700_REGION_NAME="Oman"
            G700_TZ="Asia/Muscat"
            ;;

        4)
            G700_REGION_NAME="Qatar"
            G700_TZ="Asia/Qatar"
            ;;

        5)
            G700_REGION_NAME="Kuwait"
            G700_TZ="Asia/Kuwait"
            ;;

        6)
            G700_REGION_NAME="Bahrain"
            G700_TZ="Asia/Bahrain"
            ;;

        7)
            G700_REGION_NAME="Egypt"
            G700_TZ="Africa/Cairo"
            ;;

        0)
            return
            ;;

        *)
            echo
            echo "✗ Invalid region."
            sleep 2
            return
            ;;

    esac

    # ============================================================
    # SOFTWARE VERSION
    # ============================================================

    clear

    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                🔐 G700 CODE GENERATOR                        ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║ Region: %-50s   ║\n" "$G700_REGION_NAME"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    echo "Software Version:"
    echo
    echo "  1. 3.30 - 3.35"
    echo "  2. 3.36+"
    echo "  0. Back"
    echo

    read -r -p "Select version [0-2]: " G700_VERSION

    case "$G700_VERSION" in

        1)
            G700_SEED="20250530"
            G700_VERSION_NAME="3.30 - 3.35"
            G700_DYNAMIC="false"
            G700_DIAL="*#20240730#*"
            ;;

        2)
            G700_SEED="20251030"
            G700_VERSION_NAME="3.36+"
            G700_DYNAMIC="true"
            ;;

        0)
            return
            ;;

        *)
            echo
            echo "✗ Invalid version."
            sleep 2
            return
            ;;

    esac

    # ============================================================
    # GET CURRENT TIME FOR SELECTED REGION
    # ============================================================

    G700_DATE="$(
        TZ="$G700_TZ" date '+%Y-%m-%d'
    )"

    G700_HOUR="$(
        TZ="$G700_TZ" date '+%H'
    )"

    G700_MINUTE="$(
        TZ="$G700_TZ" date '+%M'
    )"

    G700_SECOND="$(
        TZ="$G700_TZ" date '+%S'
    )"

    # Remove leading zero
    G700_HOUR=$((10#$G700_HOUR))

    G700_MONTH="$(
        TZ="$G700_TZ" date '+%m'
    )"

    G700_DAY="$(
        TZ="$G700_TZ" date '+%d'
    )"

    G700_MONTH=$((10#$G700_MONTH))
    G700_DAY=$((10#$G700_DAY))

    # ============================================================
    # CALCULATE CODE
    #
    # Unlokit:
    #
    # data = MM * 10000 + DD * 100 + HOUR
    # r    = SEED * data - HOUR
    # code = ((r % 1000000) + 1000000) % 1000000
    # ============================================================

    G700_DATA=$(
        printf '%d' \
        $((G700_MONTH * 10000 + G700_DAY * 100 + G700_HOUR))
    )

    G700_RESULT=$(
        python3 - "$G700_SEED" "$G700_DATA" "$G700_HOUR" <<'PY'
import sys

seed = int(sys.argv[1])
data = int(sys.argv[2])
hour = int(sys.argv[3])

mod = 1000000

result = seed * data - hour
result = ((result % mod) + mod) % mod

print(f"{result:06d}")
PY
    )

    # ============================================================
    # VALIDATE
    # ============================================================

    if ! [[ "$G700_RESULT" =~ ^[0-9]{6}$ ]]; then
        echo
        echo "✗ Failed to calculate code."
        echo
        read -r -p "Press ENTER to return..."
        return
    fi

    # ============================================================
    # DISPLAY
    # ============================================================

    clear

    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    ✓ CODE GENERATED                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    echo "Region        : $G700_REGION_NAME"
    echo "Timezone      : $G700_TZ"
    echo "Software      : $G700_VERSION_NAME"
    echo "Date          : $G700_DATE"
    printf "Time          : %02d:%02d:%02d\n" \
        "$G700_HOUR" "$G700_MINUTE" "$G700_SECOND"
    echo

    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│                    ENGINEERING CODE                          │"
    echo "├──────────────────────────────────────────────────────────────┤"
    echo "│                                                              │"
    printf "│                         %s                               │\n" "$G700_RESULT"
    echo "│                                                              │"
    echo "└──────────────────────────────────────────────────────────────┘"
    echo

    if [[ "$G700_DYNAMIC" == "true" ]]; then

        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│                     CONNECTION CODE                          │"
        echo "├──────────────────────────────────────────────────────────────┤"
        echo "│                                                              │"
        printf "│                       *#%s#*                             │\n" "$G700_RESULT"
        echo "│                                                              │"
        echo "└──────────────────────────────────────────────────────────────┘"

    else

        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│                     CONNECTION CODE                          │"
        echo "├──────────────────────────────────────────────────────────────┤"
        echo "│                                                              │"
        printf "│                      %s                            │\n" "$G700_DIAL"
        echo "│                                                              │"
        echo "└──────────────────────────────────────────────────────────────┘"

    fi

    echo
    echo "⏱ Code is tied to the selected region's local clock."
    echo "=============================================================="
    echo

    read -r -p "Press ENTER to return..."
}


# ============================================================
# G700 APP INSTALLER
# ============================================================

G700_INSTALL_APPS() {
  clear

  select_device || {
    echo "Returning to main menu..."
    return
  }

  wait_for_adb

  echo "🚀 Installing Apps on G700"
  echo

  # ============================================================
  # GET ALL USERS
  # ============================================================

  USERS=($(ADB_CMD shell pm list users 2>/dev/null | \
    grep -oE 'UserInfo\{[0-9]+' | \
    cut -d'{' -f2 | \
    tr -d '\r'))

  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | \
      grep -oE 'UserInfo\{[0-9]+' | \
      cut -d'{' -f2 | \
      tr -d '\r'))
  fi

  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | \
      grep -oE 'UserInfo\{[0-9]+' | \
      cut -d'{' -f2 | \
      tr -d '\r'))
  fi

  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)

  echo "👥 Users: ${USERS[*]}"
  echo

  # ============================================================
  # INSTALL ROOT G700 APKs
  # ============================================================

  USE_ALL_USERS=true

  install_apks_in_folder "$DESKTOP_APK/G700"

  USE_ALL_USERS=false

  # ============================================================
  # INSTALL APKs FROM SUBFOLDERS
  # ============================================================

  install_from_subfolders "$DESKTOP_APK/G700" "G700"

  # ============================================================
  # SET PERMISSIONS
  # ============================================================

  set_permissions

  # ============================================================
  # RESTART eLauncher FOR ALL USERS
  # ============================================================

  for user in $(ADB_CMD shell pm list users 2>/dev/null | \
    grep -oE 'UserInfo\{[0-9]+' | \
    cut -d'{' -f2 | \
    tr -d '\r'); do

    echo "Restarting eLauncher for user $user..."

    ADB_CMD shell am force-stop \
      --user "$user" \
      qa.essa.elauncher

    ADB_CMD shell am start \
      --user "$user" \
      -n qa.essa.elauncher/.MainActivity

  done

  echo
  echo "✅ Installed Successfully"

  disconnect_if_wireless
}


# ============================================================
# G700 MAIN MENU
# ============================================================

G700() {

    while true; do

        clear

        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                       🚙 G700 TOOLS                          ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║  1. 🔐 Generate G700 Code                                    ║"
        echo "║  2. 📱 Install Apps                                          ║"
        echo "║  0. ↩️  Back                                                  ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo

        read -r -p "CHOOSE: " G700_OPTION

        case "$G700_OPTION" in

            1)
                G700_GENERATE_CODE
                ;;

            2)
                G700_INSTALL_APPS
                ;;

            0)
                return
                ;;

            *)
                echo
                echo "✗ Invalid option."
                sleep 1
                ;;

        esac

    done
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
  # ADB_CMD shell pm disable-user ecarx.notificationcenterui 2>/dev/null || true
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
    select_device || { echo "Returning to main menu..."; return; }
    wait_for_adb

    echo "🚀 Installing Apps on AVATR 11"

    USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))

    if [[ ${#USERS[@]} -eq 0 ]]; then
        USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
    fi

    if [[ ${#USERS[@]} -eq 0 ]]; then
        USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
    fi

    [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)

    echo "👥 Users: ${USERS[*]}"

    ############################################################
    # Disable Package Installer
    ############################################################

    for user in "${USERS[@]}"; do
        ADB_CMD shell pm disable-user --user "$user" com.android.packageinstaller >/dev/null 2>&1 || true
    done

    sleep 2

    ############################################################
    # Install Normal APKs
    ############################################################

    for apk in "$DESKTOP_APK/AVATR"/*.apk; do
        [[ -f "$apk" ]] || continue

        echo "📦 Installing: $(basename "$apk")"

        for user in "${USERS[@]}"; do

            output=$(ADB_CMD install -r -d -g \
                --user "$user" \
                -i com.huawei.appmarket.vehicle \
                "$apk" 2>&1)

            if echo "$output" | grep -q "Success"; then
                printf "   👤 User %-3s ✅ Installed\n" "$user"
                continue
            fi

            output=$(ADB_CMD install -r -d -g \
                --user "$user" \
                -i com.huawei.appinstaller.car \
                "$apk" 2>&1)

            if echo "$output" | grep -q "Success"; then
                printf "   👤 User %-3s ✅ Installed (Car Installer)\n" "$user"
            else
                printf "   👤 User %-3s ❌ Failed\n" "$user"
                echo "$output"
            fi

        done
    done

    ############################################################
    # Install ALL Split APK folders Automatically
    ############################################################

    echo ""
    echo "📂 Installing Split APK folders..."

    for folder in "$DESKTOP_APK/AVATR"/*/; do

        [[ -d "$folder" ]] || continue

        name=$(basename "$folder")

        echo ""
        echo "📦 $name"

        shopt -s nullglob
        files=("$folder"/*.apk)
        shopt -u nullglob

        [[ ${#files[@]} -eq 0 ]] && continue

        for user in "${USERS[@]}"; do

            output=$(ADB_CMD install-multiple \
                -r -d -g \
                --user "$user" \
                -i com.huawei.appmarket.vehicle \
                "${files[@]}" 2>&1)

            if echo "$output" | grep -q "Success"; then
                printf "   👤 User %-3s ✅ Installed\n" "$user"
                continue
            fi

            output=$(ADB_CMD install-multiple \
                -r -d -g \
                --user "$user" \
                -i com.huawei.appinstaller.car \
                "${files[@]}" 2>&1)

            if echo "$output" | grep -q "Success"; then
                printf "   👤 User %-3s ✅ Installed (Car Installer)\n" "$user"
            else
                printf "   👤 User %-3s ❌ Failed\n" "$user"
                echo "$output"
            fi

        done

    done

    ############################################################
    # Permissions
    ############################################################

    set_permissions

    ############################################################
    # Re-enable Package Installer
    ############################################################

    for user in "${USERS[@]}"; do
        ADB_CMD shell pm enable --user "$user" com.android.packageinstaller >/dev/null 2>&1 || true
    done

    ############################################################
    # Set Chrome as Default Browser
    ############################################################

    echo ""
    echo "🌐 Setting Chrome as Default Browser..."

    for user in "${USERS[@]}"; do

        if ADB_CMD shell cmd role add-role-holder --user "$user" android.app.role.BROWSER com.android.chrome >/dev/null 2>&1; then
            printf "   👤 User %-3s ✅ Chrome set as default browser\n" "$user"
        else
            printf "   👤 User %-3s ⚠️ Unable to set default browser\n" "$user"
        fi

    done

    echo ""
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

# ============================================================
# DEEPAL TOOLS
# ============================================================

# ============================================================
# DEEPAL TOOLS
# ============================================================

Deepal73() {

  while true; do

    clear

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     🚗 DEEPAL TOOLS                          ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  1. 🔐 Generate Engineering Mode Password                    ║"
    echo "║  2. 🌐 Online Code Generator                                 ║"
    echo "║  3. 🔄 Refresh ADB Connection                                ║"
    echo "║  4. 📱 Install Deepal Apps                                   ║"
    echo "║  5. 🔑 Authorize Deepal Tools                                ║"
    echo "║  6. 📋 Device Information                                    ║"
    echo "║  0. ↩️  Back                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    echo -n "CHOOSE: "
    read -r dopt

    case "$dopt" in

      1)

        deepal_password

        ;;

      2)

        deepal_online_generator

        ;;

      3)

        echo
        echo "🔄 Refreshing ADB..."
        echo

        select_device

        if [[ -n "$TARGET_DEVICE" ]]; then

          wait_for_adb

          echo
          echo "✅ ADB device: $TARGET_DEVICE"

        fi

        ;;

      4)

        deepal_install

        ;;

      5)

        deepal_authorize

        ;;

      6)

        deepal_info

        ;;

      0)

        return

        ;;

      *)

        echo
        echo "❌ Invalid option!"
        echo

        ;;

    esac

    echo
    echo "Press Enter to return to Deepal menu..."
    read -r

  done

}

# Deepal73() {
#   while true; do
#     clear
#     echo "╔══════════════════════════════════════════════════════════════╗"
#     echo "║                     🚗 DEEPAL TOOLS                          ║"
#     echo "╠══════════════════════════════════════════════════════════════╣"
#     echo "║  1. 🔐 Generate Engineering Mode Password                    ║"
#     echo "║  2. 🔄 Refresh ADB Connection                                ║"
#     echo "║  3. 📱 Install Deepal Apps                                   ║"
#     echo "║  4. 🔑 Authorize Deepal Tools                                ║"
#     echo "║  5. 📋 Device Information                                    ║"
#     echo "║  0. ↩️  Back                                                  ║"
#     echo "╚══════════════════════════════════════════════════════════════╝"
#     echo -n "CHOOSE: "
#     read -r dopt

#     case "$dopt" in
#       1)
#         deepal_password
#         ;;
#       2)
#         echo ""
#         echo "🔄 Refreshing ADB..."
#         select_device
#         if [[ -n "$TARGET_DEVICE" ]]; then
#           wait_for_adb
#           echo "✅ ADB device: $TARGET_DEVICE"
#         fi
#         ;;
#       3)
#         deepal_install
#         ;;
#       4)
#         deepal_authorize
#         ;;
#       5)
#         deepal_info
#         ;;
#       0)
#         return
#         ;;
#       *)
#         echo "❌ Invalid option!"
#         ;;
#     esac

#     echo -e "\nPress Enter to return to Deepal menu..."
#     read -r
#   done
# }

# ------------------------------------------------------------
# Deepal Engineering Mode Password
# ------------------------------------------------------------
deepal_password() {
  clear
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║              🔐 DEEPAL ENGINEERING PASSWORD                  ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Enter the last 4 characters of the VIN:"
  echo -n "> "
  read -r vin4
  vin4=$(echo "$vin4" | tr '[:lower:]' '[:upper:]' | tr -cd '[:alnum:]')

  if [[ ${#vin4} -lt 4 ]]; then
    echo "❌ VIN must contain at least 4 characters."
    return
  fi

  echo ""
  echo "Select vehicle model:"
  echo ""
  echo "1. C385      - Deepal SL03"
  echo "2. C673      - Deepal S7"
  echo "3. C673_ICA  - Deepal S07"
  echo "4. L07       - Deepal L07 (Code: C385_MCA)"
  echo "5. Custom model code"
  echo -n "Select (1-5, default 4): "
  read -r model_choice

  case "$model_choice" in
    1) model_code="C385" ;;
    2) model_code="C673" ;;
    3) model_code="C673_ICA" ;;
    5)
      echo -n "Enter custom model code: "
      read -r model_code
      model_code=$(echo "$model_code" | tr -d '[:space:]')
      ;;
    *) model_code="C385_MCA" ;;
  esac

  vin_tail="${vin4: -4}"
  mmdd=$(date '+%m%d')

  # Same password flow used by the standalone Deepal tool:
  # SHA256(model + VIN last 4 + MMDD), then take 12 chars.
  if command -v shasum >/dev/null 2>&1; then
    hash=$(printf '%s' "${model_code}${vin_tail}${mmdd}" | shasum -a 256 | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    hash=$(printf '%s' "${model_code}${vin_tail}${mmdd}" | sha256sum | awk '{print $1}')
  else
    echo "❌ SHA-256 utility not found."
    return
  fi

  day=$(date '+%-d' 2>/dev/null)
  if [[ -z "$day" ]]; then
    day=$(date '+%d' | sed 's/^0//')
  fi

  start=$((day + 1))
  password="${hash:$start:12}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔐 Engineering Mode Password: $password"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Vehicle Code : $model_code"
  echo "VIN Last 4   : $vin_tail"
  echo "Date         : $mmdd"
  echo ""
  echo "➡️  Engineering Mode → USB Mode Switch → DEVICE"
  echo "➡️  Then choose Refresh ADB from the Deepal menu."
}

# ------------------------------------------------------------
# Deepal ADB refresh / connection
# ------------------------------------------------------------
deepal_refresh_adb() {
  echo "🔄 Refreshing ADB connection..."
  select_device || return 1
  wait_for_adb
  echo "✅ ADB ready: $TARGET_DEVICE"
  return 0
}

# ------------------------------------------------------------
# Deepal App installation
# ------------------------------------------------------------
deepal_install() {
  clear
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║                  📱 DEEPAL APP INSTALLER                     ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  select_device || { echo "Returning to Deepal menu..."; return; }
  wait_for_adb

  DEEPAL_DIR="$DESKTOP_APK/Deepal"

  if [[ ! -d "$DEEPAL_DIR" ]]; then
    echo "❌ Deepal folder not found: $DEEPAL_DIR"
    echo ""
    echo "Create: ~/Desktop/apk/Deepal/"
    return
  fi

  USERS=($(ADB_CMD shell pm list users 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell cmd user list 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  if [[ ${#USERS[@]} -eq 0 ]]; then
    USERS=($(ADB_CMD shell dumpsys user 2>/dev/null | grep -oE 'UserInfo\{[0-9]+' | cut -d'{' -f2 | tr -d '\r'))
  fi
  [[ ${#USERS[@]} -eq 0 ]] && USERS=(0)

  echo "👥 Users: ${USERS[*]}"
  echo "📂 Source: $DEEPAL_DIR"
  echo ""

  # Normal APKs
  shopt -s nullglob
  deepal_apks=("$DEEPAL_DIR"/*.apk)
  shopt -u nullglob

  for apk in "${deepal_apks[@]}"; do
    [[ -f "$apk" ]] || continue
    echo "📦 Installing: $(basename "$apk")"

    for user in "${USERS[@]}"; do
      output=$(ADB_CMD install -r -d -g --user "$user" "$apk" 2>&1)
      if echo "$output" | grep -q "Success"; then
        printf "   👤 User %-3s ✅ Installed\n" "$user"
      else
        printf "   👤 User %-3s ❌ Failed\n" "$user"
        echo "$output"
      fi
    done
  done

  # Split APK folders
  for folder in "$DEEPAL_DIR"/*/; do
    [[ -d "$folder" ]] || continue

    shopt -s nullglob
    files=("$folder"/*.apk)
    shopt -u nullglob
    [[ ${#files[@]} -eq 0 ]] && continue

    echo ""
    echo "📦 Split package: $(basename "$folder")"

    for user in "${USERS[@]}"; do
      output=$(ADB_CMD install-multiple -r -d -g --user "$user" "${files[@]}" 2>&1)
      if echo "$output" | grep -q "Success"; then
        printf "   👤 User %-3s ✅ Installed\n" "$user"
      else
        printf "   👤 User %-3s ❌ Failed\n" "$user"
        echo "$output"
      fi
    done
  done

  echo ""
  echo "🎉 Deepal installation completed."
  disconnect_if_wireless
}

# ------------------------------------------------------------
# Deepal Tools authorization
# ------------------------------------------------------------
deepal_authorize() {
  clear
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║                  🔑 DEEPAL AUTHORIZATION                     ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  select_device || { echo "Returning to Deepal menu..."; return; }
  wait_for_adb

  DEEPAL_PACKAGE="com.yukiovo.deepaltools"

  echo "🔑 Granting WRITE_SECURE_SETTINGS..."
  output=$(ADB_CMD shell pm grant "$DEEPAL_PACKAGE" android.permission.WRITE_SECURE_SETTINGS 2>&1)

  if [[ $? -eq 0 ]]; then
    echo "   ✅ WRITE_SECURE_SETTINGS granted"
  else
    echo "   ⚠️ Permission could not be granted automatically"
    [[ -n "$output" ]] && echo "$output"
  fi

  echo ""
  echo "🔑 Granting REQUEST_INSTALL_PACKAGES AppOp..."
  ADB_CMD shell cmd appops set "$DEEPAL_PACKAGE" REQUEST_INSTALL_PACKAGES allow >/dev/null 2>&1 || true
  echo "   ✓ Done"

  echo ""
  echo "🎉 Deepal authorization process completed."
  disconnect_if_wireless
}

# ------------------------------------------------------------
# Deepal device information
# ------------------------------------------------------------
deepal_info() {
  clear
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║                    📋 DEEPAL DEVICE INFO                     ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  select_device || { echo "Returning to Deepal menu..."; return; }
  wait_for_adb

  echo "Serial      : $(ADB_CMD shell getprop ro.serialno | tr -d '\r')"
  echo "Model       : $(ADB_CMD shell getprop ro.product.model | tr -d '\r')"
  echo "Brand       : $(ADB_CMD shell getprop ro.product.brand | tr -d '\r')"
  echo "Android     : $(ADB_CMD shell getprop ro.build.version.release | tr -d '\r')"
  echo "SDK         : $(ADB_CMD shell getprop ro.build.version.sdk | tr -d '\r')"
  echo "Build       : $(ADB_CMD shell getprop ro.build.display.id | tr -d '\r')"
  echo ""
  echo "👥 Users:"
  ADB_CMD shell pm list users

  disconnect_if_wireless
}

# ============================================================
# DEEPAL ONLINE CODE GENERATOR
# ============================================================

deepal_online_generator() {

    clear

    # ------------------------------------------------------------
    # Website
    # ------------------------------------------------------------

    DEEPAL_ONLINE_URL="https://turansoft.ru"

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║             🔐 DEEPAL ONLINE CODE GENERATOR                  ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║        Generate codes directly from Deepal website           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # ------------------------------------------------------------
    # Check curl
    # ------------------------------------------------------------

    if ! command -v curl >/dev/null 2>&1; then

        echo
        echo "❌ curl is not installed."
        echo

        read -r -p "Press ENTER to return..."
        return

    fi

    # ------------------------------------------------------------
    # Check Python3
    # ------------------------------------------------------------

    if ! command -v python3 >/dev/null 2>&1; then

        echo
        echo "❌ python3 is required."
        echo

        read -r -p "Press ENTER to return..."
        return

    fi


    # ============================================================
    # SOFTWARE VERSION
    # ============================================================

    echo "Software Version:"
    echo
    echo "1. 3.1 and newer"
    echo "2. Up to 3.0 (S07 / SL03)"
    echo "3. Back"
    echo

    while true; do

        read -r -p "Select version [1-3]: " DEEPAL_VERSION_CHOICE

        case "$DEEPAL_VERSION_CHOICE" in

            1)

                DEEPAL_VERSION="3.1"
                break

                ;;

            2)

                DEEPAL_VERSION="3.0"
                DEEPAL_MODEL=""
                break

                ;;

            3)

                return
                ;;

            *)

                echo
                echo "❌ Invalid selection."
                echo

                ;;

        esac

    done


    # ============================================================
    # MODEL
    # ============================================================

    if [[ "$DEEPAL_VERSION" != "3.0" ]]; then

        echo
        echo "Model:"
        echo
        echo "1. S07"
        echo "2. SL03"
        echo "3. S07 2026"
        echo

        while true; do

            read -r -p "Select model [1-3]: " DEEPAL_MODEL_CHOICE

            case "$DEEPAL_MODEL_CHOICE" in

                1)

                    DEEPAL_MODEL="S07"
                    break

                    ;;

                2)

                    DEEPAL_MODEL="SL03"
                    break

                    ;;

                3)

                    DEEPAL_MODEL="S07_RESTYLE"
                    break

                    ;;

                *)

                    echo
                    echo "❌ Invalid model."
                    echo

                    ;;

            esac

        done

    fi


    # ============================================================
    # VIN LAST 4
    # ============================================================

    echo
    echo "Enter the last 4 digits of VIN:"
    echo

    while true; do

        read -r -p "VIN [0000-9999]: " DEEPAL_SEED

        # Keep numbers only
        DEEPAL_SEED=$(printf '%s' "$DEEPAL_SEED" | tr -cd '0-9')

        if [[ ${#DEEPAL_SEED} -eq 4 ]]; then
            break
        fi

        echo
        echo "❌ VIN must contain exactly 4 digits."
        echo

    done


    # ============================================================
    # BUILD JSON
    # ============================================================

    if [[ "$DEEPAL_VERSION" == "3.0" ]]; then

        DEEPAL_PAYLOAD="$(
            python3 - "$DEEPAL_SEED" "$DEEPAL_VERSION" <<'PY'
import json
import sys

seed = sys.argv[1]
version = sys.argv[2]

payload = {
    "seed": seed,
    "version": version
}

print(json.dumps(payload, separators=(",", ":")))
PY
        )"

    else

        DEEPAL_PAYLOAD="$(
            python3 \
                - "$DEEPAL_SEED" "$DEEPAL_VERSION" "$DEEPAL_MODEL" \
                <<'PY'
import json
import sys

seed = sys.argv[1]
version = sys.argv[2]
model = sys.argv[3]

payload = {
    "seed": seed,
    "version": version,
    "model": model
}

print(json.dumps(payload, separators=(",", ":")))
PY
        )"

    fi


    # ============================================================
    # ONLINE REQUEST
    # ============================================================

    clear

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║             🔐 DEEPAL ONLINE CODE GENERATOR                  ║"
    echo "╠══════════════════════════════════════════════════════════════╣"

    if [[ "$DEEPAL_VERSION" == "3.0" ]]; then

        printf "║  Software Version : %-36s     ║\n" "Up to 3.0"

    else

        printf "║  Software Version : %-36s     ║\n" "3.1+"
        printf "║  Model            : %-36s     ║\n" "$DEEPAL_MODEL"

    fi

    printf "║  VIN              : %-36s     ║\n" "****$DEEPAL_SEED"

    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    echo "🌐 Connecting to Deepal online generator..."
    echo


    DEEPAL_RESPONSE="$(
        curl \
            --silent \
            --show-error \
            --location \
            --fail \
            --connect-timeout 15 \
            --max-time 30 \
            -A "Mozilla/5.0" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -X POST \
            --data "$DEEPAL_PAYLOAD" \
            "${DEEPAL_ONLINE_URL%/}/generate" \
            2>&1
    )"

    DEEPAL_CURL_STATUS=$?


    # ============================================================
    # CONNECTION ERROR
    # ============================================================

    if [[ $DEEPAL_CURL_STATUS -ne 0 ]]; then

        echo
        echo "❌ Could not connect to Deepal online generator."
        echo
        echo "Server response:"
        echo "$DEEPAL_RESPONSE"
        echo

        read -r -p "Press ENTER to return..."
        return

    fi


    # ============================================================
    # EMPTY RESPONSE
    # ============================================================

    if [[ -z "$DEEPAL_RESPONSE" ]]; then

        echo
        echo "❌ Empty response received from server."
        echo

        read -r -p "Press ENTER to return..."
        return

    fi


    # ============================================================
    # PARSE JSON RESPONSE
    # ============================================================

    DEEPAL_CODES="$(
        python3 - "$DEEPAL_RESPONSE" <<'PY'
import json
import sys

try:

    data = json.loads(sys.argv[1])

    yesterday = data.get("codeYesterday") or "-"
    today = data.get("codeToday") or data.get("code") or "-"
    tomorrow = data.get("codeTomorrow") or "-"

    print(yesterday)
    print(today)
    print(tomorrow)

except Exception:

    print("-")
    print("-")
    print("-")
PY
    )"


    DEEPAL_YESTERDAY="$(printf '%s\n' "$DEEPAL_CODES" | sed -n '1p')"
    DEEPAL_TODAY="$(printf '%s\n' "$DEEPAL_CODES" | sed -n '2p')"
    DEEPAL_TOMORROW="$(printf '%s\n' "$DEEPAL_CODES" | sed -n '3p')"


    # ============================================================
    # VALIDATE RESPONSE
    # ============================================================

    if [[ "$DEEPAL_YESTERDAY" == "-" &&
          "$DEEPAL_TODAY" == "-" &&
          "$DEEPAL_TOMORROW" == "-" ]]; then

        echo
        echo "❌ Could not retrieve codes from website."
        echo
        echo "Raw server response:"
        echo "$DEEPAL_RESPONSE"
        echo

        read -r -p "Press ENTER to return..."
        return

    fi


    # ============================================================
    # RESULT
    # ============================================================

    clear

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  ✓ ONLINE CODES FOUND                        ║"
    echo "╠══════════════════════════════════════════════════════════════╣"

    if [[ "$DEEPAL_VERSION" == "3.0" ]]; then

        printf "║  Software Version : %-36s     ║\n" "Up to 3.0"

    else

        printf "║  Software Version : %-36s     ║\n" "3.1+"
        printf "║  Model            : %-36s     ║\n" "$DEEPAL_MODEL"

    fi

    printf "║  VIN              : %-36s     ║\n" "****$DEEPAL_SEED"

    echo "╚══════════════════════════════════════════════════════════════╝"
    echo


    # ============================================================
    # YESTERDAY
    # ============================================================

    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│                         YESTERDAY                            │"
    echo "├──────────────────────────────────────────────────────────────┤"
    printf "│                       %-30s         │\n" "$DEEPAL_YESTERDAY"
    echo "└──────────────────────────────────────────────────────────────┘"
    echo


    # ============================================================
    # TODAY
    # ============================================================

    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│                           TODAY                              │"
    echo "├──────────────────────────────────────────────────────────────┤"
    printf "│                       %-30s         │\n" "$DEEPAL_TODAY"
    echo "└──────────────────────────────────────────────────────────────┘"
    echo


    # ============================================================
    # TOMORROW
    # ============================================================

    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│                          TOMORROW                            │"
    echo "├──────────────────────────────────────────────────────────────┤"
    printf "│                       %-30s         │\n" "$DEEPAL_TOMORROW"
    echo "└──────────────────────────────────────────────────────────────┘"
    echo


    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "🌐 Source: BestStore.ae"
    echo "✓ Codes retrieved online"
    echo

    read -r -p "Press ENTER to return..."

}

# ============================================================
# XMOD / ACTIVA DASHBOARD
# ============================================================

# Activa_Dashboard() {

#     clear

#     echo
#     echo "╔══════════════════════════════════════════════════════════════╗"
#     echo "║                    🚀 ACTIVA DASHBOARD                      ║"
#     echo "╠══════════════════════════════════════════════════════════════╣"
#     echo "║              XMod Installer / Dashboard Setup               ║"
#     echo "╚══════════════════════════════════════════════════════════════╝"
#     echo

#     # ============================================================
#     # PATHS
#     # ============================================================

#     local X9_DIR="$USER_HOME/Desktop/9x"

#     # APK used for the XMod installation/bootstrap
#     local XMOD_INSTALLER="$X9_DIR/Install/XModInstaller.apk"

#     # Dashboard APK - change this folder/name if needed
#     local DASHBOARD_DIR="$X9_DIR/Dashboard"
#     local DASHBOARD_APK="$DASHBOARD_DIR/Dashboard.apk"

#     echo "📁 X9 Directory:"
#     echo "   $X9_DIR"
#     echo

#     echo "📦 XMod Installer:"
#     echo "   $XMOD_INSTALLER"
#     echo

#     echo "📱 Dashboard:"
#     echo "   $DASHBOARD_APK"
#     echo

#     # ============================================================
#     # CHECK FILES
#     # ============================================================

#     if [[ ! -d "$X9_DIR" ]]; then
#         echo "❌ 9x folder not found:"
#         echo "   $X9_DIR"
#         return 1
#     fi

#     if [[ ! -f "$XMOD_INSTALLER" ]]; then
#         echo "❌ XModInstaller.apk not found:"
#         echo "   $XMOD_INSTALLER"
#         return 1
#     fi

#     if [[ ! -f "$DASHBOARD_APK" ]]; then
#         echo "❌ Dashboard APK not found:"
#         echo "   $DASHBOARD_APK"
#         return 1
#     fi

#     echo "✅ Required files found."
#     echo

#     # ============================================================
#     # SELECT DEVICE
#     # ============================================================

#     select_device || {
#         echo "❌ No device selected."
#         return 1
#     }

#     wait_for_adb

#     echo
#     echo "📱 Device:"
#     echo "   $TARGET_DEVICE"
#     echo

#     # ============================================================
#     # VERIFY ADB ROOT
#     # ============================================================

#     echo "🔐 Checking ADB root..."

#     local ROOT_ID
#     ROOT_ID=$(ADB_CMD shell id 2>/dev/null | tr -d '\r')

#     if [[ "$ROOT_ID" != *"uid=0"* ]]; then
#         echo "⚠️ ADB is not currently root."
#         echo
#         echo "Attempting adb root..."

#         ADB_CMD root >/dev/null 2>&1 || true

#         sleep 2
#         wait_for_adb

#         ROOT_ID=$(ADB_CMD shell id 2>/dev/null | tr -d '\r')
#     fi

#     if [[ "$ROOT_ID" != *"uid=0"* ]]; then
#         echo
#         echo "❌ ADB root is required for XMod bootstrap."
#         echo "   Current identity:"
#         echo "   $ROOT_ID"
#         echo
#         return 1
#     fi

#     echo "✅ ADB root confirmed."
#     echo

#     # ============================================================
#     # INSTALL XMOD INSTALLER
#     # ============================================================

#     echo "📦 Installing XMod Installer..."
#     echo

#     if ! ADB_CMD install -r "$XMOD_INSTALLER"; then
#         echo
#         echo "❌ Failed to install XModInstaller.apk"
#         return 1
#     fi

#     echo
#     echo "✅ XMod Installer installed."
#     echo

#     # ============================================================
#     # GET PACKAGE NAME
#     # ============================================================

#     local XMOD_PKG="com.xmod.customs.installer"

#     echo "🔎 Checking XMod package..."

#     if ! ADB_CMD shell pm path "$XMOD_PKG" >/dev/null 2>&1; then
#         echo "❌ XMod Installer package was not found:"
#         echo "   $XMOD_PKG"
#         return 1
#     fi

#     echo "✅ Package detected:"
#     echo "   $XMOD_PKG"
#     echo

#     # ============================================================
#     # GRANT REQUIRED PERMISSIONS
#     # ============================================================

#     echo "🔐 Applying XMod permissions..."

#     ADB_CMD shell pm grant \
#         "$XMOD_PKG" \
#         android.permission.ACCESS_COARSE_LOCATION \
#         2>/dev/null || true

#     ADB_CMD shell pm grant \
#         "$XMOD_PKG" \
#         android.permission.ACCESS_FINE_LOCATION \
#         2>/dev/null || true

#     ADB_CMD shell appops set \
#         "$XMOD_PKG" \
#         COARSE_LOCATION \
#         allow \
#         2>/dev/null || true

#     ADB_CMD shell appops set \
#         "$XMOD_PKG" \
#         FINE_LOCATION \
#         allow \
#         2>/dev/null || true

#     ADB_CMD shell appops set \
#         "$XMOD_PKG" \
#         REQUEST_INSTALL_PACKAGES \
#         allow \
#         2>/dev/null || true

#     echo "✅ Required permissions applied."
#     echo

#     # ============================================================
#     # LAUNCH XMOD INSTALLER
#     # ============================================================

#     echo "🚀 Launching XMod Installer..."

#     ADB_CMD shell am start \
#         -n "$XMOD_PKG/.MainActivity" \
#         >/dev/null 2>&1 || true

#     sleep 2

#     # ============================================================
#     # INSTALL DASHBOARD
#     # ============================================================

#     echo
#     echo "📱 Installing Activa Dashboard..."
#     echo

#     if ! ADB_CMD install -r "$DASHBOARD_APK"; then
#         echo
#         echo "❌ Failed to install Dashboard APK."
#         return 1
#     fi

#     echo
#     echo "✅ Dashboard installed successfully."
#     echo

#     # ============================================================
#     # DETECT DASHBOARD PACKAGE
#     # ============================================================

#     local DASHBOARD_PKG
#     DASHBOARD_PKG=$(get_package_name "$DASHBOARD_APK")

#     if [[ -z "$DASHBOARD_PKG" ]]; then
#         echo "⚠️ Could not automatically detect Dashboard package."
#         echo "   APK was installed successfully."
#     else
#         echo "📦 Dashboard package:"
#         echo "   $DASHBOARD_PKG"
#         echo

#         echo "🚀 Launching Dashboard..."

#         ADB_CMD shell monkey \
#             -p "$DASHBOARD_PKG" \
#             1 >/dev/null 2>&1 || true
#     fi

#     echo
#     echo "╔══════════════════════════════════════════════════════════════╗"
#     echo "║              ✅ ACTIVA DASHBOARD READY                      ║"
#     echo "╚══════════════════════════════════════════════════════════════╝"
#     echo

#     disconnect_if_wireless
# }

# ============================================================
# ACTIVA DASHBOARD (ZEEKR)
# ============================================================

# Activa_Dashboard() {

#     clear

#     echo
#     echo "╔══════════════════════════════════════════════════════════════╗"
#     echo "║              🚀 ACTIVA DASHBOARD (ZEEKR)                     ║"
#     echo "╠══════════════════════════════════════════════════════════════╣"
#     echo "║          XMod Bootstrap + Dashboard Installation             ║"
#     echo "╚══════════════════════════════════════════════════════════════╝"
#     echo

#     # ============================================================
#     # XMOD DIRECTORY
#     # ============================================================

#     local XMOD_DIR="$DESKTOP_APK/9X/Dashboard"

#     echo "📁 Apps directory:"
#     echo "   $XMOD_DIR"
#     echo

#     if [[ ! -d "$XMOD_DIR" ]]; then
#         echo "❌ Folder not found:"
#         echo "   $XMOD_DIR"
#         return 1
#     fi

#     # ============================================================
#     # FIND ALL APK FILES
#     # ============================================================

#     local APK_FILES=()

#     while IFS= read -r -d '' apk; do
#         APK_FILES+=("$apk")
#     done < <(find "$XMOD_DIR" -type f \( -iname "*.apk" \) -print0)

#     if [[ ${#APK_FILES[@]} -eq 0 ]]; then
#         echo "❌ No APK files found in:"
#         echo "   $XMOD_DIR"
#         return 1
#     fi

#     echo "📦 APKs found: ${#APK_FILES[@]}"
#     echo

#     for apk in "${APK_FILES[@]}"; do
#         echo "   • $(basename "$apk")"
#     done

#     echo

#     # ============================================================
#     # SELECT DEVICE
#     # ============================================================

#     select_device || {
#         echo "❌ No device selected."
#         return 1
#     }

#     wait_for_adb

#     echo
#     echo "📱 Device: $TARGET_DEVICE"
#     echo

#     # ============================================================
#     # VERIFY ROOT
#     # ============================================================

#     echo "🔐 Checking ADB root..."

#     local ROOT_ID
#     ROOT_ID=$(ADB_CMD shell id 2>/dev/null | tr -d '\r')

#     if [[ "$ROOT_ID" != *"uid=0"* ]]; then

#         echo "⚠️ ADB is not root."
#         echo "🔄 Attempting adb root..."

#         ADB_CMD root >/dev/null 2>&1 || true

#         sleep 2
#         wait_for_adb

#         ROOT_ID=$(ADB_CMD shell id 2>/dev/null | tr -d '\r')
#     fi

#     if [[ "$ROOT_ID" != *"uid=0"* ]]; then
#         echo
#         echo "❌ ADB root is required."
#         echo "   Current identity:"
#         echo "   $ROOT_ID"
#         return 1
#     fi

#     echo "✅ ADB root confirmed."
#     echo

#     # ============================================================
#     # INSTALL ALL APKS
#     # ============================================================

#     echo "📦 Installing all APKs from 9X..."
#     echo

#     local INSTALLED_COUNT=0
#     local FAILED_COUNT=0

#     for apk in "${APK_FILES[@]}"; do

#         echo "──────────────────────────────────────────────────────────────"
#         echo "📦 Installing: $(basename "$apk")"
#         echo

#         if ADB_CMD install -r "$apk"; then
#             echo "✅ Installed: $(basename "$apk")"
#             ((INSTALLED_COUNT++))
#         else
#             echo "❌ Failed: $(basename "$apk")"
#             ((FAILED_COUNT++))
#         fi

#         echo
#     done

#     echo "──────────────────────────────────────────────────────────────"
#     echo
#     echo "📊 Installation Summary"
#     echo "   ✅ Installed : $INSTALLED_COUNT"
#     echo "   ❌ Failed    : $FAILED_COUNT"
#     echo

#     if [[ "$INSTALLED_COUNT" -eq 0 ]]; then
#         echo "❌ No applications were installed."
#         return 1
#     fi

#     # ============================================================
#     # XMOD INSTALLER PACKAGE
#     # ============================================================

#     local XMOD_PKG="com.xmod.customs.installer"

#     echo "🔎 Checking XMod Installer..."

#     if ADB_CMD shell pm path "$XMOD_PKG" >/dev/null 2>&1; then

#         echo "✅ XMod Installer detected."
#         echo

#         # --------------------------------------------------------
#         # REQUIRED PERMISSIONS
#         # --------------------------------------------------------

#         echo "🔐 Applying XMod permissions..."

#         ADB_CMD shell pm grant \
#             "$XMOD_PKG" \
#             android.permission.ACCESS_COARSE_LOCATION \
#             2>/dev/null || true

#         ADB_CMD shell pm grant \
#             "$XMOD_PKG" \
#             android.permission.ACCESS_FINE_LOCATION \
#             2>/dev/null || true

#         ADB_CMD shell appops set \
#             "$XMOD_PKG" \
#             COARSE_LOCATION \
#             allow \
#             2>/dev/null || true

#         ADB_CMD shell appops set \
#             "$XMOD_PKG" \
#             FINE_LOCATION \
#             allow \
#             2>/dev/null || true

#         ADB_CMD shell appops set \
#             "$XMOD_PKG" \
#             REQUEST_INSTALL_PACKAGES \
#             allow \
#             2>/dev/null || true

#         echo "✅ XMod permissions applied."
#         echo

#     else

#         echo "⚠️ XMod Installer package not found:"
#         echo "   $XMOD_PKG"
#         echo
#         echo "The other APKs were installed normally."
#         echo

#     fi

#     # ============================================================
#     # LAUNCH XMOD INSTALLER
#     # ============================================================

#     if ADB_CMD shell pm path "$XMOD_PKG" >/dev/null 2>&1; then

#         echo "🚀 Starting XMod Installer..."

#         ADB_CMD shell am start \
#             -n "$XMOD_PKG/.MainActivity" \
#             >/dev/null 2>&1 || true

#         sleep 2

#         echo "✅ XMod Installer started."
#         echo
#     fi

#     # ============================================================
#     # SHOW INSTALLED PACKAGES
#     # ============================================================

#     echo "📱 Installed XMod-related packages:"
#     echo

#     ADB_CMD shell pm list packages 2>/dev/null |
#         grep -Ei 'xmod|activa|dashboard' |
#         sed 's/^/   /'

#     echo

#     echo "╔══════════════════════════════════════════════════════════════╗"
#     echo "║              ✅ ACTIVA DASHBOARD COMPLETED                   ║"
#     echo "╚══════════════════════════════════════════════════════════════╝"
#     echo

#     disconnect_if_wireless
# }

# ============================================================
# ACTIVA DASHBOARD (ZEEKR)
# ============================================================

Activa_Dashboard() {

    clear

    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              🚀 ACTIVA DASHBOARD (ZEEKR)                     ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║              XMod Installer / Root Bootstrap                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    # ============================================================
    # PATHS
    # ============================================================

    local XMOD_DIR="$DESKTOP_APK/9X/Dashboard"
    local PACKAGE_NAME="com.xmod.customs.installer"
    local DAEMON_CLASS="com.xmod.customs.installer.RootCommandDaemon"
    local AUTO_PREPARE_EXTRA="com.xmod.customs.installer.extra.AUTO_PREPARE_ROOT"
    local BOOTSTRAP_TOKEN_EXTRA="com.xmod.customs.installer.extra.BOOTSTRAP_TOKEN"

    local INSTALLER_APK=""

    echo "📁 Apps directory:"
    echo "   $XMOD_DIR"
    echo

    # ============================================================
    # CHECK DIRECTORY
    # ============================================================

    if [[ ! -d "$XMOD_DIR" ]]; then
        echo "❌ Folder not found:"
        echo "   $XMOD_DIR"
        echo
        read -r -p "Press Enter to return to main menu..."
        return
    fi

    # ============================================================
    # FIND XMOD INSTALLER
    # ============================================================

    INSTALLER_APK=$(find "$XMOD_DIR" -maxdepth 1 -type f \
        -iname "XModInstaller.apk" | head -n 1)

    if [[ -z "$INSTALLER_APK" ]]; then
        echo "❌ XModInstaller.apk not found:"
        echo "   $XMOD_DIR"
        echo
        read -r -p "Press Enter to return to main menu..."
        return
    fi

    echo "📦 XMod Installer:"
    echo "   $(basename "$INSTALLER_APK")"
    echo

    # ============================================================
    # COUNT APKs
    # ============================================================

    local APK_COUNT=0

    for apk in "$XMOD_DIR"/*.apk; do
        [[ -f "$apk" ]] || continue

        echo "   📦 $(basename "$apk")"
        ((APK_COUNT++))
    done

    echo

    if (( APK_COUNT == 0 )); then
        echo "❌ No APK files found."
        echo
        read -r -p "Press Enter to return to main menu..."
        return
    fi

    echo "📦 Total APKs: $APK_COUNT"
    echo

    # ============================================================
    # SELECT DEVICE
    # ============================================================

    select_device || {
        return
    }

    wait_for_adb

    # ============================================================
    # ADB TRANSPORT CHECK
    # ============================================================

    echo
    echo "🔍 Checking ADB devices..."

    local transport_count

    transport_count=$(
        "$ADB" devices 2>/dev/null |
        awk 'NR > 1 && NF >= 2 { count++ } END { print count + 0 }'
    )

    if (( transport_count > 1 )); then

        echo "ADB reported $transport_count devices."
        echo "Restarting its server once..."

        "$ADB" kill-server
        sleep 0.5
        "$ADB" start-server
        sleep 0.5

        transport_count=$(
            "$ADB" devices 2>/dev/null |
            awk 'NR > 1 && NF >= 2 { count++ } END { print count + 0 }'
        )

        if (( transport_count > 1 )); then

            echo
            echo "❌ ADB still reports multiple devices."
            "$ADB" devices
            echo

            read -r -p "Press Enter to return to main menu..."
            return
        fi

        echo "✅ ADB server restarted."
    fi

    # ============================================================
    # WAIT FOR DEVICE
    # ============================================================

    echo "⏳ Waiting for the car..."

    ADB_CMD wait-for-device

    transport_count=$(
        "$ADB" devices 2>/dev/null |
        awk 'NR > 1 && NF >= 2 { count++ } END { print count + 0 }'
    )

    if (( transport_count > 1 )); then

        echo
        echo "❌ More than one ADB device became available."
        "$ADB" devices
        echo

        read -r -p "Press Enter to return to main menu..."
        return
    fi

    # ============================================================
    # REQUEST ROOT ADB
    # ============================================================

    echo
    echo "🔐 Requesting root ADB..."

    ADB_CMD shell 1234abcd >/dev/null 2>&1 || true

    local ADB_UID=""

    for attempt in {1..50}; do

        if ADB_UID=$(ADB_CMD shell id -u 2>/dev/null); then

            ADB_UID=${ADB_UID//$'\r'/}
            ADB_UID=${ADB_UID//$'\n'/}

            if [[ "$ADB_UID" == "0" ]]; then
                break
            fi
        fi

        sleep 0.2
    done

    if [[ "$ADB_UID" != "0" ]]; then

        echo
        echo "❌ The ADB shell is not root."
        echo "   UID=$ADB_UID"
        echo

        read -r -p "Press Enter to return to main menu..."
        return
    fi

    echo "✅ Root ADB verified (uid=0)."
    echo

    # ============================================================
    # INSTALL ALL APPS FROM 9X
    # ============================================================

    echo "📦 Installing all applications from 9X..."
    echo

    local apk
    local INSTALL_OUTPUT

    for apk in "$XMOD_DIR"/*.apk; do

        [[ -f "$apk" ]] || continue

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📦 Installing: $(basename "$apk")"
        echo

        if INSTALL_OUTPUT=$(ADB_CMD install -r "$apk" 2>&1); then

            echo "$INSTALL_OUTPUT"
            echo "✅ Installed successfully."

        else

            echo "$INSTALL_OUTPUT"

            if [[ "$INSTALL_OUTPUT" == *"INSTALL_FAILED_UPDATE_INCOMPATIBLE"* ]]; then

                echo
                echo "⚠️ INSTALL_FAILED_UPDATE_INCOMPATIBLE"
                echo "   Existing application has a different signature."

            else

                echo
                echo "❌ Installation failed."
            fi
        fi

        echo
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # ============================================================
    # VERIFY XMOD INSTALLER
    # ============================================================

    echo "🔎 Checking XMod Installer..."

    local PACKAGE_APK

    PACKAGE_APK=$(
        ADB_CMD shell pm path "$PACKAGE_NAME" |
        tr -d '\r' |
        sed -n 's/^package://p' |
        head -n 1
    )

    if [[ -z "$PACKAGE_APK" ]]; then

        echo
        echo "❌ Could not resolve installed XMod Installer:"
        echo "   $PACKAGE_NAME"
        echo

        read -r -p "Press Enter to return to main menu..."
        return
    fi

    echo "✅ XMod Installer detected."
    echo

    # ============================================================
    # REGISTER XMOD INSTALLER UPDATE OWNER
    # ============================================================

    echo "🔐 Registering XMod Installer as its own update owner..."

    ADB_CMD install -r \
        -i "$PACKAGE_NAME" \
        "$INSTALLER_APK"

    # ============================================================
    # GRANT LOCATION ACCESS
    # ============================================================

    echo "🔐 Granting XMod Installer location access..."

    ADB_CMD shell pm grant \
        "$PACKAGE_NAME" \
        android.permission.ACCESS_COARSE_LOCATION

    ADB_CMD shell pm grant \
        "$PACKAGE_NAME" \
        android.permission.ACCESS_FINE_LOCATION

    ADB_CMD shell appops set \
        "$PACKAGE_NAME" \
        COARSE_LOCATION \
        allow

    ADB_CMD shell appops set \
        "$PACKAGE_NAME" \
        FINE_LOCATION \
        allow

    ADB_CMD shell appops set \
        "$PACKAGE_NAME" \
        REQUEST_INSTALL_PACKAGES \
        allow

    echo "✅ XMod Installer permissions granted."
    echo

    # ============================================================
    # BOOTSTRAP TOKEN
    # ============================================================

    local BOOTSTRAP_TOKEN=""

    echo "🔑 Bootstrap Token"
    echo
    echo "Enter the XMod bootstrap token."
    echo "Press Enter to continue without a token."
    echo

    read -r -p "BOOTSTRAP TOKEN: " BOOTSTRAP_TOKEN

    if [[ -n "$BOOTSTRAP_TOKEN" ]]; then

        if [[ ! "$BOOTSTRAP_TOKEN" =~ ^xmod_boot_[A-Za-z0-9_-]{43}$ ]]; then

            echo
            echo "❌ Desktop supplied an invalid bootstrap token."
            echo

            read -r -p "Press Enter to return to main menu..."
            return
        fi

        echo "✅ Bootstrap token format verified."
    fi

    # ============================================================
    # START XMOD INSTALLER
    # ============================================================

    echo
    echo "🚀 Starting XMod Installer..."

    if [[ -n "$BOOTSTRAP_TOKEN" ]]; then

        ADB_CMD shell am start -W \
            -n "$PACKAGE_NAME/.MainActivity" \
            --es "$BOOTSTRAP_TOKEN_EXTRA" \
            "$BOOTSTRAP_TOKEN" \
            >/dev/null

        BOOTSTRAP_TOKEN=""

    else

        ADB_CMD shell am start -W \
            -n "$PACKAGE_NAME/.MainActivity" \
            >/dev/null
    fi

    # ============================================================
    # CURRENT USER
    # ============================================================

    local CURRENT_USER

    CURRENT_USER=$(
        ADB_CMD shell am get-current-user |
        tr -d '\r'
    )

    # ============================================================
    # APPLICATION DATA
    # ============================================================

    local APP_DATA
    local CHANNEL
    local DAEMON_LOG
    local APP_UID

    APP_DATA="/data/user/$CURRENT_USER/$PACKAGE_NAME"
    CHANNEL="$APP_DATA/files/root-channel"
    DAEMON_LOG="/data/local/tmp/xmod-installer-root.log"

    echo
    echo "🔧 Preparing root channel..."
    echo
    echo "   Current User : $CURRENT_USER"
    echo "   APK          : $PACKAGE_APK"
    echo "   App Data     : $APP_DATA"
    echo "   Root Channel : $CHANNEL"
    echo "   Daemon Log   : $DAEMON_LOG"
    echo

    # ============================================================
    # GET APPLICATION UID
    # ============================================================

    APP_UID=$(
        ADB_CMD shell stat -c %u "$APP_DATA" |
        tr -d '\r'
    )

    if [[ -z "$APP_UID" ]]; then

        echo "❌ Could not determine XMod Installer UID."
        echo

        read -r -p "Press Enter to return to main menu..."
        return
    fi

    echo "   App UID: $APP_UID"
    echo

    # ============================================================
    # STOP PREVIOUS DAEMON
    # ============================================================

    echo "🛑 Stopping previous RootCommandDaemon instances..."

    ADB_CMD shell \
        "for pid in \$(pidof app_process 2>/dev/null); do
            if tr '\\0' ' ' < /proc/\$pid/cmdline 2>/dev/null |
               grep -Fq '$DAEMON_CLASS $CHANNEL';
            then
                kill \$pid 2>/dev/null || true
            fi
        done"

    sleep 0.25

    # ============================================================
    # PREPARE ROOT CHANNEL
    # ============================================================

    echo "📁 Preparing root-channel..."

    ADB_CMD shell \
        "mkdir -p '$CHANNEL' &&
         rm -f '$CHANNEL'/*.request '$CHANNEL'/*.request.tmp \
               '$CHANNEL'/*.result '$CHANNEL'/*.result.tmp \
               '$CHANNEL/ready' &&
         chown '$APP_UID:$APP_UID' '$CHANNEL' &&
         chmod 700 '$CHANNEL'"

    # ============================================================
    # START ROOT COMMAND DAEMON
    # ============================================================

    echo "🚀 Starting RootCommandDaemon..."

    ADB_CMD shell \
        "CLASSPATH='$PACKAGE_APK' \
         nohup app_process /system/bin \
         '$DAEMON_CLASS' \
         '$CHANNEL' \
         </dev/null \
         >'$DAEMON_LOG' 2>&1 &"

    # ============================================================
    # WAIT FOR READY
    # ============================================================

    echo "⏳ Waiting for root companion..."

    local ROOT_READY=false

    for attempt in {1..50}; do

        if ADB_CMD shell test -f "$CHANNEL/ready"; then

            ROOT_READY=true
            break
        fi

        sleep 0.1
    done

    # ============================================================
    # ROOT DAEMON READY
    # ============================================================

    if [[ "$ROOT_READY" == true ]]; then

        ADB_CMD shell am start -W \
            -n "$PACKAGE_NAME/.MainActivity" \
            --ez "$AUTO_PREPARE_EXTRA" true \
            >/dev/null

        echo
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                ✅ ACTIVA DASHBOARD READY                     ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║ XMod Installer installed                                     ║"
        echo "║ Root ADB verified                                            ║"
        echo "║ Permissions granted                                          ║"
        echo "║ RootCommandDaemon running                                    ║"
        echo "║ Root channel ready                                           ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo

        disconnect_if_wireless

        read -r -p "Press Enter to return to main menu..."
        return
    fi

    # ============================================================
    # ROOT DAEMON FAILED
    # ============================================================

    echo
    echo "❌ Root companion did not start."
    echo
    echo "Device log:"
    echo "   $DAEMON_LOG"
    echo

    ADB_CMD shell cat "$DAEMON_LOG" || true

    echo
    read -r -p "Press Enter to return to main menu..."

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
    echo "║ 11. 🚙 Install Apps (G700 + AIO)                             ║"
    echo "║ 12. 📱 Install Apps (LYNK&CO)                                ║"
    echo "║ 13. 📱 Install Apps (Zeeker9X)                               ║"
    echo "║ 14. 🔓 Unlock States (Zeeker9X)                              ║"
    echo "║ 15. 📱 Install Apps (Leepmotor)                              ║"
    echo "║ 16. 📱 Install Apps (BYD_OLD)                                ║"
    echo "║ 17. 📱 Install Apps (AVATR)                                  ║"
    echo "║ 18. 📱 Install Apps (VOYAH)                                  ║"
    echo "║ 19. 📱 Install Apps (ICAR)                                   ║"
    echo "║ 20. 🚗 Deepal Tools (S07 / S03 / L07)                        ║"
    echo "║ 21. 🚀 Activa Dashboard (Zeekr)                              ║"
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
      19) ICAR ;;
      20) Deepal73 ;;
      21) Activa_Dashboard ;;
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
