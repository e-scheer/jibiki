param(
  [Parameter(Mandatory = $true)]
  [string]$Site
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'var\site_mirror\batch_logs'
$siteRoot = Join-Path $root ("var\site_mirror\" + $Site)
$runnerPath = Join-Path $siteRoot 'runner.json'
$siteLog = Join-Path $logDir ($Site + '.log')
New-Item -ItemType Directory -Force -Path $logDir, $siteRoot | Out-Null

$commonArgs = @(
  'scripts/mirror_sites.py',
  '--delay-seconds', '15',
  '--discover-links',
  '--ignore-robots',
  '--scope', 'jibiki',
  '--site', $Site
)

$startAt = Get-Date -Format o
Add-Content -Path (Join-Path $logDir 'batch.log') -Value "$startAt START $Site"

$runner = @{
  site = $Site
  pid = $PID
  status = 'running'
  start_at = $startAt
}
$runner | ConvertTo-Json | Set-Content -Path $runnerPath -Encoding UTF8

& python @commonArgs *>> $siteLog
$exitCode = $LASTEXITCODE

$endAt = Get-Date -Format o
Add-Content -Path (Join-Path $logDir 'batch.log') -Value "$endAt END $Site"

$runner.status = if ($exitCode -eq 0) { 'done' } else { 'failed' }
$runner.end_at = $endAt
$runner.exit_code = $exitCode
$runner | ConvertTo-Json | Set-Content -Path $runnerPath -Encoding UTF8

exit $exitCode
