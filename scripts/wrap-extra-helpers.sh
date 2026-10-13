#!/bin/zsh
# Xcode build phase: wraps the embedded ThawExtraHelper executable into one
# .app per Apple menu extra and per third-party stand-in slot, then removes the
# bare copy. Each bundle needs its own identifier, because macOS 27 conceals
# status items per bundle.
set -euo pipefail
# Xcode does not remove embedded frameworks when an incremental build drops a dependency.
updater="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Frameworks/Sparkle.framework"
if [[ -d "$updater" ]]; then
    updater_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$updater/Resources/Info.plist" 2>/dev/null || true)
    if [[ $updater_id == org.sparkle-project.Sparkle ]]; then
        rm -rf "$updater"
    fi
fi
extras="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Library/Extras"
exe="$extras/ThawExtraHelper"
[[ -f $exe ]] || { echo "warning: wrap-extra-helpers: $exe not found"; exit 0; }
identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
for role in focus timemachine timer airdrop nowplaying user textinput slot1 slot2 slot3 slot4 slot5 slot6; do
    "${SRCROOT}/scripts/assemble-extra-helper.sh" "$exe" "$extras" "${PRODUCT_BUNDLE_IDENTIFIER}" "$role" "$identity"
done
rm -f "$exe"
