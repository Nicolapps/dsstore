set shell := ["bash", "-euo", "pipefail", "-c"]

project := "DSStore.xcodeproj"
scheme := "DSStore"
bundle_id := "dev.ettlin.nicolas.dsstore"
derived_data := "build/DerivedData"
app := derived_data / "Build/Products/Debug-iphonesimulator/DSStore.app"

# This project needs Xcode 27.1, regardless of `xcode-select`; set XCODE_PATH if it lives elsewhere.
xcode := env_var_or_default("XCODE_PATH", "/Applications/Xcode 27.1.app")
export DEVELOPER_DIR := xcode / "Contents/Developer"

# Simulator to build for and run on; override with `just simulator="iPhone 18 Pro" run`.
simulator := "iPhone Duo"

# List available recipes.
default:
    @just --list

# Fetch submodules, patch them for the current Xcode, and generate the Xcode project.
bootstrap:
    Scripts/bootstrap.sh

# Regenerate the Xcode project from project.yml.
generate:
    xcodegen generate

# Open the project in Xcode, generating it first if needed.
open:
    [ -d {{ project }} ] || just bootstrap
    open -a '{{ xcode }}' {{ project }}

# Build the app for the simulator.
build: _project
    xcodebuild build \
        -project {{ project }} \
        -scheme {{ scheme }} \
        -configuration Debug \
        -destination "platform=iOS Simulator,id=$(just simulator='{{ simulator }}' _udid)" \
        -derivedDataPath {{ derived_data }} \
        | {{ if `command -v xcbeautify || true` != "" { "xcbeautify" } else { "cat" } }}

# Build, install and launch the app on the simulator, streaming its console output.
run: build boot
    xcrun simctl install "$(just simulator='{{ simulator }}' _udid)" {{ app }}
    xcrun simctl launch --console-pty --terminate-running-process "$(just simulator='{{ simulator }}' _udid)" {{ bundle_id }}

# Boot the simulator and bring Device Hub (which replaces Simulator.app in Xcode 27) to the front.
boot:
    xcrun simctl boot "$(just simulator='{{ simulator }}' _udid)" 2>/dev/null || true
    open -a '{{ xcode }}/Contents/Applications/DeviceHub.app'

# Build, install and launch the app on the simulator, then show it in Bitrig.
bitrig: build
    xcrun simctl boot "$(just simulator='{{ simulator }}' _udid)" 2>/dev/null || true
    xcrun simctl install "$(just simulator='{{ simulator }}' _udid)" {{ app }}
    xcrun simctl launch --terminate-running-process "$(just simulator='{{ simulator }}' _udid)" {{ bundle_id }}
    open -a Bitrig .

# Uninstall the app from the simulator (also clears its save data).
uninstall:
    xcrun simctl uninstall "$(just simulator='{{ simulator }}' _udid)" {{ bundle_id }}

# Symlink a game into ROM/ under its store id (e.g. `just rom kart path/to/game.zip`) so it gets bundled.
rom id path:
    #!/usr/bin/env bash
    set -euo pipefail
    src='{{ path }}'
    ext=$(echo "${src##*.}" | tr '[:upper:]' '[:lower:]')
    [[ "$ext" == nds || "$ext" == zip ]] || { echo "error: expected a .nds or .zip file" >&2; exit 1; }
    [ -f "$src" ] || { echo "error: $src does not exist" >&2; exit 1; }
    for existing in ROM/{{ id }}.nds ROM/{{ id }}.zip; do
        if [ -e "$existing" ] && [ ! -L "$existing" ]; then
            echo "error: $existing is a real file, not a symlink; move it away first" >&2
            exit 1
        fi
    done
    rm -f ROM/{{ id }}.nds ROM/{{ id }}.zip
    ln -s "$(cd "$(dirname "$src")" && pwd)/$(basename "$src")" "ROM/{{ id }}.$ext"
    ls -l "ROM/{{ id }}.$ext"

# Update the vendored cores to their latest upstream commits, then re-bootstrap.
update-vendor:
    git submodule update --remote --recursive
    just bootstrap

# Remove build products.
clean:
    rm -rf build

# Remove build products and the generated Xcode project.
clean-all: clean
    rm -rf {{ project }}

# List the available iPhone simulators.
simulators:
    xcrun simctl list devices available | grep -E 'iPhone|-- iOS'

_project:
    [ -d {{ project }} ] || just bootstrap

# Print the UDID of the simulator named `simulator`, preferring the newest iOS runtime.
# Resolving by UDID keeps every recipe on the same device when several share a name.
_udid:
    @xcrun simctl list devices available -j \
        | jq -er --arg name '{{ simulator }}' \
            '[.devices | to_entries | sort_by(.key) | reverse | .[].value[] | select(.name == $name)][0].udid // error("no available simulator named \($name)")'
