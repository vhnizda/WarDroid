# Draws the WarDroid launcher icon as 32x32 pixel art in the 16-colour VGA
# palette, then writes it as Android vector drawables (one square per pixel)
# and an enlarged PNG preview.
#
# Each weapon is drawn upright as simple shapes, rotated 45 degrees and
# rasterised without anti-aliasing, then given a black outline.
#
#   powershell -File android\icon\make-icon.ps1 [-Preview <png path>]
param(
    [string]$Preview = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$res = Join-Path $PSScriptRoot '..\app\src\main\res'
$N = 32

$palette = [ordered]@{
    K = '#000000'; N = '#000080'; M = '#800000'; O = '#808000'
    D = '#808080'; L = '#C0C0C0'; W = '#FFFFFF'; R = '#FF0000'
    Y = '#FFFF00'; G = '#00FF00'
}
$byArgb = @{}
foreach ($k in $palette.Keys) { $byArgb[[System.Drawing.ColorTranslator]::FromHtml($palette[$k]).ToArgb()] = $k }

function New-Canvas($angle) {
    $bmp = New-Object System.Drawing.Bitmap $N, $N
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'None'
    $g.PixelOffsetMode = 'Half'
    $g.TranslateTransform(16, 16)
    $g.RotateTransform($angle)
    $g.ScaleTransform(0.92, 0.92)
    $g.TranslateTransform(-16, -16)
    @{ Bitmap = $bmp; Graphics = $g }
}

function Fill($canvas, $key, [float[]]$xy) {
    $pts = for ($i = 0; $i -lt $xy.Count; $i += 2) { New-Object System.Drawing.PointF $xy[$i], $xy[$i + 1] }
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($palette[$key]))
    $canvas.Graphics.FillPolygon($brush, [System.Drawing.PointF[]]$pts)
    $brush.Dispose()
}

function Rect($canvas, $key, $x1, $y1, $x2, $y2) { Fill $canvas $key @($x1, $y1, $x2, $y1, $x2, $y2, $x1, $y2) }

function Disc($canvas, $key, $cx, $cy, $r) {
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($palette[$key]))
    $canvas.Graphics.FillEllipse($brush, [float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r))
    $brush.Dispose()
}

# Reads a canvas into a 32x32 grid of palette keys.
function Read-Layer($canvas) {
    $canvas.Graphics.Dispose()
    $layer = New-Object 'string[,]' $N, $N
    for ($y = 0; $y -lt $N; $y++) {
        for ($x = 0; $x -lt $N; $x++) {
            $c = $canvas.Bitmap.GetPixel($x, $y)
            if ($c.A -eq 255) { $layer[$x, $y] = $byArgb[$c.ToArgb()] }
        }
    }
    $canvas.Bitmap.Dispose()
    ,$layer
}

# Every pixel next to a filled one (including diagonals) becomes black.
function Add-Outline($layer) {
    $out = New-Object 'string[,]' $N, $N
    for ($y = 0; $y -lt $N; $y++) {
        for ($x = 0; $x -lt $N; $x++) {
            if ($layer[$x, $y]) { $out[$x, $y] = $layer[$x, $y]; continue }
            :scan for ($dy = -1; $dy -le 1; $dy++) {
                for ($dx = -1; $dx -le 1; $dx++) {
                    $nx = $x + $dx; $ny = $y + $dy
                    if ($nx -ge 0 -and $ny -ge 0 -and $nx -lt $N -and $ny -lt $N -and $layer[$nx, $ny]) {
                        $out[$x, $y] = 'K'; break scan
                    }
                }
            }
        }
    }
    ,$out
}

function Merge-Layer($base, $top) {
    for ($y = 0; $y -lt $N; $y++) {
        for ($x = 0; $x -lt $N; $x++) {
            if ($top[$x, $y]) { $base[$x, $y] = $top[$x, $y] }
        }
    }
}

# Background: a navy disc with dithered shadow on the lower right, a red
# ring lit from the top left, and a black rim.
$icon = New-Object 'string[,]' $N, $N
for ($y = 0; $y -lt $N; $y++) {
    for ($x = 0; $x -lt $N; $x++) {
        $d = [Math]::Sqrt([Math]::Pow($x - 15.5, 2) + [Math]::Pow($y - 15.5, 2))
        if ($d -gt 15.6) { continue }
        if ($d -gt 14.6) { $icon[$x, $y] = 'K' }
        elseif ($d -gt 12.8) { $icon[$x, $y] = if ($x + $y -lt 29) { 'R' } else { 'M' } }
        elseif ($d -gt 12.0) { $icon[$x, $y] = 'K' }
        elseif ($x + $y -gt 33 -and ($x + $y) % 2) { $icon[$x, $y] = 'K' }
        else { $icon[$x, $y] = 'N' }
    }
}

