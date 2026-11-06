# WarcraftAI

Android port of the open source Stratagus engine and Wargus game layer. Both are GPL-2.0.

This repo contains no Blizzard data. Players supply `data.Wargus`, extracted from a copy they own.

## Layout

| Path | Contents |
|---|---|
| `engine/stratagus` | Stratagus submodule |
| `game/wargus` | Wargus submodule |
| `android/cmake/ndk-toolchain.cmake` | NDK toolchain wrapper, see below |
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

Build through the junction `D:\w`, which points at this folder. The real path is long enough to push SDL's header copy step past the Windows command line limit.

```powershell
New-Item -ItemType Junction -Path D:\w -Target "C:\Users\Vaclav\Cloud-Drive\0. Game Essence\WarcraftAI"
```

Apply the patches once after cloning or updating submodules:

```powershell
git -C engine/stratagus/third-party apply "$PWD\android\patches\stratagus-third-party.patch"
```

| Setting | Value |
|---|---|
| NDK | 28.2.13676358 |
| CMake | 3.31.6 from the SDK |
| Minimum Android | API 23 |
| Environment | `ANDROID_NDK_ROOT`, plus `WARCRAFTAI_ABI` set to `arm64-v8a` or `armeabi-v7a` |
| CMake options | `-DCMAKE_TOOLCHAIN_FILE=D:/w/android/cmake/ndk-toolchain.cmake -DBUILD_VENDORED_LUA=ON -DBUILD_VENDORED_SDL=ON -DBUILD_VENDORED_MEDIA_LIBS=ON -DWITH_STACKTRACE=OFF -DWITH_OPENMP=OFF -DBUILD_TESTING=OFF` |

The engine generates `tolua.cpp` at build time, so a real build also needs `-DSTRATAGUS_HOST_TOLUAPP=<path>`, a tolua++ program built for Windows.

## Upstream

The submodules point at the upstream repos. To fork, create the forks on GitHub, then add them as a remote in each submodule and update `.gitmodules`.
