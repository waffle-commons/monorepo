#!/usr/bin/env bash
# =============================================================================
# scripts/backup-schedule.sh — run `wfl backup` every day (macOS LaunchAgent).
#
# install writes ~/Library/LaunchAgents/dev.waffle-commons.backup.plist and
# loads it into the person's GUI session; it runs scripts/backup-bundles.sh
# daily at the chosen time (19:00 by default) and at the next wake when the Mac
# slept through it. The log goes to ~/Library/Logs/waffle-backup.log.
#
# macOS may ask once for access to iCloud Drive (or the --dest disk) the first
# time the job runs; a refusal shows in the log as "Operation not permitted".
#
# Usage: scripts/backup-schedule.sh install [--at HH:MM] [--dest DIR]
#        scripts/backup-schedule.sh uninstall
#        scripts/backup-schedule.sh status
# Exit:  0 on success, 1 otherwise.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="dev.waffle-commons.backup"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/waffle-backup.log"
DOMAIN="gui/$(id -u)"

die() { printf '✗ %s\n' "$*" >&2; exit 1; }
ok()  { printf '✓ %s\n' "$*"; }

[ "$(uname -s)" = Darwin ] || die "LaunchAgents are macOS only: schedule scripts/backup-bundles.sh with cron or a systemd timer instead"

ACTION="${1:-status}"
shift || true
AT="19:00"
DEST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --at)   [ $# -ge 2 ] || die "--at needs HH:MM"; AT="$2"; shift 2 ;;
    --dest) [ $# -ge 2 ] || die "--dest needs a directory"; DEST="$2"; shift 2 ;;
    *)      die "unknown option: $1" ;;
  esac
done

case "$ACTION" in
  install)
    [[ "$AT" =~ ^([01][0-9]|2[0-3]):([0-5][0-9])$ ]] || die "--at wants HH:MM (24 h), got '$AT'"
    hour=$((10#${BASH_REMATCH[1]}))
    minute=$((10#${BASH_REMATCH[2]}))
    args="<string>$REPO_ROOT/scripts/backup-bundles.sh</string>"
    if [ -n "$DEST" ]; then
      args="$args<string>--dest</string><string>$DEST</string>"
    fi
    mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
    cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string>$args</array>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$minute</integer></dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string></dict>
</dict>
</plist>
PLIST
    plutil -lint "$PLIST" >/dev/null || die "the generated plist does not lint: $PLIST"
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$PLIST"
    ok "daily backup at $AT installed ($PLIST); log: $LOG"
    ok "run it once now with: launchctl kickstart $DOMAIN/$LABEL"
    ;;
  uninstall)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    ok "daily backup removed"
    ;;
  status)
    if [ -f "$PLIST" ]; then
      ok "installed: $PLIST"
      launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -E 'state =|last exit code|runs =' | sed 's/^[[:space:]]*/  /' || printf '  (not loaded: run install again)\n'
    else
      printf '· not installed (scripts/backup-schedule.sh install [--at HH:MM])\n'
    fi
    "$REPO_ROOT/scripts/local-only.sh"
    ;;
  *)
    die "usage: scripts/backup-schedule.sh install [--at HH:MM] [--dest DIR] | uninstall | status"
    ;;
esac
