# Hourbloom

*Grow the hours your city forgot, and play them.*

A stylized 3D game for Steam (PC) and Google Play. In the burnt-out city of Velmora, people's unlived
hours are stored as seeds. Plant one in Ira's rooftop greenhouse and it blooms into a playable world.
What its owner wished to do with that hour decides the genre. Graft two seeds and the genres fuse.

**Status: playable prototype (Milestone 1).** Greenhouse hub, three genre worlds (rhythm, racing,
puzzle), one graft (Racing × Rhythm), six citizen stories, achievements, save system.

Play the web build: https://claude.ai/artifact/G6LQZrKGJ42JaXBN2uqR9Q (private to the owner until shared).

## Controls

| Action | Touch / mouse | Keyboard | Gamepad |
| --- | --- | --- | --- |
| Plant a seed | Drag a card onto a pot (or tap card, then pot) | — | — |
| Rhythm lanes | Tap a quarter of the screen | D F J K / arrows | LB, X, B, RB / D-pad |
| Racing lanes | Tap left / right half, or swipe | ← → / A D | D-pad / left stick |
| Puzzle | Tap a tile to rotate it | Arrows + Space, H for hint | D-pad + A, Y for hint |
| Pause | II button | Esc / P | Start |
| FPS overlay | Settings | F3 | — |

## Project layout

```
core/        game state + saves, seeds (data), controls (input actions), audio, 3D stage, pools, platform (achievements)
screens/     title, greenhouse (3D hub), results, notebook, settings
genres/      genre base (fixed 60 Hz tick, pause, hit-stop) + rhythm, racing, puzzle
ui/          shared UI kit, seed cards, Sunday's speech bubble
assets/      3D models (.glb from Blender), symbol font
art/blender/ build_assets.py (makes every model) + editable .blend sources
tests/       automated play-through test (45 checks) + screenshot helper
.claude/skills/  game-development and game-engine skills used to design the game
```

## Build and test

Requires [Godot 4.5](https://godotengine.org/download) (free, MIT). Open `project.godot` in the editor and press Play.

```bash
# automated play-through (plants, grafts, plays all worlds, checks achievements and saves)
godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn

# rebuild all 3D models from code (Blender 4.x/5.x, or `pip install bpy`)
blender --background --python art/blender/build_assets.py

# exports (install export templates first: Editor > Manage Export Templates)
godot --headless --path . --export-release "Windows Desktop" build/windows/Hourbloom.exe
godot --headless --path . --export-release "Linux" build/linux/Hourbloom.x86_64
godot --headless --path . --export-release "Web" build/web/index.html
```

Sizes today: Windows 97 MB, Linux 70 MB (almost all engine), game content under 1 MB.

## Releasing on Google Play

1. Create a [Google Play Console](https://play.google.com/console) developer account (one-time USD 25 fee, identity verification).
2. In Godot: Editor Settings > Export > Android: set the Android SDK path and Java (JDK 17). Install the Android build template (Project > Install Android Build Template).
3. Create an upload keystore (`keytool -genkeypair -v -keystore upload.keystore -alias hourbloom -keyalg RSA -keysize 2048 -validity 10000`), and enter it in the Android export preset. **Never commit the keystore** (it is in `.gitignore`).
4. Export the **Android** preset (already set up: package `com.hourbloom.game`, arm64 + armv7, `.aab`).
5. In Play Console: create the app, fill in the store listing, content rating (target 12+), data-safety form (the game collects no personal data today), then upload the `.aab` to Internal testing first. New personal developer accounts must run a closed test with testers before production; check Play Console for the current requirement.

## Releasing on Steam

1. Join [Steamworks](https://partner.steamgames.com/) and pay the Steam Direct fee (USD 100 per game, recoupable).
2. Add the [GodotSteam](https://godotsteam.com/) extension (`addons/godotsteam`). `core/platform.gd` detects it automatically and unlocks Steam achievements with the ids in `Platform.ACHIEVEMENTS`. Create the same ids in the Steamworks achievement page.
3. Export the **Windows Desktop** (and optionally Linux) preset and upload the builds with SteamCMD / SteamPipe.
4. Store page, capsule art, trailer and "Coming soon" page at least 2 weeks before launch (Steam requirement).

## What is not in yet

Five more genres (combat, exploration, stealth, builder, co-op), 27 more grafts, the full 5-act story,
leagues and duels, the premium shop and Bloom Pass, cloud saves, localisation. See the design plan doc.

## Credits and licences

- Engine: Godot 4.5 (MIT). 3D models: generated with Blender (`art/blender/build_assets.py`).
- `assets/fonts/symbols.ttf`: subset of DejaVu Sans (see `assets/fonts/LICENSE-DejaVu.txt`).
- `.claude/skills/game-development`: from davila7/claude-code-templates (MIT, see its LICENSE).
- `.claude/skills/game-engine`: from github/awesome-copilot (MIT).
