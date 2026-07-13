import { createHash } from 'node:crypto';
import { cp, mkdir, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';

const repoRoot = path.resolve(import.meta.dirname, '..');

function fail(message) {
  throw new Error(message);
}

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  if (index === -1 || !process.argv[index + 1]) {
    fail(`Missing --${name}`);
  }
  return process.argv[index + 1];
}

function insideRepository(candidate) {
  const relative = path.relative(repoRoot, candidate);
  return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
}

function pathsOverlap(left, right) {
  return (
    left === right ||
    left.startsWith(`${right}${path.sep}`) ||
    right.startsWith(`${left}${path.sep}`)
  );
}

async function exists(file) {
  try {
    await stat(file);
    return true;
  } catch {
    return false;
  }
}

async function filesUnder(root) {
  const result = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const absolute = path.join(root, entry.name);
    if (entry.isDirectory()) {
      result.push(...(await filesUnder(absolute)));
    } else if (entry.isFile()) {
      result.push(absolute);
    } else if (entry.isSymbolicLink()) {
      fail(`Symbolic links are not allowed in the runtime: ${path.relative(root, absolute)}`);
    }
  }
  return result;
}

async function sha256(file) {
  return createHash('sha256').update(await readFile(file)).digest('hex');
}

const release = argument('release');
const revision = argument('revision');
const siteInput = path.resolve(repoRoot, argument('site'));
const appInput = path.resolve(repoRoot, argument('app'));
const output = path.resolve(repoRoot, argument('output'));

if (!insideRepository(siteInput) || !insideRepository(appInput)) {
  fail('Build inputs must be directories inside the repository');
}
if (!insideRepository(output) || path.basename(output) !== 'web-runtime') {
  fail('The output must be a web-runtime directory inside the repository');
}
if (pathsOverlap(siteInput, output) || pathsOverlap(appInput, output)) {
  fail('The output must not overlap a build input');
}
if (!/^[0-9a-f]{40}$/.test(revision)) {
  fail('The revision must be a full Git commit SHA');
}
if (release !== `jibiki-web@${revision}`) {
  fail('The release must be jibiki-web@ followed by the exact Git revision');
}

const requiredInputs = [
  path.join(siteInput, 'fr', 'index.html'),
  path.join(siteInput, 'en', 'index.html'),
  path.join(appInput, 'index.html'),
  path.join(appInput, 'main.dart.js'),
  path.join(appInput, 'main.dart.js.map'),
];
for (const file of requiredInputs) {
  if (!(await exists(file))) fail(`Required build output is missing: ${path.relative(repoRoot, file)}`);
}

const mainJavaScript = await readFile(path.join(appInput, 'main.dart.js'), 'utf8');
const mainSourceMap = await readFile(path.join(appInput, 'main.dart.js.map'), 'utf8');
let parsedSourceMap;
try {
  parsedSourceMap = JSON.parse(mainSourceMap);
} catch {
  fail('main.dart.js.map is not valid JSON');
}
if (!mainJavaScript.includes(release)) {
  fail('main.dart.js does not contain the exact JIBIKI_RELEASE value');
}
if (!mainJavaScript.includes('_sentryDebugIds') && !mainJavaScript.includes('debugId=')) {
  fail('main.dart.js has no injected Sentry Debug ID');
}
const sourceMapDebugId = parsedSourceMap.debug_id ?? parsedSourceMap.debugId;
if (
  typeof sourceMapDebugId !== 'string' ||
  !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(sourceMapDebugId)
) {
  fail('main.dart.js.map has no injected Sentry Debug ID');
}
if (!mainJavaScript.includes(sourceMapDebugId)) {
  fail('The JavaScript and source map Sentry Debug IDs do not match');
}

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await cp(siteInput, path.join(output, 'site'), { recursive: true });
await cp(appInput, path.join(output, 'app'), {
  recursive: true,
  filter: (source) => !source.toLowerCase().endsWith('.map'),
});
await cp(path.join(repoRoot, 'caddy', 'Caddyfile'), path.join(output, 'Caddyfile'));
await cp(path.join(repoRoot, 'caddy', 'Dockerfile.runtime'), path.join(output, 'Dockerfile'));

const metadata = {
  schema: 1,
  release,
  revision,
  hosts: {
    marketing: 'jibiki.app',
    application: 'my.jibiki.app',
    api: 'api.jibiki.app',
  },
  flutterMainSha256: await sha256(path.join(appInput, 'main.dart.js')),
  sourceMaps: {
    sentryDebugId: sourceMapDebugId,
    sentryDebugIdsInjected: true,
    includedInRuntime: false,
  },
};
await mkdir(path.join(output, 'metadata'), { recursive: true });
await writeFile(
  path.join(output, 'metadata', 'release.json'),
  `${JSON.stringify(metadata, null, 2)}\n`,
  'utf8',
);

const runtimeFiles = (await filesUnder(output))
  .filter((file) => path.basename(file) !== 'SHA256SUMS')
  .sort((left, right) => left.localeCompare(right));

const forbidden = runtimeFiles.filter((file) => {
  const name = path.basename(file).toLowerCase();
  return (
    name.endsWith('.map') ||
    name.startsWith('.env') ||
    name === 'sentry.properties' ||
    name === 'google-services.json' ||
    name === 'googleservice-info.plist' ||
    name.endsWith('.p8') ||
    name.endsWith('.pem')
  );
});
if (forbidden.length > 0) {
  fail(`Forbidden release files found: ${forbidden.map((file) => path.relative(output, file)).join(', ')}`);
}

const checksums = [];
for (const file of runtimeFiles) {
  checksums.push(`${await sha256(file)}  ${path.relative(output, file).split(path.sep).join('/')}`);
}
await writeFile(path.join(output, 'SHA256SUMS'), `${checksums.join('\n')}\n`, 'utf8');

console.log(`Prepared ${release} with ${runtimeFiles.length} runtime files`);
