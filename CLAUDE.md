# DSStore

- Only use the Xcode 27.1 beta (`/Applications/Xcode 27.1.app`), never the default `xcode-select` Xcode. The Justfile exports `DEVELOPER_DIR` for this; when running `xcodebuild`/`xcrun` outside of `just`, prefix them with `DEVELOPER_DIR="/Applications/Xcode 27.1.app/Contents/Developer"`.
- Default to the iPhone Duo simulator for building, running and screenshots.
- When launching the app yourself to test something, launch it muted: `SIMCTL_CHILD_DSSTORE_MUTE=1 xcrun simctl launch …`. Shut down any extra simulators you booted once you're done with them.
