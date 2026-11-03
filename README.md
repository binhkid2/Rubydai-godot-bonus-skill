# Rubydai Godot bonus skill

A [Claude Code](https://claude.com/claude-code) skill for Godot 4 games that ship to phones. It collects the "works in the editor, breaks on the device" lessons, and Claude applies them automatically whenever it works in a Godot project, without being asked.

Works on macOS, Windows and Linux. iOS export needs a Mac, because Xcode only runs there.

The skill installs as `rubydai-godot-bonus-skill`.

## Contents

| File | What's in it |
|---|---|
| `SKILL.md` | What Claude reads: when to use the skill, the always-on rules, and which reference to open when |
| `references/touch-input.md` | How a phone delivers touches to Godot (an emulated click first, then the touch; the default `mouse_filter` of each control). Three bugs that only show on a device: lists that won't swipe, a sheet that closes right after opening, a swipe that ends in a mis-tap. Fixes, rotate/zoom/double-tap gestures, and testing with simulated touch |
| `references/silent-bugs-checklist.md` | Godot 4 silent bugs: scripts/classes, Controls built in code (anchors/offsets, `reset_size`, autowrapping labels, data-driven text pushing a panel off screen, overlapping hand-drawn text), tweens/timers/coroutines (freed nodes, hanging `await`s), mobile 3D (sRGB colors, tonemapping, cameras, glow, heat), assets (GLB, SVG, WAV, path case, line endings), platform and saving |
| `references/android-export.md` | Exporting to Android: JDK/SDK setup, the export preset, installing/launching with `adb`, reading `logcat`, release keystores and AABs for the Play Store, common errors, an on-device checklist |
| `references/ios-export.md` | Exporting to iPhone/iPad (on a Mac): "No presets found", finding the right Team ID, exporting and installing/launching from the command line (`devicectl`), common errors, the ATT prompt for App Review, an on-device checklist |
| `references/testing.md` | Running Godot from a terminal on each OS, then the order of checks: scripts load, headless validators, logic fuzzing, worst-case UI data, `--selftest` through the main scene, screenshots, playing all content through the UI, performance, testing on a device |
| `templates/touch_scroll.gd` | A ScrollContainer that swipes even when the finger lands on a button, with inertia and no mis-taps after a swipe |
| `templates/check_touch.gd` | Simulated tap/drag helpers (`tap`, `drag`, canvas → window coordinates) with example tests |
| `templates/check_extremes.gd` | Worst-case data tests: longest names, everything out at once, huge numbers, at every screen size. Checks that panels stay on screen, HUD text stays inside its card and doesn't overlap, and no `nan`/`inf`/overflowed numbers appear |
| `templates/fuzz_logic.gd` | A seeded random player with invariants checked after every step (finite money, stock within limits, save → load gives the same data...) |
| `templates/store_shots.gd` | App Store screenshots taken on the desktop at iPhone 6.9" / iPad 13" sizes with a simulated notch and home bar |
| `setup.command`, `setup.sh` | Installer for macOS (double-click `setup.command`) and Linux (`bash setup.sh`) |
| `setup.bat`, `setup.ps1` | Installer for Windows (double-click `setup.bat`) |

The guides in `references/` stand on their own and are useful without Claude. The iOS parts were measured on Godot 4.7.2, Xcode 27, macOS on Apple Silicon.

## Install

User-level skills live in `~/.claude/skills/<skill-name>/` (on Windows, `%USERPROFILE%\.claude\skills\<skill-name>\`) and apply to every project.

### With the installer (no commands to type)

1. On the repo page on GitHub, choose **Code → Download ZIP** and unzip it.
2. Run the installer for your OS:
   - **macOS:** right-click `setup.command` → **Open**. The first time, macOS blocks files downloaded from the internet, so use right-click rather than a double-click.
   - **Windows:** double-click `setup.bat`. If SmartScreen says "Windows protected your PC", click **More info → Run anyway**.
   - **Linux:** run `bash setup.sh` in a terminal from the unzipped folder.

The installer:
- checks for git. On macOS it opens the Command Line Tools installer; on Windows it installs Git with `winget`; on Linux it prints the install command for your package manager. Run the installer again once git is there.
- clones the skill into `Desktop/Godot game projects/rubydai-godot-bonus-skill`, or pulls if it's already there;
- links it into the skills folder. On Windows it uses a directory junction, which needs no admin rights;
- adds the "always use this skill" line to `~/.claude/CLAUDE.md` if it's not there yet.

It's safe to run again at any time; anything already in place is skipped. The list of skills and the clone folder are at the top of `setup.sh` and `setup.ps1`.

### By hand

Clone straight into the skills folder (macOS/Linux):

```sh
mkdir -p ~/.claude/skills
git clone https://github.com/rubydai-dev/Rubydai-godot-bonus-skill.git ~/.claude/skills/rubydai-godot-bonus-skill
```

On Windows (PowerShell):

```powershell
git clone https://github.com/rubydai-dev/Rubydai-godot-bonus-skill.git "$env:USERPROFILE\.claude\skills\rubydai-godot-bonus-skill"
```

Update later with `git -C <that folder> pull`.

If you'd rather keep the clone in your own projects folder and edit it there, clone it anywhere and link it into the skills folder: `ln -s "<clone>" ~/.claude/skills/rubydai-godot-bonus-skill` on macOS/Linux, or `New-Item -ItemType Junction -Path "$env:USERPROFILE\.claude\skills\rubydai-godot-bonus-skill" -Target "<clone>"` on Windows.

Start a new Claude Code session, type `/`, and check that `rubydai-godot-bonus-skill` is in the list of skills.

### Making Claude always use the skill in Godot projects

Claude uses the skill on its own when the task matches the `description` in `SKILL.md`, but not reliably every time. To make sure, add this line to `~/.claude/CLAUDE.md` (the installer does it for you):

```md
- In every Godot project (one with a project.godot file), always use the `rubydai-godot-bonus-skill` skill.
```

## Updating the content

- Edit the files in this repo directly, then commit and push.
- Whenever you hit a bug that only shows on a real device, add the symptom, the cause, the fix and the test that catches it to the matching reference.
- Keep it **generic**: no class names, paths or features specific to one game.
- Write everything in English.
- The `description` in `SKILL.md` decides when Claude uses the skill. Keep it under 1024 characters and list the situations it covers explicitly.
- The skill's folder name and the `name` in `SKILL.md` must stay `rubydai-godot-bonus-skill`: lowercase letters, digits and hyphens only.
