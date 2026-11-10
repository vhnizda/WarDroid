# Renders the game's MIDI music to Ogg Vorbis with FluidSynth and a General
# MIDI SoundFont. FluidSynth plays the SoundFont as designed, with its filters,
# every velocity layer, stereo and reverb, which TiMidity's GUS patches can't.
#
#   powershell -File android\music\render-music.ps1 `
#       -FluidSynth D:\WarcraftAI-work\tools\fluidsynth\fluidsynth-v2.6.1-win10-x64-cpp11\bin\fluidsynth.exe `
#       -SoundFont D:\WarcraftAI-work\soundfont\GeneralUser-GS\GeneralUser-GS.sf2 `
#       -Music D:\WarcraftAI-work\data.Wargus\music `
#       -Out D:\WarcraftAI-work\data.Wargus\music
#
# The game picks the files up when wc2-config.lua sets
# wargus.music_extension = ".ogg".
param(
    [Parameter(Mandatory)][string]$FluidSynth,
    [Parameter(Mandatory)][string]$SoundFont,
    [Parameter(Mandatory)][string]$Music,
    [Parameter(Mandatory)][string]$Out,
    # One gain for every track keeps their relative loudness. At 1.0 the
    # loudest track peaks at 2.9 with GeneralUser GS, so 0.3 stays below 1.0.
    [double]$Gain = 0.3,
    # Vorbis quality from 0 to 1. 0.4 is about 128 kbit/s.
    [double]$Quality = 0.4
)

$ErrorActionPreference = 'Stop'

# The encoder uses the libsndfile that ships next to fluidsynth.exe.
$env:PATH = (Split-Path $FluidSynth) + ';' + $env:PATH
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;

public static class OggWriter {
    [StructLayout(LayoutKind.Sequential)]
    struct SfInfo { public long frames; public int samplerate, channels, format, sections, seekable; }

    [DllImport("sndfile.dll")] static extern IntPtr sf_open(string path, int mode, ref SfInfo info);
    [DllImport("sndfile.dll")] static extern int sf_command(IntPtr sf, int cmd, ref double data, int size);
    [DllImport("sndfile.dll")] static extern long sf_writef_float(IntPtr sf, float[] data, long frames);
    [DllImport("sndfile.dll")] static extern int sf_close(IntPtr sf);
    [DllImport("sndfile.dll")] static extern IntPtr sf_strerror(IntPtr sf);

    const int SFM_WRITE = 0x20;
    const int SF_FORMAT_OGG = 0x200000, SF_FORMAT_VORBIS = 0x0060;
    const int SFC_SET_VBR_ENCODING_QUALITY = 0x1300;

    // Reads a 32-bit float stereo WAV, drops the silence after the last
    // audible sample (some MIDI files end minutes after their last note)
    // and writes the rest as Ogg Vorbis. Returns the length in seconds.
    public static double Convert(string wav, string ogg, int rate, double quality) {
        byte[] b = File.ReadAllBytes(wav);
        int p = 12, start = -1, length = 0;
        while (p + 8 <= b.Length) {
            string id = System.Text.Encoding.ASCII.GetString(b, p, 4);
            int len = BitConverter.ToInt32(b, p + 4);
            if (id == "data") { start = p + 8; length = Math.Min(len, b.Length - start); break; }
            p += 8 + len + (len & 1);
        }
        if (start < 0) throw new Exception("No audio in " + wav);
        float[] samples = new float[length / 4];
        Buffer.BlockCopy(b, start, samples, 0, samples.Length * 4);

        // Keep one second after the last sample above -80 dB for reverb tails.
        int last = samples.Length - 1;
        while (last > 0 && Math.Abs(samples[last]) < 1e-4f) last--;
        long frames = Math.Min(samples.Length / 2, last / 2 + 1 + rate);

        // libvorbis needs more stack than PowerShell's threads have.
        Exception error = null;
        var thread = new System.Threading.Thread(() => {
            try { Write(ogg, samples, frames, rate, quality); } catch (Exception e) { error = e; }
        }, 64 * 1024 * 1024);
        thread.Start();
        thread.Join();
        if (error != null) throw error;
        return (double)frames / rate;
    }

    static void Write(string ogg, float[] samples, long frames, int rate, double quality) {
        SfInfo info = new SfInfo { samplerate = rate, channels = 2, format = SF_FORMAT_OGG | SF_FORMAT_VORBIS };
        IntPtr sf = sf_open(ogg, SFM_WRITE, ref info);
        if (sf == IntPtr.Zero) throw new Exception("Can't write " + ogg + ": " + Marshal.PtrToStringAnsi(sf_strerror(IntPtr.Zero)));
        sf_command(sf, SFC_SET_VBR_ENCODING_QUALITY, ref quality, 8);
        const int chunk = 4096;
        float[] buf = new float[chunk * 2];
        for (long done = 0; done < frames; done += chunk) {
            int n = (int)Math.Min(chunk, frames - done);
            Array.Copy(samples, done * 2, buf, 0, n * 2);
            if (sf_writef_float(sf, buf, n) != n) { sf_close(sf); throw new Exception("Short write to " + ogg); }
        }
        sf_close(sf);
    }
}
"@

$rate = 44100
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$work = Join-Path ([IO.Path]::GetTempPath()) ("render-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $work | Out-Null
try {
    foreach ($f in Get-ChildItem -LiteralPath $Music -Filter *.mid) {
        $wav = Join-Path $work 'track.wav'
        & $FluidSynth -ni -q -g $Gain -r $rate -O float -T wav -F $wav $SoundFont $f.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "FluidSynth failed on $($f.Name)" }
        $ogg = Join-Path $Out ($f.BaseName + '.ogg')
        $seconds = [OggWriter]::Convert($wav, $ogg, $rate, $Quality)
        Write-Host ("{0,-26} {1,4:N0}s  {2,6:N1} MB" -f $f.BaseName, $seconds, ((Get-Item -LiteralPath $ogg).Length / 1MB))
        Remove-Item -LiteralPath $wav
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
