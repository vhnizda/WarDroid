# Draws the WarDroid launcher icon as 64x64 pixel art: a crossed sword and axe
# on a square wooden shield with rounded corners. Writes it as Android vector
# drawables (one square per pixel) and an enlarged PNG preview.
#
# The shield is drawn pixel by pixel. Each weapon is drawn upright as simple
# shapes, rotated 45 degrees and rasterised without anti-aliasing, then given
# a black outline and a shadow on the wood.
#
#   powershell -File android\icon\make-icon.ps1 [-Preview <png path>]
param(
    [string]$Preview = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$res = Join-Path $PSScriptRoot '..\app\src\main\res'
$N = 64

$palette = [ordered]@{
    K = '#000000'
    # Steel
    W = '#FFFFFF'; L = '#D0D4D8'; S = '#A0A6AC'; D = '#6C727A'
    # Gold and leather
    Y = '#F8C830'; O = '#A87818'; M = '#7A1A10'; R = '#B83020'
    # Gem
    G = '#50E850'; n = '#108A28'
    # Wood, light to dark
    a = '#D49A50'; b = '#B07434'; c = '#8C5624'; e = '#643A16'; f = '#3C220C'
    # Iron
    h = '#A8AEB6'; i = '#747A84'; j = '#464B53'
}
$byArgb = @{}
foreach ($k in $palette.Keys) { $byArgb[[System.Drawing.ColorTranslator]::FromHtml($palette[$k]).ToArgb()] = $k }

function In-RoundRect($x, $y, $x0, $y0, $x1, $y1, $r) {
    $px = $x + 0.5; $py = $y + 0.5
    if ($px -lt $x0 -or $px -gt $x1 -or $py -lt $y0 -or $py -gt $y1) { return $false }
    $cx = [Math]::Min([Math]::Max($px, $x0 + $r), $x1 - $r)
    $cy = [Math]::Min([Math]::Max($py, $y0 + $r), $y1 - $r)
    ([Math]::Pow($px - $cx, 2) + [Math]::Pow($py - $cy, 2)) -le $r * $r
}

# Shield: black edge, iron rim lit from the top left, then vertical planks
# with grain and dark seams, crossed by two riveted iron bands.
$icon = New-Object 'string[,]' $N, $N
for ($y = 0; $y -lt $N; $y++) {
    for ($x = 0; $x -lt $N; $x++) {
        if (-not (In-RoundRect $x $y 0 0 64 64 12)) { continue }
        if (-not (In-RoundRect $x $y 1 1 63 63 11)) { $icon[$x, $y] = 'K'; continue }
        if (-not (In-RoundRect $x $y 5 5 59 59 8)) {
            $icon[$x, $y] = if ($x + $y -lt 56) { 'h' } elseif ($x + $y -gt 72) { 'j' } else { 'i' }
            continue
        }
        if (-not (In-RoundRect $x $y 6 6 58 58 7)) { $icon[$x, $y] = 'K'; continue }

        $col = ($x - 6) % 9
        $plank = [Math]::Floor(($x - 6) / 9)
        if ($col -eq 8) { $icon[$x, $y] = 'f'; continue }
        $wood = if ($col -eq 0) { 'a' } elseif ($col -eq 7) { 'c' } else { 'b' }
        # Broken vertical grain lines, offset per plank.
        if (($col -eq 2 -or $col -eq 5) -and (($y + $plank * 7 + $col * 3) % 11) -lt 4) { $wood = 'c' }
        if ($col -eq 4 -and (($y + $plank * 5) % 17) -eq 0) { $wood = 'e' }
        # Darker towards the lower right.
        if ($x + $y -gt 84 -and ($x + $y) % 2 -eq 0) { $wood = if ($wood -eq 'a') { 'b' } elseif ($wood -eq 'b') { 'c' } else { 'e' } }
        $icon[$x, $y] = $wood
    }
}
# A 2x2 rivet, lit from the top left.
function Set-Rivet($x, $y) {
    $x1 = $x + 1; $y1 = $y + 1
    $icon[$x, $y] = 'W'; $icon[$x1, $y] = 'h'
    $icon[$x, $y1] = 'h'; $icon[$x1, $y1] = 'j'
}

foreach ($band in @(15, 46)) {
    for ($x = 6; $x -lt 58; $x++) {
        if (-not $icon[$x, $band]) { continue }
        if ($icon[$x, $band] -in @('K', 'h', 'i', 'j')) { continue }
        $icon[$x, ($band - 1)] = 'K'
        $icon[$x, $band] = 'h'
        $icon[$x, ($band + 1)] = 'i'
        $icon[$x, ($band + 2)] = 'j'
        $icon[$x, ($band + 3)] = 'K'
    }
    for ($x = 10; $x -lt 58; $x += 9) { Set-Rivet $x $band }
}
# Rivets around the rim.
foreach ($p in @(@(14, 3), @(32, 3), @(50, 3), @(14, 60), @(32, 60), @(50, 60), @(3, 14), @(3, 32), @(3, 50), @(60, 14), @(60, 32), @(60, 50))) {
    Set-Rivet $p[0] $p[1]
}

function New-Canvas($angle) {
    $bmp = New-Object System.Drawing.Bitmap $N, $N
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'None'
    $g.PixelOffsetMode = 'Half'
    # Shapes below use a 32-unit design space centred on 16,16.
    $g.TranslateTransform(32, 32)
    $g.RotateTransform($angle)
    $g.ScaleTransform(1.8, 1.8)
    $g.TranslateTransform(-16, -16)
    @{ Bitmap = $bmp; Graphics = $g }
}

function Fill($canvas, $key, [float[]]$xy) {
    $pts = for ($n = 0; $n -lt $xy.Count; $n += 2) { New-Object System.Drawing.PointF $xy[$n], $xy[$n + 1] }
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

# Reads a canvas into a grid of palette keys.
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

# Darkens the wood two pixels down and right of a weapon.
function Add-Shadow($layer) {
    $darker = @{ a = 'c'; b = 'e'; c = 'e'; e = 'f'; h = 'i'; i = 'j' }
    for ($y = $N - 1; $y -ge 2; $y--) {
        for ($x = $N - 1; $x -ge 2; $x--) {
            $sx = $x - 2; $sy = $y - 2
            $here = [string]$icon[$x, $y]
            if ($layer[$sx, $sy] -and $darker.ContainsKey($here)) {
                $icon[$x, $y] = $darker[$here]
            }
        }
    }
}

function Merge-Layer($top) {
    for ($y = 0; $y -lt $N; $y++) {
        for ($x = 0; $x -lt $N; $x++) {
            if ($top[$x, $y]) { $icon[$x, $y] = $top[$x, $y] }
        }
    }
}

# Axe, drawn upright with the blade on the left, then turned so the head
# sits at the upper left.
$axe = New-Canvas -45
Rect $axe 'O' 15 4 17.6 28
Rect $axe 'Y' 15 4 16.1 27.5
Rect $axe 'K' 15 22.6 17.6 23.2
Rect $axe 'K' 15 24.4 17.6 25
Rect $axe 'K' 15 26.2 17.6 26.8
Rect $axe 'S' 14.4 27.5 18.2 29.4
Rect $axe 'L' 14.4 27.5 16 29.4
Fill $axe 'L' @(14.5, 5, 9, 2.5, 6.4, 5, 5.2, 8.5, 6.4, 12, 9, 14.5, 14.5, 12)
Fill $axe 'S' @(14.5, 7.5, 11, 6.5, 10, 8.5, 11, 10.5, 14.5, 9.5)
Fill $axe 'W' @(9, 2.5, 6.4, 5, 5.2, 8.5, 6.4, 12, 9, 14.5, 8, 12.4, 7.2, 8.5, 8, 4.8)
Rect $axe 'D' 13.6 4.6 18.8 12.4
Rect $axe 'S' 13.6 4.6 15.2 12.4
Rect $axe 'K' 13.6 6.8 18.8 7.2
Rect $axe 'K' 13.6 9.8 18.8 10.2
Fill $axe 'D' @(18.8, 6.4, 23, 8.5, 18.8, 10.6)
Fill $axe 'S' @(18.8, 6.4, 23, 8.5, 18.8, 8.5)
$axeLayer = Read-Layer $axe
Add-Shadow $axeLayer
Merge-Layer (Add-Outline $axeLayer)

# Sword, point at the upper right, crossing the axe at a right angle.
$sword = New-Canvas 45
Fill $sword 'W' @(16, 1, 14, 4, 14, 19, 16, 19)
Fill $sword 'L' @(16, 1, 18, 4, 18, 19, 16, 19)
Rect $sword 'S' 17.3 4.5 18 19
Rect $sword 'S' 15.75 5 16.25 17.5
Rect $sword 'Y' 10 19 22 21
Rect $sword 'O' 10 20.4 22 21.4
Fill $sword 'Y' @(10.4, 19, 8.6, 18.2, 8.6, 21.8, 10.4, 21.4)
Fill $sword 'Y' @(21.6, 19, 23.4, 18.2, 23.4, 21.8, 21.6, 21.4)
Rect $sword 'O' 8.6 21 10.4 21.8
Rect $sword 'O' 21.6 21 23.4 21.8
Rect $sword 'M' 15 21.4 17.2 26
Rect $sword 'R' 15 21.4 15.8 26
Rect $sword 'K' 15 22.8 17.2 23.2
Rect $sword 'K' 15 24.4 17.2 24.8
Disc $sword 'O' 16.1 27.8 2.5
Disc $sword 'Y' 15.8 27.5 2.2
Disc $sword 'n' 16.1 27.7 1.2
Disc $sword 'G' 15.9 27.5 0.8
$swordLayer = Read-Layer $sword
Add-Shadow $swordLayer
Merge-Layer (Add-Outline $swordLayer)

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
    foreach ($k in $palette.Keys) {
        $d = New-Object System.Text.StringBuilder
        for ($y = 0; $y -lt $N; $y++) {
            for ($x = 0; $x -lt $N; $x++) {
                if ($icon[$x, $y] -ceq $k) { [void]$d.Append("M$($x + $offset),$($y + $offset)h1v1h-1z") }
            }
        }
        if ($d.Length) {
            [void]$sb.AppendLine('    <path')
            [void]$sb.AppendLine("        android:fillColor=`"$($palette[$k])`"")
            [void]$sb.AppendLine("        android:pathData=`"$d`" />")
        }
    }
    [void]$sb.AppendLine('</vector>')
    $sb.ToString()
}

# Adaptive icons show the middle 72 of 108dp, so 64 pixels plus 16 on each
# side puts the whole shield in view.
$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $res 'drawable\ic_launcher_foreground.xml'),
    (Get-VectorXml 16 96 'Pixel-art crossed sword and axe on a wooden shield, centred on the adaptive icon canvas.'), $utf8)
[IO.File]::WriteAllText((Join-Path $res 'mipmap-anydpi\ic_launcher.xml'),
    (Get-VectorXml 0 64 'Pixel-art crossed sword and axe on a wooden shield, for Android 6 and 7.'), $utf8)

if ($Preview) {
    $scale = 6
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
