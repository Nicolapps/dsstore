#!/bin/sh
# Fetches dependencies, patches them for the current Xcode, and generates the Xcode project.
set -eu
cd "$(dirname "$0")/.."

git submodule update --init --recursive

# Xcode 27 no longer supports iOS 12 deployment targets, which ZIPFoundation still uses.
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 12.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/' \
    Vendor/DeltaCore/External/ZIPFoundation/ZIPFoundation.xcodeproj/project.pbxproj

# Games read the player's nickname from the firmware, which MelonDSDeltaCore sets to "Delta".
sed -i '' 's/Config::FirmwareUsername = "Delta";/Config::FirmwareUsername = "Nicolas";/' \
    Vendor/MelonDSDeltaCore/MelonDSDeltaCore/Bridge/MelonDSEmulatorBridge.mm

xcodegen generate
