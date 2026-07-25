param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [int]$Width = 1122,
    [int]$Height = 1402,
    [string]$FontFamily = 'MS PGothic',
    [int]$GlyphSize = 620,
    [string]$BackgroundColor = '#F1CF4E',
    [string]$GlyphColor = '#FFFBE8',
    [string]$DrawingColor = '#B94F48'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-TransparentBitmap {
    param([int]$BitmapWidth = $Width, [int]$BitmapHeight = $Height)
    $bitmap = [System.Drawing.Bitmap]::new($BitmapWidth, $BitmapHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmap.SetResolution(96, 96)
    return $bitmap
}

function New-Graphics {
    param([System.Drawing.Bitmap]$Bitmap)
    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    return $graphics
}

function Get-AlphaBounds {
    param([System.Drawing.Bitmap]$Bitmap)

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt 0) {
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($maxX -lt 0) { throw 'The glyph layer is empty.' }
    return [System.Drawing.Rectangle]::new($minX, $minY, $maxX - $minX + 1, $maxY - $minY + 1)
}

function Save-Png {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$background = New-TransparentBitmap
$under = New-TransparentBitmap
$glyph = New-TransparentBitmap
$over = New-TransparentBitmap
$composite = New-TransparentBitmap
$glyphSource = New-TransparentBitmap -BitmapWidth 900 -BitmapHeight 900

$backgroundInk = [System.Drawing.ColorTranslator]::FromHtml($BackgroundColor)
$glyphInk = [System.Drawing.ColorTranslator]::FromHtml($GlyphColor)
$drawingInk = [System.Drawing.ColorTranslator]::FromHtml($DrawingColor)
$hiraganaA = [string][char]0x3042

try {
    # Render the canonical glyph once, crop to its actual alpha bounds, then place it.
    # This is the immutable source of truth; illustration layers never redraw it.
    $graphics = New-Graphics $glyphSource
    $font = [System.Drawing.Font]::new($FontFamily, $GlyphSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = [System.Drawing.SolidBrush]::new($glyphInk)
    $format = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
    try {
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap
        $graphics.DrawString($hiraganaA, $font, $brush, [System.Drawing.RectangleF]::new(0, 0, 900, 900), $format)
    }
    finally {
        $format.Dispose()
        $brush.Dispose()
        $font.Dispose()
        $graphics.Dispose()
    }

    $sourceBounds = Get-AlphaBounds $glyphSource

    # Composition target, chosen to match the reference: large, central and wide.
    $glyphBox = [System.Drawing.Rectangle]::new(
        [int]($Width * 0.19),
        [int]($Height * 0.345),
        [int]($Width * 0.62),
        [int]($Height * 0.335)
    )

    $graphics = New-Graphics $glyph
    try {
        $graphics.DrawImage(
            $glyphSource,
            $glyphBox,
            $sourceBounds.X,
            $sourceBounds.Y,
            $sourceBounds.Width,
            $sourceBounds.Height,
            [System.Drawing.GraphicsUnit]::Pixel
        )
    }
    finally { $graphics.Dispose() }

    # All illustration coordinates are derived from the placed glyph box.
    $gx = [double]$glyphBox.X
    $gy = [double]$glyphBox.Y
    $gw = [double]$glyphBox.Width
    $gh = [double]$glyphBox.Height
    $centerX = $gx + ($gw * 0.50)
    $canopyLeft = $gx + ($gw * 0.05)
    $canopyRight = $gx + ($gw * 0.95)
    $canopyTop = $gy - ($gh * 0.29)
    $canopyBottom = $gy + ($gh * 0.025)
    $shaftTop = $canopyTop + ($gh * 0.02)
    $handY = $gy + ($gh * 0.73)
    $hookBottom = $gy + ($gh * 1.13)

    # Layer 0: flat background.
    $graphics = New-Graphics $background
    try { $graphics.Clear($backgroundInk) } finally { $graphics.Dispose() }

    # Layer 1: elements behind the exact glyph: canopy and rain.
    $graphics = New-Graphics $under
    $drawingBrush = [System.Drawing.SolidBrush]::new($drawingInk)
    $rainPen = [System.Drawing.Pen]::new($drawingInk, [single]($gw * 0.010))
    try {
        $rainPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $rainPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

        foreach ($line in @(
            @(($gx - $gw * 0.04), ($canopyTop - $gh * 0.05), ($gx + $gw * 0.03), ($gy + $gh * 0.18)),
            @(($gx + $gw * 0.10), ($canopyTop - $gh * 0.10), ($gx + $gw * 0.16), ($gy - $gh * 0.03)),
            @(($gx + $gw * 0.84), ($canopyTop - $gh * 0.08), ($gx + $gw * 0.91), ($gy + $gh * 0.07)),
            @(($gx + $gw * 0.98), $canopyTop, ($gx + $gw * 1.06), ($gy + $gh * 0.23)),
            @(($gx - $gw * 0.01), ($gy + $gh * 0.45), ($gx + $gw * 0.05), ($gy + $gh * 0.76)),
            @(($gx + $gw * 0.96), ($gy + $gh * 0.42), ($gx + $gw * 1.03), ($gy + $gh * 0.72))
        )) {
            $graphics.DrawLine($rainPen, [single]$line[0], [single]$line[1], [single]$line[2], [single]$line[3])
        }

        $canopy = [System.Drawing.Drawing2D.GraphicsPath]::new()
        try {
            $cWidth = $canopyRight - $canopyLeft
            $cHeight = $canopyBottom - $canopyTop
            $canopy.StartFigure()
            $canopy.AddBezier(
                [single]$canopyLeft, [single]$canopyBottom,
                [single]($canopyLeft + $cWidth * 0.12), [single]$canopyTop,
                [single]($canopyRight - $cWidth * 0.12), [single]$canopyTop,
                [single]$canopyRight, [single]$canopyBottom
            )
            $canopy.AddBezier([single]$canopyRight, [single]$canopyBottom, [single]($canopyRight - $cWidth * 0.10), [single]($canopyBottom - $cHeight * 0.10), [single]($canopyRight - $cWidth * 0.18), [single]($canopyBottom - $cHeight * 0.10), [single]($canopyRight - $cWidth * 0.25), [single]$canopyBottom)
            $canopy.AddBezier([single]($canopyRight - $cWidth * 0.25), [single]$canopyBottom, [single]($canopyRight - $cWidth * 0.33), [single]($canopyBottom - $cHeight * 0.12), [single]($canopyRight - $cWidth * 0.42), [single]($canopyBottom - $cHeight * 0.12), [single]$centerX, [single]$canopyBottom)
            $canopy.AddBezier([single]$centerX, [single]$canopyBottom, [single]($canopyLeft + $cWidth * 0.42), [single]($canopyBottom - $cHeight * 0.12), [single]($canopyLeft + $cWidth * 0.33), [single]($canopyBottom - $cHeight * 0.12), [single]($canopyLeft + $cWidth * 0.25), [single]$canopyBottom)
            $canopy.AddBezier([single]($canopyLeft + $cWidth * 0.25), [single]$canopyBottom, [single]($canopyLeft + $cWidth * 0.18), [single]($canopyBottom - $cHeight * 0.10), [single]($canopyLeft + $cWidth * 0.10), [single]($canopyBottom - $cHeight * 0.10), [single]$canopyLeft, [single]$canopyBottom)
            $canopy.CloseFigure()
            $graphics.FillPath($drawingBrush, $canopy)
        }
        finally { $canopy.Dispose() }
    }
    finally {
        $rainPen.Dispose()
        $drawingBrush.Dispose()
        $graphics.Dispose()
    }

    # Layer 3: elements in front of the exact glyph: shaft, hand and hook.
    $graphics = New-Graphics $over
    $shaftWidth = [single]($gw * 0.035)
    $shaftPen = [System.Drawing.Pen]::new($drawingInk, $shaftWidth)
    $handBrush = [System.Drawing.SolidBrush]::new($drawingInk)
    try {
        $shaftPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $shaftPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawLine($shaftPen, [single]$centerX, [single]$shaftTop, [single]$centerX, [single]($gy + $gh * 0.91))

        $hook = [System.Drawing.Drawing2D.GraphicsPath]::new()
        try {
            $hook.StartFigure()
            $hook.AddBezier(
                [single]$centerX, [single]($gy + $gh * 0.88),
                [single]$centerX, [single]$hookBottom,
                [single]($centerX + $gw * 0.16), [single]($hookBottom + $gh * 0.01),
                [single]($centerX + $gw * 0.17), [single]($gy + $gh * 0.98)
            )
            $graphics.DrawPath($shaftPen, $hook)
        }
        finally { $hook.Dispose() }

        $handWidth = $gw * 0.13
        $handHeight = $gh * 0.20
        $graphics.FillEllipse($handBrush, [single]($centerX - $handWidth * 0.52), [single]$handY, [single]$handWidth, [single]$handHeight)
        foreach ($offset in @(0.00, 0.055, 0.11)) {
            $graphics.FillEllipse($handBrush, [single]($centerX - $handWidth * 0.68), [single]($handY + $gh * $offset), [single]($handWidth * 0.47), [single]($handHeight * 0.31))
        }
    }
    finally {
        $handBrush.Dispose()
        $shaftPen.Dispose()
        $graphics.Dispose()
    }

    # Deterministic z-order: background -> under -> exact glyph -> over.
    $graphics = New-Graphics $composite
    try {
        $graphics.DrawImageUnscaled($background, 0, 0)
        $graphics.DrawImageUnscaled($under, 0, 0)
        $graphics.DrawImageUnscaled($glyph, 0, 0)
        $graphics.DrawImageUnscaled($over, 0, 0)
    }
    finally { $graphics.Dispose() }

    $backgroundPath = Join-Path $OutputDirectory '00-background.png'
    $underPath = Join-Path $OutputDirectory '01-under-illustration.png'
    $glyphPath = Join-Path $OutputDirectory '02-exact-glyph.png'
    $overPath = Join-Path $OutputDirectory '03-over-illustration.png'
    $compositePath = Join-Path $OutputDirectory '04-composite.png'
    $manifestPath = Join-Path $OutputDirectory 'layers.json'

    Save-Png -Bitmap $background -Path $backgroundPath
    Save-Png -Bitmap $under -Path $underPath
    Save-Png -Bitmap $glyph -Path $glyphPath
    Save-Png -Bitmap $over -Path $overPath
    Save-Png -Bitmap $composite -Path $compositePath

    $manifest = [ordered]@{
        character = $hiraganaA
        font = $FontFamily
        sourceBounds = [ordered]@{ x = $sourceBounds.X; y = $sourceBounds.Y; width = $sourceBounds.Width; height = $sourceBounds.Height }
        glyphBox = [ordered]@{ x = $glyphBox.X; y = $glyphBox.Y; width = $glyphBox.Width; height = $glyphBox.Height }
        anchors = [ordered]@{ centerX = [math]::Round($centerX, 2); canopyBottom = [math]::Round($canopyBottom, 2); handY = [math]::Round($handY, 2) }
        zOrder = @(
            '00-background.png'
            '01-under-illustration.png'
            '02-exact-glyph.png'
            '03-over-illustration.png'
        )
        glyphSha256 = (Get-FileHash -Algorithm SHA256 $glyphPath).Hash
    }
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 $manifestPath
}
finally {
    $glyphSource.Dispose()
    $composite.Dispose()
    $over.Dispose()
    $glyph.Dispose()
    $under.Dispose()
    $background.Dispose()
}
