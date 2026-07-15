$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'var\site_mirror\batch_logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$sites = @(
  'kanjidraw',
  'the_kanji_map',
  'kanshudo',
  'wanikani',
  'tanoshii_japanese'
)

$commonArgs = @(
  'scripts/mirror_sites.py',
  '--delay-seconds', '15',
  '--discover-links',
  '--include-assets',
  '--ignore-robots'
)

foreach ($site in $sites) {
  $stamp = Get-Date -Format o
  Add-Content -Path (Join-Path $logDir 'batch.log') -Value "$stamp START $site"
  $siteLog = Join-Path $logDir "$site.log"
  & python @commonArgs --site $site *>> $siteLog
  $stamp = Get-Date -Format o
  Add-Content -Path (Join-Path $logDir 'batch.log') -Value "$stamp END $site"
}
