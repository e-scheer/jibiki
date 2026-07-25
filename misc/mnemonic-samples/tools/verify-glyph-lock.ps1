param(
    [Parameter(Mandatory = $true)]
    [string]$FinalImage,

    [Parameter(Mandatory = $true)]
    [string]$BaseImage,

    [Parameter(Mandatory = $true)]
    [string]$MaskImage,

    [string]$GlyphColor = '#FFF7E3'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public sealed class GlyphLockReport
{
    public long GlyphMaskPixels { get; set; }
    public long ModifiedGlyphPixels { get; set; }
    public long IvoryPixelsOutsideMask { get; set; }
}

public static class GlyphLockVerifier
{
    public static GlyphLockReport Verify(string finalPath, string basePath, string maskPath, Color glyph)
    {
        using (var final = new Bitmap(finalPath))
        using (var baseImage = new Bitmap(basePath))
        using (var mask = new Bitmap(maskPath))
        {
            if (final.Width != baseImage.Width || final.Height != baseImage.Height ||
                mask.Width != baseImage.Width || mask.Height != baseImage.Height)
                throw new InvalidOperationException("Image dimensions do not match.");

            var rect = new Rectangle(0, 0, final.Width, final.Height);
            var finalData = final.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var baseData = baseImage.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var maskData = mask.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            try
            {
                int bytes = Math.Abs(finalData.Stride) * final.Height;
                var finalPixels = new byte[bytes];
                var basePixels = new byte[bytes];
                var maskPixels = new byte[bytes];
                Marshal.Copy(finalData.Scan0, finalPixels, 0, bytes);
                Marshal.Copy(baseData.Scan0, basePixels, 0, bytes);
                Marshal.Copy(maskData.Scan0, maskPixels, 0, bytes);

                var report = new GlyphLockReport();
                for (int offset = 0; offset < bytes; offset += 4)
                {
                    bool inside = maskPixels[offset] != 0 || maskPixels[offset + 1] != 0 || maskPixels[offset + 2] != 0;
                    if (inside)
                    {
                        report.GlyphMaskPixels++;
                        if (finalPixels[offset] != basePixels[offset] ||
                            finalPixels[offset + 1] != basePixels[offset + 1] ||
                            finalPixels[offset + 2] != basePixels[offset + 2])
                            report.ModifiedGlyphPixels++;
                    }
                    else if (finalPixels[offset] == glyph.B &&
                             finalPixels[offset + 1] == glyph.G &&
                             finalPixels[offset + 2] == glyph.R)
                    {
                        report.IvoryPixelsOutsideMask++;
                    }
                }
                return report;
            }
            finally
            {
                final.UnlockBits(finalData);
                baseImage.UnlockBits(baseData);
                mask.UnlockBits(maskData);
            }
        }
    }
}
'@ -ReferencedAssemblies System.Drawing

$report = [GlyphLockVerifier]::Verify(
    $FinalImage,
    $BaseImage,
    $MaskImage,
    [System.Drawing.ColorTranslator]::FromHtml($GlyphColor)
)

$report | ConvertTo-Json
