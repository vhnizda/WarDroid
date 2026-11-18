# WarDroid

## Thanks

WarDroid stands on the work of the **[Wargus](https://wargus.github.io)** team ([source](https://github.com/Wargus/wargus)) and the **[Stratagus](https://github.com/Wargus/stratagus)** engine. Together they rebuilt Warcraft II: Tides of Darkness as open source. Thank you to everyone who has contributed to them over the years.

Like them, WarDroid is licensed under GPL-2.0. This repo contains no Blizzard game data; you need your own copy of Warcraft II.

## About

WarDroid is a port of Warcraft II to Android phones and tablets. It tries to reimagine the game as if it had been built for touch from the start. Most menus still use the original layout, stretched to fill a widescreen phone. So far the focus has been the battlefield: commanding units, building and moving around the map with your fingers.

An external mouse and keyboard still work as on PC.

**How it's made:** WarDroid is developed with heavy use of [Claude Code](https://claude.com/claude-code), Anthropic's AI coding assistant. I come up with the ideas, decide how the game should feel and test it on real phones. Claude Code does most of the heavy lifting: it writes the code, builds the app and tests each change on an Android emulator.

## All features developed so far

**Commanding units**
- **Smart taps:** tap a unit to select it. Tap the ground to move there, or tap an enemy to attack it.
- **Worker taps:** with workers selected, tap a gold mine or trees to start harvesting, or tap a damaged building to repair it.
- **Double-tap:** double-tap a unit to select all your units of that type within 10 tiles.
- **Selection box:** drag a finger across the map to draw a box and select every unit inside it. A slightly wobbly tap stays a tap.
- **Health and mana bars:** selected units show a health bar that turns from green to yellow, orange and red, and casters also show a blue mana bar.
- **Range circles:** hold a finger on a unit to see its attack and sight range.

**Moving around the map**
- **Shield joystick:** a wooden shield lets you move around the map with your left thumb while your right hand gives commands.
- **Second finger:** while you hold the joystick, tap with another finger to give orders.
- **Pinch zoom:** pinch with two fingers to zoom. The minimap's view box follows the zoom, and you can't zoom out past the map's width or height.
- **Joystick dead zone:** the area around the joystick ignores touches, so a thumb near it can't select or order anything by accident.

**Groups and workers**
- **Group buttons 1–4:** hold one to save your selection, units or a building; it turns blue. Tap it later to reselect that group and jump to it.
- **Idle worker button:** a yellow "!" button appears when peasants, peons or oil tankers stand idle. Tap it to jump to one, and keep tapping to cycle through them all.
- **X button:** a big X deselects. It first backs out of building placement, the build menu or picking a target.

**Building**
- **Hold to place:** hold your finger on the map and the building appears just above it, green where it fits and red where it doesn't. It's built where you let go.
- **Scrolling while placing:** drag to the edge of the screen to scroll, or use the joystick with your other thumb.
- **Drag to cancel:** drag the building onto the X to cancel it; the X lights up with a gold frame while you hold a building.

**Screen and menus**
- **Widescreen:** the whole game fills a widescreen phone with no black bars.
- **Bigger controls:** a double-height Menu button and larger resource numbers at the top.
- **Back button:** your phone's Back button opens the game menu, and backs out of menus.
- **Loading a save:** the view centres on your base, not the map's corner.

**Multiplayer**
- **LAN games:** phones on the same Wi-Fi find each other's games with "Search LAN".

## Build and install it yourself

### The easy way: let Claude Code do it

If you have [Claude Code](https://claude.com/claude-code) on your PC, you can skip the steps below. Open Claude Code in an empty folder and ask it something like:

> Build WarDroid from https://github.com/vhnizda/WarDroid and install it on my Android phone, following its README. My Warcraft II files are in C:\GOG Games\Warcraft II.

Claude Code will install the tools, build the game, extract the game data and put it all on your phone. A few things are still up to you:

- **Your own game files:** you need your own copy of Warcraft II, because Claude can't provide them.
- **USB debugging:** turn it on and plug in your phone, as in step 5 below, then accept the prompt that appears on the phone.
- **Approvals:** Claude Code asks before it downloads or installs anything, so expect to approve a few steps.

### The manual way

You'll need a Windows 10 or 11 PC, a USB cable, and your own copy of Warcraft II (the Battle.net Edition from GOG works). Your phone needs Android 6.0 or newer. Android Studio is not needed.

#### 1. Install the tools (one time)

- **[Git](https://git-scm.com/download/win).**
- **A Java JDK, version 17 or newer:** for example [Eclipse Temurin](https://adoptium.net).
- **[Android command-line tools](https://developer.android.com/studio#command-line-tools-only):** unzip them to `C:\Android\cmdline-tools\latest`, then run:
  ```
  C:\Android\cmdline-tools\latest\bin\sdkmanager.bat --sdk_root=C:\Android "platform-tools" "platforms;android-37" "ndk;28.2.13676358" "cmake;3.31.6"
  ```
- **[Visual Studio Build Tools 2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022):** tick **Desktop development with C++**. This builds two small PC helpers: one used during the build, and the tool that extracts the game data.

#### 2. Get the code

```
git clone --recursive https://github.com/vhnizda/WarDroid.git C:\WarDroid
cd C:\WarDroid
git -C engine/stratagus apply ..\..\android\patches\stratagus.patch
git -C engine/stratagus/third-party apply ..\..\..\android\patches\stratagus-third-party.patch
git -C game/wargus apply ..\..\android\patches\wargus.patch
```

Keep the folder path short, like `C:\WarDroid`. Long paths break part of the Android build.

#### 3. Build the helper and the app

```
cmake -S engine/stratagus/third-party/lua-5.1.5 -B build/host-tolua -G "Visual Studio 17 2022" -A x64
cmake --build build/host-tolua --config Release --target toluapp
```

Open `android\gradle.properties` and point the three paths at your folder:
```
warcraftai.workDir=C:/WarDroid
warcraftai.engineDir=C:/WarDroid/engine/stratagus
warcraftai.hostToluapp=C:/WarDroid/build/host-tolua/Release/toluapp.exe
```

Then build. The first build takes a while.
```
set ANDROID_HOME=C:\Android
android\gradlew.bat -p android assembleDebug
```

The app lands in `build\gradle\app\outputs\apk\debug\app-debug.apk`.

#### 4. Extract the game data

Build the extractor:
```
cmake -S game/wargus -B build/host-wargus -G "Visual Studio 17 2022" -A x64 -DENABLE_VENDORED_LIBS=ON -DSTRATAGUS=engine/stratagus/none.exe -DSTRATAGUS_INCLUDE_DIR=engine/stratagus/gameheaders
cmake --build build/host-wargus --config Release --target bzip2
cmake --build build/host-wargus --config Release --target wartool
```

1. Make an empty folder `C:\WarDroid\data.Wargus`, and copy these folders from `game\wargus` into it: `campaigns`, `maps`, `shaders`, `scripts`, and `contrib` (copied as `graphics\ui`).
2. Run the extractor, replacing the first path with your Warcraft II folder:
   ```
   build\host-wargus\Release\wartool.exe "C:\GOG Games\Warcraft II" C:\WarDroid\data.Wargus
   ```
3. Copy `contrib\red_cross.png` to `data.Wargus\graphics\missiles`, and `contrib\cross.png` to `data.Wargus\graphics\ui\cursors`.

#### 5. Install on your phone

1. On the phone, turn on **Developer options** (tap **Build number** 7 times in **Settings → About phone**), then turn on **USB debugging**.
2. Plug in the phone, accept the prompt on it, and run:
   ```
   set PATH=%PATH%;C:\Android\platform-tools
   adb install build\gradle\app\outputs\apk\debug\app-debug.apk
   adb push C:\WarDroid\data.Wargus /sdcard/Android/data/com.vaclav.wargusport/files/
   ```
3. Open **WarDroid** on your phone.

**Optional:** the original music is MIDI. For better-sounding music, see [docs/music.md](docs/music.md). More technical notes are in [docs/developer-notes.md](docs/developer-notes.md).
