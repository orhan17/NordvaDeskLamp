#!/bin/bash
# Builds build/NordvaDeskLamp.app.
#   --install  also copies it to /Applications and launches it
#   --zip      builds a universal app (Apple Silicon + Intel) and packs build/NordvaDeskLamp.zip
set -euo pipefail
cd "$(dirname "$0")"

mode="${1:-}"
app=build/NordvaDeskLamp.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

if [[ "$mode" == "--zip" ]]; then
    slices=()
    for triple in arm64-apple-macosx13.0 x86_64-apple-macosx13.0; do
        swift build -c release --triple "$triple"
        slices+=("$(swift build -c release --triple "$triple" --show-bin-path)/NordvaDeskLamp")
    done
    lipo -create -output "$app/Contents/MacOS/NordvaDeskLamp" "${slices[@]}"
else
    swift build -c release
    cp "$(swift build -c release --show-bin-path)/NordvaDeskLamp" "$app/Contents/MacOS/"
fi
cp Resources/Info.plist "$app/Contents/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"

# An ad-hoc signature's requirement is its cdhash, so every rebuild would lose the Local
# Network and Keychain grants. Pinning the requirement to the bundle id keeps them.
codesign --force --sign - -r '=designated => identifier "io.github.orhan17.NordvaDeskLamp"' "$app"
echo "built: $app"

if [[ "$mode" == "--zip" ]]; then
    rm -f build/NordvaDeskLamp.zip
    ditto -c -k --keepParent "$app" build/NordvaDeskLamp.zip
    echo "packed: build/NordvaDeskLamp.zip"
fi

if [[ "$mode" == "--install" ]]; then
    osascript -e 'quit app "NordvaDeskLamp"' 2>/dev/null || true
    # `quit` returns immediately; opening the new copy before the old one exits fails with -600.
    for _ in {1..50}; do
        pgrep -xq NordvaDeskLamp || break
        sleep 0.1
    done
    pkill -x NordvaDeskLamp 2>/dev/null || true
    rm -rf /Applications/NordvaDeskLamp.app
    cp -R "$app" /Applications/
    open /Applications/NordvaDeskLamp.app
    echo "installed and launched: /Applications/NordvaDeskLamp.app"
fi
