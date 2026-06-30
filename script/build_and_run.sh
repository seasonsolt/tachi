#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Tachi"
PRODUCT_NAME="Tachi"
LAUNCH_AGENT_LABEL="com.seasonsolt.tachi.local"
LEGACY_LAUNCH_AGENT_LABELS=("com.seasonsolt.monolith.local")

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PANEL_DIR="$ROOT_DIR/eacc-panel"
INSTALLED_APP="/Applications/$APP_NAME.app"
LOG_FILE="${TMPDIR:-/tmp}/tachi.log"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_LABEL.plist"
LAUNCH_AGENT_STDOUT="${TMPDIR:-/tmp}/tachi-launchagent.log"
LAUNCH_AGENT_STDERR="${TMPDIR:-/tmp}/tachi-launchagent.err"
USER_DOMAIN="gui/$(id -u)"

stop_app() {
  launchctl bootout "$USER_DOMAIN" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
  for legacy_label in "${LEGACY_LAUNCH_AGENT_LABELS[@]}"; do
    local legacy_plist="$HOME/Library/LaunchAgents/$legacy_label.plist"
    launchctl bootout "$USER_DOMAIN" "$legacy_plist" >/dev/null 2>&1 || true
  done
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
  cd "$PANEL_DIR"
  ./build.sh
}

app_binary() {
  printf "%s/Contents/MacOS/%s\n" "$INSTALLED_APP" "$APP_NAME"
}

write_launch_agent() {
  local binary="$1"
  mkdir -p "$(dirname "$LAUNCH_AGENT_PLIST")"
  rm -f "$LAUNCH_AGENT_PLIST"
  plutil -create xml1 "$LAUNCH_AGENT_PLIST"
  plutil -insert Label -string "$LAUNCH_AGENT_LABEL" "$LAUNCH_AGENT_PLIST"
  plutil -insert ProgramArguments -json "[\"$binary\"]" "$LAUNCH_AGENT_PLIST"
  plutil -insert RunAtLoad -bool true "$LAUNCH_AGENT_PLIST"
  plutil -insert StandardOutPath -string "$LAUNCH_AGENT_STDOUT" "$LAUNCH_AGENT_PLIST"
  plutil -insert StandardErrorPath -string "$LAUNCH_AGENT_STDERR" "$LAUNCH_AGENT_PLIST"
  plutil -lint "$LAUNCH_AGENT_PLIST" >/dev/null
}

start_app() {
  local binary="$1"
  write_launch_agent "$binary"
  launchctl bootstrap "$USER_DOMAIN" "$LAUNCH_AGENT_PLIST"
  launchctl kickstart -k "$USER_DOMAIN/$LAUNCH_AGENT_LABEL"
}

verify_app() {
  sleep 8
  launchctl print "$USER_DOMAIN/$LAUNCH_AGENT_LABEL" | grep -q "state = running"
  pgrep -x "$APP_NAME" >/dev/null
}

case "$MODE" in
  run)
    stop_app
    build_app
    start_app "$(app_binary)"
    ;;
  --debug|debug)
    stop_app
    build_app
    lldb -- "$(app_binary)"
    ;;
  --logs|logs)
    stop_app
    build_app
    start_app "$(app_binary)"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    stop_app
    build_app
    start_app "$(app_binary)"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\" OR eventMessage CONTAINS[c] \"$PRODUCT_NAME\""
    ;;
  --verify|verify)
    stop_app
    build_app
    start_app "$(app_binary)"
    verify_app
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
