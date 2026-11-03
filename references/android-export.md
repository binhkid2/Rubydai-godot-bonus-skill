# Exporting a Godot game to Android

Works the same on macOS, Windows and Linux. Run commands from the project folder; `godot` means the Godot binary for your OS (`testing.md` §0). This guide is less battle-tested than `ios-export.md`: when a step doesn't match your Godot version, trust the official "Exporting for Android" docs and update this file.

---

## 1. Prerequisites

- **Export templates** for the exact Godot version: **Editor → Manage Export Templates → Download**.
- **JDK 17** (OpenJDK, e.g. Eclipse Temurin) and the **Android SDK** (Android Studio, or the command-line tools with `platform-tools`, `build-tools` and a `platforms;android-<api>` package).
- **Editor Settings → Export → Android:** set **Java SDK Path** and **Android SDK Path**. Godot uses them to sign the APK and to find `adb`.
- **Debug keystore:** Godot creates or uses one from Editor Settings (**Debug Keystore**); if the export complains about it, generate one with `keytool` (§4) and point the setting at it.
- **Project Settings:** `rendering/textures/vram_compression/import_etc2_astc=true` (Android uses ETC2/ASTC); `application/run/max_fps=60` (90/120 Hz phones heat up); `display/window/handheld/orientation`.
- **The phone:** **Settings → About phone**, tap **Build number** seven times to unlock **Developer options**, then turn on **USB debugging**. Plug it in and accept the "Allow USB debugging?" prompt on the phone. On Windows, some brands need their OEM USB driver before `adb` sees the phone.

---

## 2. Export preset

**Project → Export → Add… → Android**, then set at least:
- `package/unique_name` (e.g. `com.<name>.<game>`): the app's identity on the Play Store; never change it after release.
- `version/code` (an integer that must go up on every Play Store upload) and `version/name`.
- **Permissions** the game needs, e.g. `INTERNET` and `ACCESS_NETWORK_STATE` for ads/online features, `VIBRATE` for `Input.vibrate_handheld()`.
- **Use Gradle Build** only when a plugin needs it or you need an AAB (§4); it requires **Project → Install Android Build Template** and adds an `android/` folder to the project.

Add `/build/` to `.gitignore`, and `build/.gdignore` so Godot doesn't import what you export.

---

## 3. Export, install, launch, read the log

**In the editor:** with the phone plugged in, the Android icon at the top right runs the game on the device (one-click deploy).

**From the command line** (to verify the build yourself before telling the user it works):

```sh
mkdir -p build
godot --headless --path . --export-debug "Android" build/<game>.apk > build/export.log 2>&1

adb devices                                   # the phone must show as "device", not "unauthorized"
adb install -r build/<game>.apk               # -r keeps the app's data
adb shell monkey -p <package> -c android.intent.category.LAUNCHER 1    # launch it
adb shell pidof <package>                     # prints a PID a few seconds later = no crash on launch
adb logcat -s godot                           # the game's print() output and errors
```

`adb` lives in `<Android SDK>/platform-tools/`; add that folder to `PATH` (on Windows: `adb.exe`, the same commands work in PowerShell).

**The app's save files:** `user://` is the app's private data folder. For a debug build: `adb shell run-as <package> ls files` and `adb exec-out run-as <package> cat files/save.json > save.json`. Release builds don't allow `run-as`.

---

## 4. Release builds and the Play Store

- Create an upload keystore once and **back it up**; keep it and its passwords out of git:
  ```sh
  keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
  ```
- Put it in the preset's **Keystore → Release** fields, or set the environment variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` so passwords never land in `export_presets.cfg`.
- The Play Store wants an **AAB**, not an APK: turn on **Use Gradle Build** and set the export format to AAB, then `godot --headless --path . --export-release "Android" build/<game>.aab`.
- Enroll in **Play App Signing**: Google keeps the real signing key, and a lost upload key can be reset instead of losing the app.
- Bump `version/code` before every upload; the Play Console rejects a code it has seen.

---

## 5. Common errors

| Error | Fix |
|---|---|
| `adb devices` shows `unauthorized` | Unlock the phone and accept the "Allow USB debugging?" prompt; if it never appears, revoke USB debugging authorizations in Developer options and replug. |
| `adb devices` shows nothing | A charge-only cable, USB debugging off, or (Windows) a missing OEM driver. Try another cable and port. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | The installed app was signed with a different key (e.g. a release build over a debug build, or another machine's debug keystore). `adb uninstall <package>`, then install again; this deletes the app's data. |
| The export fails on keystore, Java or SDK paths | Recheck **Editor Settings → Export → Android**; the paths must point at JDK 17 and the SDK root. |
| The game runs but textures are missing or the export warns about ETC2/ASTC | Turn on `import_etc2_astc`, reimport, export again. |
| The Back button quits the game | `application/config/quit_on_go_back=false` and handle `NOTIFICATION_WM_GO_BACK_REQUEST` (`silent-bugs-checklist.md` §5). |
| UI hidden behind a camera cutout or the navigation bar | Use `DisplayServer.get_display_safe_area()` as on iOS (`silent-bugs-checklist.md` §1.7) and test a phone with a cutout. |

---

## 6. Minimum on-device checklist

- [ ] The app opens without crashing; nothing is hidden behind the camera cutout, status bar or navigation bar.
- [ ] Every list swipes, even when the swipe starts on a button (`touch-input.md`).
- [ ] Tapping a button that opens a sheet: the sheet doesn't close itself; tapping the backdrop closes it.
- [ ] The Back button does what the game expects (closes a sheet, goes back a screen) instead of quitting.
- [ ] Text fields: the on-screen keyboard doesn't cover the field and can be dismissed (`touch-input.md` §2.4).
- [ ] Sound, music, the mute button; pressing Home and returning resumes cleanly.
- [ ] Swipe the app away from recents and reopen: progress is kept.
- [ ] Play for 10–15 minutes: the phone doesn't get unusually hot; check `adb logcat -s godot` for errors.
