#!/bin/zsh
set -euo pipefail

APP_NAME="Roblox Account Manager"
ZIP_URL="https://roblox-cookie.com/api/download"

color() { printf "\033[%sm%s\033[0m\n" "$1" "$2"; }
info()  { color 36 "[info] $1"; }
ok()    { color 32 "[ok]   $1"; }
warn()  { color 33 "[warn] $1"; }
err()   { color 31 "[err]  $1"; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required tool not found: $1"
    exit 1
  fi
}

require curl
require unzip

DEST_DIR="$HOME/Applications"
APP_SUPPORT="$HOME/Library/Application Support/RobloxAccountManager"
TMP_DIR="${TMPDIR%/}/ram_installer_$$"
mkdir -p "$DEST_DIR" "$APP_SUPPORT" "$TMP_DIR"

cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT

info "Downloading latest build…"
ZIP_PATH="$TMP_DIR/app.zip"
HTTP_CODE=$(curl -w "%{http_code}" -LfsS "$ZIP_URL" -o "$ZIP_PATH") || true
if [[ "$HTTP_CODE" != "200" ]]; then
  err "Download failed (HTTP $HTTP_CODE)"
  exit 1
fi

info "Unpacking…"
unzip -q "$ZIP_PATH" -d "$TMP_DIR/unzipped"

APP_SRC=$(find "$TMP_DIR/unzipped" -maxdepth 2 -name "*.app" -print -quit || true)
if [[ -z "${APP_SRC}" ]]; then
  err "App bundle not found in archive"
  exit 1
fi

APP_NAME_ACTUAL="$(basename "$APP_SRC")"
TARGET_APP="$DEST_DIR/$APP_NAME_ACTUAL"

if [[ -e "$TARGET_APP" ]]; then
  warn "Existing installation found → replacing"
  rm -rf "$TARGET_APP"
fi

info "Installing to $DEST_DIR"
cp -R "$APP_SRC" "$DEST_DIR/"

info "Removing quarantine flag"
xattr -dr com.apple.quarantine "$TARGET_APP" || true

info "Creating first-run data folders"
mkdir -p "$APP_SUPPORT" "$APP_SUPPORT/Executors" "$APP_SUPPORT/RobloxInstances"

ok "Installed: $TARGET_APP"
echo
read "_resp?Launch now? [Y/n] "
if [[ -z "$_resp" || "$_resp" =~ ^[Yy]$ ]]; then
  open "$TARGET_APP"
  ok "Launched. Enjoy!"
else
  ok "You can launch it later from $DEST_DIR or Spotlight."
fi


