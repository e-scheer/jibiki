param(
    [Parameter(Mandatory = $true)]
    [string]$Character,

    [Parameter(Mandatory = $true)]
    [string]$BaseOutput,

    [Parameter(Mandatory = $true)]
    [string]$MaskOutput,

    [int]$Width = 1122,
    [int]$Height = 1402,
    [int]$GlyphSize = 820,
    [string]$FontFamily = 'Yu Gothic',
    [ValidateSet('Regular', 'Bold')]
    [string]$FontStyle = 'Bold',
    [string]$BackgroundColor = '#E8A735',
    [string]$GlyphColor = '#FFF7E3'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-GlyphBitmap {
    param(
        [System.Drawing.Color]$Background,
        [System.Drawing.Color]$Foreground
    )

    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmap.SetResolution(96, 96)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear($Background)
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        $resolvedFontStyle = if ($FontStyle -eq 'Regular') {
            [System.Drawing.FontStyle]::Regular
        }
        else {
            [System.Drawing.FontStyle]::Bold
        }
        $font = [System.Drawing.Font]::new(
            $FontFamily,
            $GlyphSize,
            $resolvedFontStyle,
            [System.Drawing.GraphicsUnit]::Pixel
        )
        $brush = [System.Drawing.SolidBrush]::new($Foreground)
        $format = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
        try {
            $format.Alignment = [System.Drawing.StringAlignment]::Center
            $format.LineAlignment = [System.Drawing.StringAlignment]::Center
            $format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoWrap
            $rect = [System.Drawing.RectangleF]::new(0, 0, $Width, $Height)
            $graphics.DrawString($Character, $font, $brush, $rect, $format)
        }
        finally {
            $format.Dispose()
            $brush.Dispose()
            $font.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
    }

    return $bitmap
}

$baseDirectory = Split-Path -Parent $BaseOutput
$maskDirectory = Split-Path -Parent $MaskOutput
New-Item -ItemType Directory -Force -Path $baseDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $maskDirectory | Out-Null

$base = New-GlyphBitmap -Background ([System.Drawing.ColorTranslator]::FromHtml($BackgroundColor)) -Foreground ([System.Drawing.ColorTranslator]::FromHtml($GlyphColor))
$mask = New-GlyphBitmap -Background ([System.Drawing.Color]::Black) -Foreground ([System.Drawing.Color]::White)
try {
    $base.Save($BaseOutput, [System.Drawing.Imaging.ImageFormat]::Png)
    $mask.Save($MaskOutput, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $base.Dispose()
    $mask.Dispose()
}
