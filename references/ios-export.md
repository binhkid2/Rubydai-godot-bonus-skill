# Exporting a Godot game to iPhone / iPad

Measured on Godot 4.7.2, Xcode 27, macOS on Apple Silicon. Run commands from the project folder.

**iOS builds need a Mac.** Signing and building go through Xcode, which only runs on macOS. On Windows or Linux, develop and test on the desktop and on Android (`android-export.md`), and do the iOS export on a Mac (your own, a borrowed one, a cloud Mac, or a macOS CI runner) with the same project.

---

## 1. Prerequisites

- Xcode, signed in with an Apple ID under **Xcode → Settings → Accounts** (a free account also has a personal team).
- Export templates for the exact Godot version: `~/Library/Application Support/Godot/export_templates/<version>/ios.zip`. If missing: **Editor → Manage Export Templates → Download**.
- Project Settings: `rendering/textures/vram_compression/import_etc2_astc=true` (iOS uses ETC2/ASTC).
- Recommended: `application/run/max_fps=60` (120 Hz screens heat the phone), `display/window/handheld/orientation`, an app icon (`application/config/icon`).

---

## 2. "No presets found"

When **Project → Export** says "No presets found", the project **has no `export_presets.cfg`**. It does not mean the templates are missing.

- Option 1: **Add… → iOS**, fill in **App Store Team ID** and **Bundle Identifier** (e.g. `com.<name>.<game>`); Godot writes `export_presets.cfg`.
- Option 2: copy `export_presets.cfg` from another iOS project that works, change `name`, `export_path`, `application/bundle_identifier`, `application/short_version`/`version`, and remove the `plugins/...` lines for plugins this project doesn't have.
- If the file was written while the editor was open: **Project → Reload Current Project** so the editor reads it again.
- Add `/build/` to `.gitignore`.

**The Team ID is not the code in parentheses in the certificate name.** In `Apple Development: Name (BR9J8U4PJX)`, `BR9J8U4PJX` identifies the certificate. The Team ID is in the `OU` field:

```sh
security find-identity -v -p codesigning                       # is there an "Apple Development" certificate?
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject   # ... OU=<TEAM_ID> ...
```

---

## 3. Export and install on a device

**In the editor:** plug in the iPhone (with **Settings → Privacy & Security → Developer Mode** on), then click the iOS icon at the top right to run directly on the device (one-click deploy), or use **Export Project** to produce an `.ipa`.

**From the command line** (to verify the build yourself before telling the user it works):

```sh
mkdir -p build
godot --headless --path . --export-debug "iOS" build/<Game>.ipa > build/export.log 2>&1
grep -E "ARCHIVE SUCCEEDED|EXPORT SUCCEEDED|error:" build/export.log

xcrun devicectl list devices                                   # get the UDID; check available/unavailable
xcrun devicectl device install app --device <UDID> build/<Game>.ipa
xcrun devicectl device process launch --device <UDID> --terminate-existing <bundle.id>
xcrun devicectl device info processes --device <UDID> | grep <Game>    # still running after a few seconds = no crash on launch
```

Godot calls `xcodebuild archive -allowProvisioningUpdates`, so Xcode creates a provisioning profile for a new bundle ID automatically (usually "iOS Team Provisioning Profile: *").

---

## 4. Common errors

| Error | Fix |
|---|---|
| `The device is not able to fulfill the requested usage assertion requirements` (CoreDeviceError 4016) | The device is locked, unplugged, or on another network: `devicectl list devices` shows `unavailable`. Unlock it, plug it back in, tap Trust. |
| The app installs but won't open, saying the developer isn't trusted | On the device: **Settings → General → VPN & Device Management**, trust the developer certificate. |
| The device doesn't show up in Godot/Xcode | Turn on Developer Mode (requires a restart), plug in the cable, trust the Mac. |
| You want to run on the iOS Simulator | Don't: test on a real device (see below the table). The official 4.7.2 template only ships an x86_64 Simulator library (even though `Info.plist` lists arm64 too; check with `lipo -archs`), and the iOS 27 Simulator on Apple Silicon doesn't run x86_64 apps. |
| Exported, but the new code isn't on the device | Export again and reinstall; the device has the build from the time of export. |
| `--export-release` (or the Export dialog with Export With Debug unchecked) fails with `ARCHIVE FAILED`: `<Game> has conflicting provisioning settings. <Game> is automatically signed for development, but a conflicting code signing identity Apple Distribution has been manually specified`. The Godot dialog only says `Failed to run xcodebuild with code 0` | With automatic signing (Provisioning Profile left empty) and **Code Sign Identity Release** left empty, Godot writes `Apple Distribution` into Xcode's Release configuration, and the archive step fails. Set `application/code_sign_identity_release="Apple Development"`. The archive is signed with the development certificate; when exporting for the App Store, Xcode (`-allowProvisioningUpdates`) re-signs it with the cloud-managed Apple Distribution certificate, even if the Mac has no Distribution certificate. Check the `.ipa`: `codesign -dvv Payload/*.app` must show `Authority=Apple Distribution` and the profile `iOS Team Store Provisioning Profile`. If the editor is open, change it in the dialog, because the editor overwrites `export_presets.cfg`. |
| Xcode: `While building for iOS Simulator, no library for this platform was found in .../<Plugin>.xcframework` | A Simulator destination is selected, but the plugin (AdMob, notifications, IAP…) only ships `ios-arm64`. Pick a real iPhone in Xcode's destination bar. |
| The project root fills up with `<Game>.xcodeproj`, `.xcframework` (hundreds of MB), `.pck`, `PrivacyInfo.xcprivacy` | The preset's `export_path` was changed to `./<Game>.xcodeproj`. Delete those files and set the path back to `build/...`. Godot would also import the icons in `Images.xcassets` and pack them into the `.pck`. |
| Icons inside `build/` get imported by Godot (`.import` files appear in `build/`) | `build/` is inside the project, so Godot scans it: add `build/.gdignore` and add `build/*` to the preset's `exclude_filter`. |
| An iOS-only GDExtension plugin prints `No GDExtension library found for current OS and architecture (macos.arm64)` on every Mac run | Harmless. Game code checks `ClassDB.class_exists("<Class>")` before using it, and finds the plugin's autoload with `get_node_or_null` so headless tools still run. |

