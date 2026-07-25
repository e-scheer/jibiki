param(
    [Parameter(Mandatory = $true)]
    [string]$GeneratedImage,

    [Parameter(Mandatory = $true)]
    [string]$BaseImage,

    [Parameter(Mandatory = $true)]
    [string]$MaskImage,

    [Parameter(Mandatory = $true)]
    [string]$Output,

    [string]$BackgroundColor = '#E8A735',
    [string]$DrawingColor = '#55204F'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not ('GlyphLockProcessor' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class GlyphLockProcessor
{
    private static Bitmap Normalize(Bitmap source, int width, int height)
    {
        var result = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(result))
        {
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
            graphics.DrawImage(source, 0, 0, width, height);
        }
        return result;
    }

    private static int DistanceSquared(byte blue, byte green, byte red, Color target)
    {
        int dr = red - target.R;
        int dg = green - target.G;
        int db = blue - target.B;
        return (dr * dr) + (dg * dg) + (db * db);
    }

    public static void Apply(
        string generatedPath,
        string basePath,
        string maskPath,
        string outputPath,
        Color background,
        Color drawing)
    {
        using (var baseOriginal = new Bitmap(basePath))
        using (var maskOriginal = new Bitmap(maskPath))
        using (var generatedOriginal = new Bitmap(generatedPath))
        using (var baseImage = Normalize(baseOriginal, baseOriginal.Width, baseOriginal.Height))
        using (var maskImage = Normalize(maskOriginal, baseOriginal.Width, baseOriginal.Height))
        using (var generated = Normalize(generatedOriginal, baseOriginal.Width, baseOriginal.Height))
        using (var result = new Bitmap(baseOriginal.Width, baseOriginal.Height, PixelFormat.Format32bppArgb))
        {
            var rect = new Rectangle(0, 0, result.Width, result.Height);
            var baseData = baseImage.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var maskData = maskImage.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var generatedData = generated.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var resultData = result.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);

            try
            {
                int bytes = Math.Abs(resultData.Stride) * result.Height;
                var basePixels = new byte[bytes];
                var maskPixels = new byte[bytes];
                var generatedPixels = new byte[bytes];
                var outputPixels = new byte[bytes];

                Marshal.Copy(baseData.Scan0, basePixels, 0, bytes);
                Marshal.Copy(maskData.Scan0, maskPixels, 0, bytes);
                Marshal.Copy(generatedData.Scan0, generatedPixels, 0, bytes);

                for (int offset = 0; offset < bytes; offset += 4)
                {
                    bool insideExactGlyph = maskPixels[offset] != 0 || maskPixels[offset + 1] != 0 || maskPixels[offset + 2] != 0;
                    if (insideExactGlyph)
                    {
                        outputPixels[offset] = basePixels[offset];
                        outputPixels[offset + 1] = basePixels[offset + 1];
                        outputPixels[offset + 2] = basePixels[offset + 2];
                        outputPixels[offset + 3] = 255;
                        continue;
                    }

                    int backgroundDistance = DistanceSquared(
                        generatedPixels[offset], generatedPixels[offset + 1], generatedPixels[offset + 2], background);
                    int drawingDistance = DistanceSquared(
                        generatedPixels[offset], generatedPixels[offset + 1], generatedPixels[offset + 2], drawing);
                    Color target = drawingDistance < backgroundDistance ? drawing : background;

                    outputPixels[offset] = target.B;
                    outputPixels[offset + 1] = target.G;
                    outputPixels[offset + 2] = target.R;
                    outputPixels[offset + 3] = 255;
                }

                Marshal.Copy(outputPixels, 0, resultData.Scan0, bytes);
            }
            finally
            {
                baseImage.UnlockBits(baseData);
                maskImage.UnlockBits(maskData);
                generated.UnlockBits(generatedData);
                result.UnlockBits(resultData);
            }

            result.Save(outputPath, ImageFormat.Png);
        }
    }
}
'@ -ReferencedAssemblies System.Drawing
}

$outputDirectory = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

[GlyphLockProcessor]::Apply(
    $GeneratedImage,
    $BaseImage,
    $MaskImage,
    $Output,
    [System.Drawing.ColorTranslator]::FromHtml($BackgroundColor),
    [System.Drawing.ColorTranslator]::FromHtml($DrawingColor)
)
