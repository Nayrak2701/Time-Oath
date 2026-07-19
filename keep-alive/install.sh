#!/bin/zsh
# One-time setup for the auto-resign background job.
# Run this from inside the keep-alive/ folder: ./install.sh
#
# It asks for your iPhone's UDID, fills in the script + launchd plist with
# the correct absolute paths, and loads the job so it starts running
# immediately and on every login from then on.

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$HERE/auto-resign.sh"
PLIST_TEMPLATE="$HERE/com.timeoath.resign.plist.template"
PLIST_OUT="$HOME/Library/LaunchAgents/com.timeoath.resign.plist"

echo "Time Oath — auto-renew setup"
echo "Project folder: $PROJ_DIR"
echo

echo "Finding connected iPhones..."
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
xcrun devicectl list devices 2>/dev/null | grep -iE "iPhone" || echo "  (none found — plug your iPhone in first)"
echo
read "UDID?Paste your iPhone's Identifier from the list above: "

if [ -z "$UDID" ]; then
    echo "No UDID entered, aborting."
    exit 1
fi

sed -i '' \
  -e "s|PROJ_DIR=\"\$HOME/Path/To/Time-Oath\"|PROJ_DIR=\"$PROJ_DIR\"|" \
  -e "s|DEVICE_UDID=\"YOUR-IPHONE-UDID-HERE\"|DEVICE_UDID=\"$UDID\"|" \
  "$SCRIPT"
chmod +x "$SCRIPT"

mkdir -p "$HOME/Library/LaunchAgents"
sed \
  -e "s|REPLACE_WITH_ABSOLUTE_PATH/auto-resign.sh|$SCRIPT|g" \
  -e "s|REPLACE_WITH_HOME|$HOME|g" \
  "$PLIST_TEMPLATE" > "$PLIST_OUT"

launchctl bootout "gui/$(id -u)/com.timeoath.resign" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_OUT"

echo
echo "Done. The app will now silently re-sign and reinstall itself every"
echo "3 hours as long as your Mac is on and the iPhone is reachable."
echo
echo "Check status any time:"
echo "  launchctl list | grep timeoath"
echo "  tail -n 30 \"$HOME/Library/Application Support/TimeOath/auto-resign.log\""
