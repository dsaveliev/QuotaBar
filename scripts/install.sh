#!/bin/bash
# Builds the app, installs it to /Applications, and registers a LaunchAgent so
# it starts at login and is restarted if it dies.
set -euo pipefail

cd "$(dirname "$0")/.."

LABEL="dev.dmitrii.quotabar"
APP="/Applications/QuotaBar.app"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOGS="$HOME/Library/Logs/QuotaBar"

./scripts/build-app.sh

echo "==> Quitting any running instance"
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
    <key>KeepAlive</key>
    <true/>
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