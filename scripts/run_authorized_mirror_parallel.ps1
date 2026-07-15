$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$sites = @(
  'kanjidraw',
  'the_kanji_map',
  'kanshudo',
  'wanikani',
  'tanoshii_japanese'
)

$started = @()
foreach ($site in $sites) {
  $proc = Start-Process -FilePath powershell -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', (Join-Path $root 'scripts\run_authorized_mirror_site.ps1'),
    '-Site', $site
  ) -WorkingDirectory $root -WindowStyle Hidden -PassThru
  $started += [PSCustomObject]@{
    Site = $site
    Pid = $proc.Id
  }
}

$started | Format-Table -AutoSize
