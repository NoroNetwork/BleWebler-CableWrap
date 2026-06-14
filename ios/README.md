# BleWebler — iOS App

A native **SwiftUI + CoreBluetooth** iPhone/iPad app for the same BLE thermal
label printers as the web version (Marklife P12/P15, Pristar P15, L13). iOS
Safari does not support Web Bluetooth, so this app talks to the printer directly
via CoreBluetooth instead.

The Bluetooth packet protocol is a 1:1 port of the web app's verified
`marklife_p12.js` (see `Bluetooth/MarklifeProtocol.swift`).

## Features in this version

- **Connect** to supported printers over BLE (scan / connect / disconnect)
- **Text** labels (font size auto-fit, bold, alignment)
- **Cable Wrap** labels — **Flag** (text both ends, far end rotated 180°, wrap
  zone = π × diameter) and **Repeating** (text tiled along the label)
- **QR** codes (text / URL) via CoreImage
- Live preview, copies, continuous vs die-cut paper

### Not yet ported from the web app
- Image upload + dithering algorithms
- The richer QR types (Wi-Fi, vCard, calendar, …)
- Free-form drag/resize canvas (the iOS editor is form-driven)

These are good follow-ups; the architecture leaves room for them.

## Project layout

```
ios/
  project.yml                 # XcodeGen spec (source of truth for the project)
  BleWebler.xcodeproj         # generated — open this
  BleWebler/
    BleWeblerApp.swift        # @main entry
    Models/                   # SupportedPrinter, LabelDocument
    Bluetooth/                # PrinterManager (CoreBluetooth), MarklifeProtocol
    Rendering/                # LabelContentView, LabelRasterizer, QRGenerator
    Views/                    # ContentView, PrinterView, PaperSettingsView
    Assets.xcassets
    Info.plist                # generated from project.yml
```

## Build & run on your iPhone

1. **Install Xcode** from the Mac App Store (required — Command Line Tools alone
   are not enough). Then point the tools at it:
   ```
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```
2. **Open the project:** `ios/BleWebler.xcodeproj` (double-click).
3. **Set signing:** select the **BleWebler** target → **Signing & Capabilities**
   → check *Automatically manage signing* → choose your **Team** (your Apple
   Developer account). If the bundle ID `com.noronetwork.blewebler` is taken,
   change it to something unique.
4. **Plug in your iPhone**, select it as the run destination, press **▶ Run**.
5. On the iPhone, the first time: **Settings → General → VPN & Device Management**
   → trust your developer certificate.
6. Launch the app and **allow Bluetooth** when prompted.

> Tip: to keep your Team across project regenerations, add it to `project.yml`
> under `settings.base` as `DEVELOPMENT_TEAM: YOURTEAMID`.

## Regenerating the Xcode project

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):
```
brew install xcodegen
cd ios && xcodegen generate
```
Edit `project.yml` (not the `.xcodeproj`) for build-setting changes, then
regenerate. Source files are picked up automatically from the `BleWebler` folder.

## Shipping to the App Store

1. Replace the placeholder **AppIcon** in `Assets.xcassets/AppIcon.appiconset`
   with a real 1024×1024 icon (App Store requires it).
2. In Xcode: **Product → Archive**, then **Distribute App → App Store Connect**.
3. Create the app record at [App Store Connect](https://appstoreconnect.apple.com)
   (needs a paid Apple Developer Program membership, $99/yr).
4. Fill in metadata, screenshots, and Bluetooth usage description, then submit.

## Status / caveats

- **Not yet tested on physical hardware** from this codebase. The protocol is a
  faithful port of the working web implementation, but do a test print and
  confirm the cable flag fold lines up; tweak diameter/flag length as needed.
- Based on [BleWebler by josb25](https://github.com/josb25/BleWebler) (GPLv3).
