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

# MelonDSDeltaCore caches the microphone converter across game starts, so if the input format changes
# (e.g. screen recording or a new audio route), connecting the new engine throws and crashes the app.
grep -q '_audioConverter = nil;' Vendor/MelonDSDeltaCore/MelonDSDeltaCore/Bridge/MelonDSEmulatorBridge.mm ||
    perl -0pi -e 's/(- \(void\)prepareAudioEngine\n\{\n    self\.audioEngine = \[\[AVAudioEngine alloc\] init\];\n)/$1\n    \/\/ Recreate the converter from the new engine\x27s input format, which may have changed since the last start.\n    _audioConverter = nil;\n\n/' \
        Vendor/MelonDSDeltaCore/MelonDSDeltaCore/Bridge/MelonDSEmulatorBridge.mm

xcodegen generate