**Don't try to run a Godot game on the iOS Simulator:** test the UI on the desktop (`testing.md` §5), and performance and plugins on a real device. What was tried (2026-10-22): a self-built arm64-simulator engine (`scons platform=ios target=template_debug simulator=yes arch=arm64`) runs, but the Simulator's OpenGL ES executes shaders on the CPU (`sample <pid>` shows `glvmInterpretFP…`), and Godot disables Metal/Vulkan in Simulator builds, so a 3D scene takes about 4 minutes for the first frame; forcing Metal makes Godot's Metal driver fail to initialize on the Simulator. The project owner considers it over-engineering.

**UI testing and App Store screenshots:** do them on the desktop, on any OS; see `testing.md` §5.

**Editing an app's save on the device** (e.g. removing a test purchase): the app must not be running (reinstalling also stops it), because the app saves when paused/closed.

```sh
xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier <bundle.id> --source Documents/save.json --destination save.json
# edit save.json, keep a backup
xcrun devicectl device copy to --device <UDID> --domain-type appDataContainer --domain-identifier <bundle.id> --source save.json --destination Documents/save.json
```

On iOS, `user://` is the app's `Documents/` folder. To read the app's `print()` output: `xcrun devicectl device process launch --console --terminate-existing --device <UDID> <bundle.id>` (run it in the background and stop it after a few dozen seconds).

### 4.1 The App Tracking Transparency (ATT) prompt with AdMob: ask on the first launch, but wait until the app is active

**Rejected by App Review:** a game with AdMob doesn't show the App Tracking Transparency dialog ("Allow … to track your activity…") on first launch. The reviewer only opens the app for a few minutes; if the game waits until some later point to ask (after the tutorial, at the first ad…), the reviewer never sees it and rejects the app for not finding the ATT request. The project owner was rejected for exactly this with another app (Capacitor).

**The second trap:** calling `requestTrackingAuthorization` too early, while the app isn't active yet (still launching, inside the first screen's `_ready()`), makes iOS **silently drop** the dialog: nothing appears and the status stays "not determined". That other app was rejected once more because of this, even though the code asked at launch.

**The right way:**
- Ask for ATT (and only then start the ads SDK) on the **first launch**, once the game has been on screen and in the foreground for about 1 second. *Offering* ads can still wait until after the tutorial; only the ATT question has to come early.
- Count "time in the foreground" in `_process` and reset it on `NOTIFICATION_APPLICATION_PAUSED` / `FOCUS_OUT`; ask only once the count is reached. On later launches iOS answers with the earlier choice and doesn't show the dialog again.
- The permission text `NSUserTrackingUsageDescription` must be in Info.plist (Godot's AdMob plugin adds it via `att_text` in its export settings). Without it, the app crashes when asking.
- The app's own privacy manifest (`PrivacyInfo.xcprivacy`): `NSPrivacyTracking = false` and **no** `NSPrivacyTrackingDomains` key. Setting `true` with no domains is rejected as ITMS-91064 "Invalid tracking information". Tracking through ads is declared under App Privacy in App Store Connect.

**Testing:** there's no ATT on the desktop; replace the plugin with a fake node that has `request_tracking_authorization()` / `initialize()`. Check: in the background it hasn't asked; right after opening it hasn't asked yet; after enough time in the foreground it asks. On a device: delete the app, reinstall, open it: the dialog must appear within the first few seconds, even over a welcome screen or tutorial.

---

## 5. Minimum on-device checklist

- [ ] The app opens without crashing; the first screen isn't covered by the notch / Dynamic Island / home bar.
- [ ] Apps with ads: delete the app, reinstall, open it for the first time: the ATT dialog appears within the first few seconds (§4.1).
- [ ] Every list swipes, even when the swipe starts on a button (`touch-input.md`).
- [ ] Tapping a button that opens a sheet: the sheet doesn't close itself; tapping the backdrop closes it.
- [ ] Buttons are big enough (about 44 pt or more); no mis-taps when swiping.
- [ ] Sound, music, the mute button; try flipping the silent switch.
- [ ] Swipe home and reopen: progress is kept. Force-quit and reopen: progress is kept.
- [ ] Play for 10–15 minutes: the phone doesn't get unusually hot (Xcode → Debug Navigator: CPU, GPU, Energy).
