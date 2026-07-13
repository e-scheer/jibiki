import { copyFile, mkdir, rm, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const appFonts = path.resolve(root, '../app/assets/fonts');
const publicFonts = path.resolve(root, 'public/fonts');
const publicOg = path.resolve(root, 'public/og');

await mkdir(publicFonts, { recursive: true });
await mkdir(publicOg, { recursive: true });

const fonts = [
  'SpaceGrotesk-Medium.ttf',
  'SpaceGrotesk-SemiBold.ttf',
  'SpaceGrotesk-Bold.ttf',
  'ZenKakuGothicNew-Bold.ttf',
  'ZenKakuGothicNew-Black.ttf',
];

await Promise.all(
  fonts.map((font) => copyFile(path.join(appFonts, font), path.join(publicFonts, font))),
);

// Sharp renders SVG text through Pango/Fontconfig. Minimal CI containers do not
// ship a global Fontconfig file, so point it explicitly at the canonical local
// brand fonts before Sharp is loaded. This keeps the social preview identical
// on developer machines and in the release image.
const fontConfig = path.join(os.tmpdir(), `jibiki-fontconfig-${process.pid}.xml`);
const escapeXml = (value) =>
  value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
await writeFile(
  fontConfig,
  `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>${escapeXml(appFonts)}</dir>
  <cachedir>${escapeXml(path.join(os.tmpdir(), 'jibiki-font-cache'))}</cachedir>
</fontconfig>
`,
  'utf8',
);
process.env.FONTCONFIG_FILE = fontConfig;

try {
  const { default: sharp } = await import('sharp');
  await sharp(path.resolve(root, 'src/assets/og-neopop.svg'))
    .resize(1200, 630)
    .png({ compressionLevel: 9, palette: true })
    .toFile(path.join(publicOg, 'jibiki-neopop.png'));
} finally {
  await rm(fontConfig, { force: true });
}