# Axe, drawn upright with the blade on the left, then turned so the head
# sits at the upper left.
$axe = New-Canvas -45
Rect $axe 'O' 15 4 17.6 28
Rect $axe 'Y' 15 4 16 27.5
Rect $axe 'K' 15 22.6 17.6 23.4
Rect $axe 'K' 15 25 17.6 25.8
Rect $axe 'L' 14.4 27.5 18.2 29.4
Fill $axe 'L' @(14.5, 5, 9, 2.5, 6.4, 5, 5.2, 8.5, 6.4, 12, 9, 14.5, 14.5, 12)
Fill $axe 'W' @(9, 2.5, 6.4, 5, 5.2, 8.5, 6.4, 12, 9, 14.5, 8, 12, 7, 8.5, 8, 5)
Fill $axe 'D' @(14.5, 7, 11.5, 6, 11.5, 11, 14.5, 10)
Rect $axe 'D' 13.6 4.6 18.8 12.4
Fill $axe 'D' @(18.8, 6.4, 23, 8.5, 18.8, 10.6)
Merge-Layer $icon (Add-Outline (Read-Layer $axe))

# Sword, point at the upper right, crossing the axe at a right angle.
$sword = New-Canvas 45
Fill $sword 'W' @(16, 1, 14, 4, 14, 19, 16, 19)
Fill $sword 'L' @(16, 1, 18, 4, 18, 19, 16, 19)
Rect $sword 'D' 17.2 4.5 18 19
Rect $sword 'Y' 10 19 22 21
Rect $sword 'O' 10 20.4 22 21.6
Rect $sword 'O' 9.2 19.4 10.4 21.4
Rect $sword 'O' 21.6 19.4 22.8 21.4
Rect $sword 'M' 15 21.6 17.2 26
Rect $sword 'R' 15 22.4 17.2 23.2
Rect $sword 'R' 15 24.4 17.2 25.2
Disc $sword 'Y' 16.1 27.6 2.4
Disc $sword 'G' 16.1 27.6 1.1
Merge-Layer $icon (Add-Outline (Read-Layer $sword))

# One <path> per colour, made of 1x1 squares, offset into the canvas.
function Get-VectorXml($offset, $size, $comment) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
    [void]$sb.AppendLine("<!-- $comment Generated by android/icon/make-icon.ps1. -->")
    [void]$sb.AppendLine('<vector xmlns:android="http://schemas.android.com/apk/res/android"')
    [void]$sb.AppendLine('    android:width="108dp"')
    [void]$sb.AppendLine('    android:height="108dp"')
    [void]$sb.AppendLine("    android:viewportWidth=`"$size`"")
    [void]$sb.AppendLine("    android:viewportHeight=`"$size`">")
    foreach ($c in $palette.Keys) {
        $d = New-Object System.Text.StringBuilder
        for ($y = 0; $y -lt $N; $y++) {
            for ($x = 0; $x -lt $N; $x++) {
                if ($icon[$x, $y] -ceq $c) { [void]$d.Append("M$($x + $offset),$($y + $offset)h1v1h-1z") }
            }
        }
        if ($d.Length) {
            [void]$sb.AppendLine('    <path')
            [void]$sb.AppendLine("        android:fillColor=`"$($palette[$c])`"")
            [void]$sb.AppendLine("        android:pathData=`"$d`" />")
        }
    }
    [void]$sb.AppendLine('</vector>')
    $sb.ToString()
}

# Adaptive icons show the middle 72 of 108dp, so 32 pixels plus 8 on each
# side puts the whole disc in view.
$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $res 'drawable\ic_launcher_foreground.xml'),
    (Get-VectorXml 8 48 'Pixel-art crossed sword and axe, centred on the adaptive icon canvas.'), $utf8)
[IO.File]::WriteAllText((Join-Path $res 'mipmap-anydpi\ic_launcher.xml'),
    (Get-VectorXml 0 32 'Pixel-art crossed sword and axe, for Android 6 and 7.'), $utf8)

if ($Preview) {
    $scale = 12
    $bmp = New-Object System.Drawing.Bitmap ($N * $scale), ($N * $scale)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 90, 90, 90))
    for ($y = 0; $y -lt $N; $y++) {
        for ($x = 0; $x -lt $N; $x++) {
            $key = $icon[$x, $y]
            if ($key) {
                $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($palette[$key]))
                $g.FillRectangle($brush, $x * $scale, $y * $scale, $scale, $scale)
                $brush.Dispose()
            }
        }
    }
    $g.Dispose()
    $bmp.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}
