#!/bin/bash
# Stops and removes the installed app and its LaunchAgent. Leaves settings and
# sample history in place so a reinstall resumes with the same configuration.
set -euo pipefail

LABEL="dev.dmitrii.quotabar"
APP="/Applications/QuotaBar.app"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

echo "==> Unloading ${LABEL}"
launchctl bootout "gui/${UID}/${LABEL}" 2>/dev/null || true

echo "==> Removing ${PLIST}"
rm -f "${PLIST}"

echo "==> Removing ${APP}"
rm -rf "${APP}"

echo "==> Uninstalled. Left in place:"
echo "    ~/Library/Application Support/QuotaBar (settings.json, history.json)"
echo "    ~/Library/Logs/QuotaBar (stdout/stderr logs)"
echo "Delete those by hand if you want a clean slate."