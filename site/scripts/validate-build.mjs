import { readFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const dist = path.resolve(here, '../dist');

const pages = [
  { file: 'fr/index.html', lang: 'fr', canonical: 'https://jibiki.app/fr/', alternate: 'https://jibiki.app/en/', schema: 'SoftwareApplication' },
  { file: 'en/index.html', lang: 'en', canonical: 'https://jibiki.app/en/', alternate: 'https://jibiki.app/fr/', schema: 'SoftwareApplication' },
  { file: 'fr/confidentialite/index.html', lang: 'fr', canonical: 'https://jibiki.app/fr/confidentialite/', alternate: 'https://jibiki.app/en/privacy/', schema: 'BreadcrumbList' },
  { file: 'en/privacy/index.html', lang: 'en', canonical: 'https://jibiki.app/en/privacy/', alternate: 'https://jibiki.app/fr/confidentialite/', schema: 'BreadcrumbList' },
  { file: 'fr/conditions/index.html', lang: 'fr', canonical: 'https://jibiki.app/fr/conditions/', alternate: 'https://jibiki.app/en/terms/', schema: 'BreadcrumbList' },
  { file: 'en/terms/index.html', lang: 'en', canonical: 'https://jibiki.app/en/terms/', alternate: 'https://jibiki.app/fr/conditions/', schema: 'BreadcrumbList' },
  { file: 'fr/sources/index.html', lang: 'fr', canonical: 'https://jibiki.app/fr/sources/', alternate: 'https://jibiki.app/en/sources/', schema: 'BreadcrumbList' },
  { file: 'en/sources/index.html', lang: 'en', canonical: 'https://jibiki.app/en/sources/', alternate: 'https://jibiki.app/fr/sources/', schema: 'BreadcrumbList' },
];

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

for (const page of pages) {
  const html = await readFile(path.join(dist, page.file), 'utf8');
  assert(html.includes(`<html lang="${page.lang}">`), `${page.file}: incorrect html lang`);
  assert(/<title>[^<]{8,}<\/title>/.test(html), `${page.file}: missing title`);
  assert(/<meta name="description" content="[^"]{40,}"/.test(html), `${page.file}: missing description`);
  assert(html.includes(`<link rel="canonical" href="${page.canonical}">`), `${page.file}: incorrect canonical`);
  assert(html.includes(`href="${page.alternate}"`), `${page.file}: missing alternate locale`);
  assert(html.includes('hreflang="x-default"'), `${page.file}: missing x-default`);
  assert(html.includes('property="og:image"'), `${page.file}: missing Open Graph image`);
  assert(html.includes('name="twitter:card" content="summary_large_image"'), `${page.file}: missing Twitter card`);
  assert(html.includes(`"@type":"${page.schema}"`), `${page.file}: missing ${page.schema} schema`);
  assert(!/<script[^>]+src=["']https:\/\/www\.googletagmanager\.com/i.test(html), `${page.file}: Google loaded before consent`);
  assert(!html.includes('https://app.jibiki.app'), `${page.file}: stale Flutter hostname`);
}

for (const locale of ['fr', 'en']) {
  const html = await readFile(path.join(dist, locale, 'index.html'), 'utf8');
  assert(html.includes('https://my.jibiki.app'), `${locale}: missing Flutter CTA hostname`);
  assert(!html.includes('"offers"'), `${locale}: unverified offer leaked into schema`);
  assert(!html.includes('"operatingSystem"'), `${locale}: unverified platform availability leaked into schema`);
  assert(!html.includes('aggregateRating'), `${locale}: invented aggregate rating`);
}

const notFound = await readFile(path.join(dist, '404.html'), 'utf8');
assert(notFound.includes('name="robots" content="noindex, nofollow"'), '404 must be noindex');

const robots = await readFile(path.join(dist, 'robots.txt'), 'utf8');
assert(robots.includes('Sitemap: https://jibiki.app/sitemap-index.xml'), 'robots sitemap mismatch');

const sitemap = await readFile(path.join(dist, 'sitemap-0.xml'), 'utf8');
assert(!sitemap.includes('/404/'), '404 leaked into sitemap');
assert(sitemap.includes('https://jibiki.app/fr/'), 'French home missing from sitemap');
assert(sitemap.includes('https://jibiki.app/en/'), 'English home missing from sitemap');
assert(!sitemap.includes('<loc>https://jibiki.app/</loc>'), 'Redirect-only root leaked into sitemap');
assert(!sitemap.includes('hreflang='), 'Sitemap generated competing automatic hreflang links');

const og = await stat(path.join(dist, 'og/jibiki-neopop.png'));
assert(og.size > 10_000, 'Open Graph image was not generated');

const consentSource = await readFile(path.resolve(here, '../src/components/ConsentBanner.astro'), 'utf8');
assert(consentSource.includes("'consent', 'update'"), 'Consent withdrawal does not update gtag');
assert(consentSource.includes("analytics_storage: 'denied'"), 'Consent withdrawal does not deny analytics storage');
assert(consentSource.includes("name.startsWith('_ga')"), 'Consent withdrawal does not purge GA cookies');
assert(consentSource.includes('window.location.reload()'), 'Consent withdrawal does not stop the active page session');

console.log(`Validated ${pages.length} localized pages, 404, robots, sitemap, schema, Open Graph assets, and analytics withdrawal.`);
