# Developer notes

Notes from the main development setup, where the project folder is cloud-synced and everything heavy lives on D:. The README has the plain build guide.

## Layout

| Path | Contents |
|---|---|
| `engine/stratagus` | Stratagus submodule |
| `game/wargus` | Wargus submodule |
| `android` | Gradle project for the Android app |
| `android/app/src/main/cpp` | Native build that wraps the engine into `libmain.so` |
| `android/patches` | Changes to upstream code needed for Android |

Because this folder is synced by IDrive, everything heavy lives on D: instead:

| Path | Contents |
|---|---|
| `D:\WarcraftAI-work\git` | Git history, including submodules |
| `D:\WarcraftAI-work\build` | Build output |
| `D:\WarcraftAI-work\data` | Extracted game data, never committed |
| `D:\Android` | Android Studio, SDK, and `gradle-home` (Gradle caches shared by all Android projects) |

## Android build

### One-time setup

1. Create the junction `D:\w`, which points at this folder. The real path is long enough to push SDL's header copy step past the Windows command line limit.

   ```powershell
   New-Item -ItemType Junction -Path D:\w -Target "C:\Users\Vaclav\Cloud-Drive\0. Game Essence\WarcraftAI"
   ```

2. Apply the patches. Repeat this after updating submodules.

   ```powershell
   git -C engine/stratagus apply "$PWD\android\patches\stratagus.patch"
   git -C engine/stratagus/third-party apply "$PWD\android\patches\stratagus-third-party.patch"
   git -C game/wargus apply "$PWD\android\patches\wargus.patch"
   ```

3. Build the Windows tolua++, which generates the engine's Lua bindings during the Android build. This needs Visual Studio Build Tools 2022 with the C++ workload.

   ```powershell
   cmake -S D:/w/engine/stratagus/third-party/lua-5.1.5 -B D:/WarcraftAI-work/build/host-tolua -G "Visual Studio 17 2022" -A x64
   cmake --build D:/WarcraftAI-work/build/host-tolua --config Release --target toluapp
   ```

### Building the APK

```powershell
$env:JAVA_HOME = 'D:\Android\AndroidStudio\jbr'
$env:ANDROID_HOME = 'D:\Android\Sdk'
$env:GRADLE_USER_HOME = 'D:\Android\gradle-home'
D:\w\android\gradlew.bat -p D:\w\android --project-cache-dir D:/WarcraftAI-work/gradle-project-cache assembleDebug
```

The APK lands in `D:\WarcraftAI-work\build\gradle\app\outputs\apk\debug`. Paths are set in `android/gradle.properties`.

### Offline APK (game data included)

For a phone with no computer or internet, add `-Pwarcraftai.bundleData=D:/WarcraftAI-work/data.Wargus` to the build command. The data is zipped into the APK, without the original `install.exe`. On the first launch after each install or update, `SetupActivity` unpacks it into the game's data folder with a progress bar, then starts the game. A normal build has no data and goes straight to the game.

The result is about 375 MB and contains Blizzard's files. Keep it in `D:\WarcraftAI-work\offline`, never in `dist` or anywhere else in this synced, public repo. The next normal build removes the data again.

| Setting | Value |
|---|---|
| ABIs | `armeabi-v7a`, `arm64-v8a` |
| Minimum Android | 6.0 (API 23) |
| Target API | 33, because SDL 2.0.22 breaks on Android 14 rules at 34 and above |
| NDK | 28.2.13676358 |
| CMake | 3.31.6 from the SDK |
| Gradle and AGP | 9.9.0 and 9.5.1 |

### Game data

Build the extractor once. Building `bzip2` first is needed because Wargus doesn't make `wartool` wait for it.

```powershell
cmake -S D:/w/game/wargus -B D:/WarcraftAI-work/build/host-wargus -G "Visual Studio 17 2022" -A x64 -DENABLE_VENDORED_LIBS=ON -DSTRATAGUS=D:/w/engine/stratagus/none.exe -DSTRATAGUS_INCLUDE_DIR=D:/w/engine/stratagus/gameheaders
cmake --build D:/WarcraftAI-work/build/host-wargus --config Release --target bzip2
cmake --build D:/WarcraftAI-work/build/host-wargus --config Release --target wartool
```

To build `data.Wargus`, follow the order Wargus's own launcher uses:

1. Copy these folders from `game/wargus` into an empty `D:\WarcraftAI-work\data.Wargus`: `campaigns`, `contrib` (into `graphics/ui`), `maps`, `shaders` and `scripts`.
2. Run the extractor over it, so extracted files replace any copied ones with the same name. `D:\WarcraftAI-work\data` holds the CD copy.

   ```powershell
   D:\WarcraftAI-work\build\host-wargus\Release\wartool.exe D:\WarcraftAI-work\data D:\WarcraftAI-work\data.Wargus
   ```

3. Copy `contrib/red_cross.png` to `graphics/missiles` and `contrib/cross.png` to `graphics/ui/cursors`, matching Wargus's install layout.


### LAN multiplayer

Both devices need the same APK and the same `data.Wargus`, since the join menu lives in `scripts/menus/network.lua`.

The host creates a game as usual. While its game menu is open it answers search probes on UDP port 6661, and the game itself runs on UDP 6660. A joiner opens Join Game and taps **Search LAN**, which probes every address in its Wi-Fi subnet. If exactly one host answers, it joins straight away. If several answer, they appear in the server list to pick from. The engine's own mDNS discovery still runs too, for networks that pass multicast.

Some routers, especially guest networks, stop devices talking to each other, and then nothing is found. An emulator behind NAT, such as MuMu in its default network mode, can join a phone's game but can't be found by one.

## Upstream

The submodules point at the upstream Wargus and Stratagus repos, which WarDroid is built from. To fork, create the forks on GitHub, then add them as a remote in each submodule and update `.gitmodules`.

