# Keep-alive (optional)

A free Apple ID signs apps for **7 days only**. After that, iOS refuses to
open the app until you rebuild it. This folder automates that rebuild so you
never have to touch Xcode again.

It's a small background job (`launchd`) that quietly rebuilds and re-signs
the app every few hours and installs it on your iPhone over USB or Wi-Fi. A
single successful run per week is enough — running it more often just makes
sure it doesn't miss the moment your iPhone happens to be reachable.

## Setup (one time, ~1 minute)

1. Keep your iPhone plugged in (or make sure it's on the same Wi-Fi as your Mac).
2. In Terminal:
   ```
   cd keep-alive
   chmod +x install.sh
   ./install.sh
   ```
3. Paste your iPhone's identifier when asked (the script lists it for you).

That's it. From now on the alarm renews itself automatically.

## Check on it

```
launchctl list | grep timeoath
tail -n 30 "$HOME/Library/Application Support/TimeOath/auto-resign.log"
```

If nothing has renewed successfully in 3+ days, you'll get a macOS
notification — well before the 7-day expiry.

## Requirements

- Your Mac needs to be turned on at least briefly every few days.
- Your iPhone needs to be reachable (plugged in, or on the same Wi-Fi with
  "Connect via network" enabled for it in Xcode's Devices window).
- If Xcode ever asks you to sign in to your Apple ID again (rare), do that
  once and the job goes back to running itself.

## Remove it

```
launchctl bootout gui/$(id -u)/com.timeoath.resign
rm ~/Library/LaunchAgents/com.timeoath.resign.plist
rm -r "$HOME/Library/Application Support/TimeOath"
```

## Why this matters (a note for the technically curious)

The build step here deliberately uses `-destination "generic/platform=iOS"`
instead of targeting a specific device. If you couple the *build* to your
iPhone's UDID, the whole re-sign silently fails every time the phone isn't
reachable at the exact moment the job runs — and since re-signing never
happens, the app just expires on day 7 with no warning. Only the *install*
step needs the device, and that one retries for several minutes.
