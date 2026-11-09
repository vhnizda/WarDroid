# WarcraftAI

Android port of the open source Stratagus engine and Wargus game layer. Both are GPL-2.0.

This repo contains no Blizzard data. Players supply `data.Wargus`, extracted from a copy they own.

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
| `D:\WarcraftAI-work\gradle-home` | Gradle caches |
| `D:\Android` | Android Studio and SDK |

## Android build

### One-time setup

1. Create the junction `D:\w`, which points at this folder. The real path is long enough to push SDL's header copy step past the Windows command line limit.

   ```powershell
   New-Item -ItemType Junction -Path D:\w -Target "C:\Users\Vaclav\Cloud-Drive\0. Game Essence\WarcraftAI"
   ```

2. Apply the patches. Repeat this after updating submodules.

   ```powershell
   git -C engine/stratagus/third-party apply "$PWD\android\patches\stratagus-third-party.patch"
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
$env:GRADLE_USER_HOME = 'D:\WarcraftAI-work\gradle-home'
D:\w\android\gradlew.bat -p D:\w\android --project-cache-dir D:/WarcraftAI-work/gradle-project-cache assembleDebug
```

The APK lands in `D:\WarcraftAI-work\build\gradle\app\outputs\apk\debug`. Paths are set in `android/gradle.properties`.

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

The app reads game data from `Android/data/com.vaclav.wargusport/files/data.Wargus` on the device. The app has no importer yet, so copy the folder with `adb push`.

## Upstream

The submodules point at the upstream repos. To fork, create the forks on GitHub, then add them as a remote in each submodule and update `.gitmodules`.
