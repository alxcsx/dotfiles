#!/usr/bin/env bash
# name:		emacs-client.install.sh
# desc:		Build/install the Emacs Client app and enable the Emacs server daemon.
# author:	Alex Candido <github:alxcsx>
#
# Invoked by macos/install.sh, so it is self-contained (no dotfiles helpers).

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="/Applications/Emacs Client.app"
AGENT="$HOME/Library/LaunchAgents/org.gnu.Emacs.plist"

EMACSCLIENT="$(command -v emacsclient || true)"
EMACS="$(command -v emacs || true)"

if [[ -z "$EMACSCLIENT" || -z "$EMACS" ]]; then
	echo "emacs/emacsclient not found, skipping Emacs Client app install" >&2
	exit 0
fi

# Build the droplet from source. The AppleScript is a thin emacsclient
# front-end; the Info.plist registers the text/org-protocol types.
rm -rf "$APP"
osacompile -o "$APP" "$DIR/main.applescript"
cp "$DIR/Info.plist" "$APP/Contents/Info.plist"

# Use the icon of the installed Emacs app instead of osacompile's default applet icon.
EMACS_APP="$(dirname "$(dirname "$(readlink -f "$EMACS")")")/Emacs.app"
ICON_SRC=""
for candidate in "$EMACS_APP" /opt/homebrew/opt/emacs-plus/Emacs.app /usr/local/opt/emacs-plus/Emacs.app; do
	if [[ -f "$candidate/Contents/Resources/Emacs.icns" ]]; then
		ICON_SRC="$candidate/Contents/Resources/Emacs.icns"
		break
	fi
done
if [[ -n "$ICON_SRC" ]]; then
	cp "$ICON_SRC" "$APP/Contents/Resources/Emacs.icns"
	plutil -replace CFBundleIconFile -string Emacs "$APP/Contents/Info.plist"
else
	# Fall back to whatever icon osacompile generated.
	ICON="$(basename "$(ls "$APP/Contents/Resources/"*.icns | head -n1)" .icns)"
	plutil -replace CFBundleIconFile -string "$ICON" "$APP/Contents/Info.plist"
fi
codesign --force --deep -s - "$APP"

# Server daemon. RunAtLoad starts it at login so the client app always has a
# server to talk to; the app also starts one on demand if it is not running.
mkdir -p "$(dirname "$AGENT")"
sed "s|@EMACS@|$EMACS|" "$DIR/org.gnu.Emacs.plist" >"$AGENT"
launchctl bootout "gui/$(id -u)/org.gnu.Emacs" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null || true
