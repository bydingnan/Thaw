#!/bin/zsh
# Wraps the ThawExtraHelper executable into one .app per Apple menu extra.
# Usage: assemble-extra-helper.sh <executable> <output dir> <parent bundle id> <role> [signing identity]
set -euo pipefail
exe=$1 out=$2 parent=$3 role=$4 identity=${5:--}
case $role in
  focus) name="Foldy Focus" symbol=moon ;;
  timemachine) name="Foldy Time Machine" symbol=clock.arrow.trianglehead.counterclockwise.rotate.90 ;;
  timer) name="Foldy Timer" symbol=timer ;;
  airdrop) name="Foldy AirDrop" symbol=dot.radiowaves.left.and.right ;;
  nowplaying) name="Foldy Now Playing" symbol=play.circle ;;
  user) name="Foldy User Switcher" symbol=person.crop.circle ;;
  textinput) name="Foldy Text Input" symbol=keyboard ;;
  slot[1-6]) name="Foldy Stand-In ${role#slot}" symbol=square.dashed ;;
  *) echo "unknown role $role" >&2; exit 1 ;;
esac
app="$out/$name.app"
# Incremental builds retain renamed products unless their old bundle is removed.
legacy_app="$out/${name/Foldy/Thaw}.app"
if [[ -d "$legacy_app" ]]; then
  legacy_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$legacy_app/Contents/Info.plist" 2>/dev/null || true)
  if [[ $legacy_id == "$parent.extra.$role" ]]; then
    rm -rf "$legacy_app"
  fi
fi
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$exe" "$app/Contents/MacOS/ThawExtraHelper"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>ThawExtraHelper</string>
  <key>CFBundleIdentifier</key><string>$parent.extra.$role</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>LSUIElement</key><true/>
  <key>ThawExtraSymbol</key><string>$symbol</string>
</dict>
</plist>
PLIST
# Ad-hoc signatures cannot carry a secure timestamp; real ones need one to notarize.
timestamp=--timestamp
[[ $identity == - ]] && timestamp=--timestamp=none
codesign --force --sign "$identity" --options runtime $timestamp "$app"
echo "$app"
