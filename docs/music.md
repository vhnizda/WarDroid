# Music

The Battle.net Edition's music is MIDI. It's rendered on the PC to Ogg Vorbis with FluidSynth and the GeneralUser GS SoundFont (free licence, kept in `D:\WarcraftAI-work\soundfont`), which sounds as the SoundFont intends and costs the phone nothing to synthesise. FluidSynth 2.6.1 for Windows is in `D:\WarcraftAI-work\tools\fluidsynth`, from the official GitHub releases. The script also trims silence that some MIDI files leave after their last note:

```powershell
powershell -File android\music\render-music.ps1 -FluidSynth D:\WarcraftAI-work\tools\fluidsynth\fluidsynth-v2.6.1-win10-x64-cpp11\bin\fluidsynth.exe -SoundFont D:\WarcraftAI-work\soundfont\GeneralUser-GS\GeneralUser-GS.sf2 -Music D:\WarcraftAI-work\data.Wargus\music -Out D:\WarcraftAI-work\data.Wargus\music
```

Then set `wargus.music_extension = ".ogg"` in `data.Wargus/scripts/wc2-config.lua`.

The fallback is to play the MIDI files on the device through TiMidity, with `wargus.music_extension = ".mid"`. That needs instruments in `data.Wargus/timidity`. Build the converter once, then run the script, which keeps only the instruments the music uses and removes the vibrato that `unsf` adds to brass and winds:

```powershell
cmake -S D:/w/engine/stratagus/third-party/unsf -B D:/WarcraftAI-work/build/host-unsf -G "Visual Studio 17 2022" -A x64
cmake --build D:/WarcraftAI-work/build/host-unsf --config Release
powershell -File android\music\make-timidity.ps1 -SoundFont D:\WarcraftAI-work\soundfont\GeneralUser-GS\GeneralUser-GS.sf2 -Music D:\WarcraftAI-work\data.Wargus\music -Out D:\WarcraftAI-work\data.Wargus\timidity -Unsf D:\WarcraftAI-work\build\host-unsf\Release\unsf.exe
```

The app reads game data from `Android/data/com.vaclav.wargusport/files/data.Wargus` on the device. The app has no importer yet, so copy the folder with `adb push`.

