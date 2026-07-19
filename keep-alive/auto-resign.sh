#!/bin/zsh
# Time Oath — automatic re-sign + reinstall.
#
# A free Apple ID signs apps for 7 days only. This script rebuilds and
# re-signs the app before that clock runs out, so you never have to open
# Xcode by hand. Run it on a schedule (see install.sh) and forget about it.
#
# IMPORTANT: the build uses "generic/platform=iOS" on purpose — it must NOT
# depend on the iPhone being reachable. Only the install step needs the
# device, and that step retries. (Coupling the build to a specific device
# destination is a common mistake: if the phone is briefly unreachable when
# the job runs, the build itself fails and nothing gets re-signed.)

set -u

# ---- Fill these in for your setup -----------------------------------------
PROJ_DIR="$HOME/Path/To/Time-Oath"        # folder containing Aufstehen.xcodeproj
DEVICE_UDID="YOUR-IPHONE-UDID-HERE"       # find with: xcrun devicectl list devices
# -----------------------------------------------------------------------------

DEVELOPER_DIR_PATH="/Applications/Xcode.app/Contents/Developer"
export DEVELOPER_DIR="$DEVELOPER_DIR_PATH"

DD="$HOME/Library/Caches/timeoath-autobuild"
BASE="$HOME/Library/Application Support/TimeOath"
LOG="$BASE/auto-resign.log"
STAMP="$BASE/last-success"

mkdir -p "$BASE"

log()    { echo "$@" >> "$LOG"; }
notify() { osascript -e "display notification \"$1\" with title \"Time Oath\" sound name \"Basso\"" >/dev/null 2>&1; }

# Warn only once the last successful signing is getting old (app expires
# after 7 days), so one unreachable-iPhone run doesn't spam notifications.
warn_if_stale() {
    local last=0
    [ -f "$STAMP" ] && last=$(stat -f %m "$STAMP")
    local age=$(( ( $(date +%s) - last ) / 86400 ))
    if [ "$age" -ge 3 ]; then
        log ">> WARNING: last successful signing was ${age} days ago (expires after 7)."
        notify "Alarm not renewed for ${age} days — it expires after 7. Check the log."
    fi
}

log ""
log "===== $(date '+%Y-%m-%d %H:%M:%S') : start ====="

if [ "$PROJ_DIR" = "$HOME/Path/To/Time-Oath" ] || [ "$DEVICE_UDID" = "YOUR-IPHONE-UDID-HERE" ]; then
    log ">> Not configured yet — edit PROJ_DIR and DEVICE_UDID at the top of this script."
    exit 3
fi

# --- 1) Build + sign (no iPhone required) -----------------------------------
xcodebuild -project "$PROJ_DIR/Aufstehen.xcodeproj" -scheme Aufstehen \
  -destination "generic/platform=iOS" -configuration Debug \
  -derivedDataPath "$DD" -allowProvisioningUpdates build >> "$LOG" 2>&1
if [ $? -ne 0 ]; then
    if tail -n 200 "$LOG" | grep -qiE "Unable to log in|login details.*rejected|No profiles for"; then
        log ">> BUILD FAILED: Apple ID session expired."
        log ">> Fix once: Xcode > Settings > Accounts > sign in again."
        notify "Apple ID sign-in expired. Open Xcode > Settings > Accounts."
    else
        log ">> BUILD FAILED (see errors above)."
        warn_if_stale
    fi
    exit 1
fi

# --- 2) Install (iPhone required) — retry, it may be asleep or off Wi-Fi ---
APP="$DD/Build/Products/Debug-iphoneos/Aufstehen.app"
for i in $(seq 1 10); do
    if xcrun devicectl device install app --device "$DEVICE_UDID" "$APP" >> "$LOG" 2>&1; then
        log ">> INSTALLED OK (attempt $i) — 7-day clock reset."
        touch "$STAMP"
        exit 0
    fi
    log ">> install attempt $i failed (iPhone unreachable/locked), retry in 90s"
    sleep 90
done

log ">> INSTALL FAILED — iPhone was not reachable this run."
warn_if_stale
exit 2
