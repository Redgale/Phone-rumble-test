# Rumble Test

A native SwiftUI iPhone app for testing the phone's haptic motor.

## Features

- Five selectable haptic intensity levels
- One-shot vibration test
- Press-and-hold continuous haptic test
- Core Haptics continuous feedback where supported
- UIKit impact-feedback fallback on devices without Core Haptics support
- Dark interface with a red accent

## Build

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project RumbleTest.xcodeproj -scheme RumbleTest -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build
```

## Download an unsigned IPA

Every push to `main` that changes the app or workflow, and every manual workflow dispatch, runs the **Build unsigned iOS IPA** workflow.

1. Open the repository's **Actions** tab.
2. Select **Build unsigned iOS IPA**.
3. Open the completed run.
4. Download the `RumbleTest-unsigned-IPA` artifact.
5. Extract the artifact ZIP to get `RumbleTest-unsigned.ipa`.

The IPA is deliberately unsigned. It is intended for a compatible sideloading workflow such as LiveContainer; installation compatibility depends on the iOS version, device, and signing/install method.

## Haptics notes

Core Haptics is used for adjustable transient and continuous haptic events. If the device does not support Core Haptics, the app falls back to UIKit impact feedback. UIKit does not provide true continuous vibration, so the hold fallback sends repeated impacts instead.

Haptics may be unavailable when the device is in certain system states or when haptics are disabled by iOS settings.
