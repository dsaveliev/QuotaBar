#!/bin/bash
# Builds the app, installs it to /Applications, and registers a LaunchAgent so
# it starts at login and is restarted if it dies abnormally. A clean quit is
# final: the app stays off until the user starts it again.
set -euo pipefail

cd "$(dirname "$0")/.."

LABEL="dev.dmitrii.quotabar"
APP="/Applications/QuotaBar.app"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOGS="$HOME/Library/Logs/QuotaBar"

./scripts/build-app.sh

echo "==> Quitting any running instance"
# This quit is final: KeepAlive below only restarts an abnormal exit, so this
# app does not come back on its own. The bootstrap + kickstart at the end of
# this script is what brings it back. Do not reorder or drop this block - it is
# what lets the old binary be replaced without a second copy left running.
osascript -e 'quit app "QuotaBar"' >/dev/null 2>&1 || true
sleep 1

echo "==> Installing ${APP}"
rm -rf "${APP}"
cp -R build/QuotaBar.app "${APP}"

echo "==> Writing ${PLIST}"
mkdir -p "$HOME/Library/LaunchAgents" "${LOGS}"
cat > "${PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${APP}/Contents/MacOS/quotabar</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <!-- Restart on abnormal exit only. A bare <true/> would also restart the
         app after the user quits it, which makes the Quit button a lie. -->
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>${LOGS}/quotabar.log</string>
    <key>StandardErrorPath</key>
    <string>${LOGS}/quotabar.err.log</string>
</dict>
</plist>
PLIST

echo "==> Loading the LaunchAgent"
# Unload first, then wait for launchd to actually drop the service: bootstrapping
# while the old job is still registered fails with "Input/output error".
if launchctl print "gui/${UID}/${LABEL}" >/dev/null 2>&1; then
    launchctl bootout "gui/${UID}/${LABEL}" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        launchctl print "gui/${UID}/${LABEL}" >/dev/null 2>&1 || break
        sleep 1
    done
fi

loaded=0
for attempt in 1 2 3 4 5; do
    if launchctl bootstrap "gui/${UID}" "${PLIST}" 2>/dev/null; then
        loaded=1
        break
    fi
    echo "    bootstrap attempt ${attempt} failed, retrying…"
    sleep 2
done

if [ "${loaded}" -ne 1 ]; then
    echo "error: could not load ${LABEL} after 5 attempts" >&2
    echo "       try: launchctl bootstrap gui/\$UID ${PLIST}" >&2
    exit 1
fi

launchctl kickstart -k "gui/${UID}/${LABEL}"

echo "==> Installed:"
echo "    app:    ${APP}"
echo "    agent:  ${PLIST} (${LABEL})"
echo "    logs:   ${LOGS}/quotabar.log, ${LOGS}/quotabar.err.log"
echo "    remove: ./scripts/uninstall.sh"