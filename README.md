# WarcraftAI

Android port of the open source Stratagus engine and Wargus game layer. Both are GPL-2.0.

This repo contains no Blizzard data. Players supply `data.Wargus`, extracted from a copy they own.

## Layout

| Path | Contents |
|---|---|
| `engine/stratagus` | Stratagus submodule |
| `game/wargus` | Wargus submodule |

Because this folder is synced by IDrive, everything heavy lives on D: instead:

| Path | Contents |
|---|---|
| `D:\WarcraftAI-work\git` | Git history, including submodules |
| `D:\WarcraftAI-work\build` | Build output |
| `D:\WarcraftAI-work\data` | Extracted game data, never committed |
| `D:\WarcraftAI-work\gradle-home` | Gradle caches |
| `D:\Android` | Android Studio and SDK |

## Upstream

The submodules point at the upstream repos. To fork, create the forks on GitHub, then add them as a remote in each submodule and update `.gitmodules`.
