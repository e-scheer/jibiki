param()

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$siteMirrorRoot = Join-Path $root 'var\site_mirror'
$dashboardScript = Join-Path $root 'scripts\generate_mirror_dashboard.py'
$siteRunnerScript = Join-Path $root 'scripts\run_authorized_mirror_site.ps1'

$sites = @(
  'kanjidraw',
  'the_kanji_map',
  'kanshudo',
  'wanikani',
  'tanoshii_japanese'
)

function Get-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  try {
    return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  catch {
    return $null
  }
}

function Get-ActiveMirrorPython {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Site
  )

  Get-CimInstance Win32_Process |
    Where-Object {
      $_.Name -eq 'python.exe' -and
      $_.CommandLine -match 'mirror_sites.py' -and
      $_.CommandLine -match [regex]::Escape("--site $Site")
    } |
    Select-Object -First 1
}

function Ensure-DashboardWatcher {
  $existing = Get-CimInstance Win32_Process |
    Where-Object {
      $_.Name -eq 'python.exe' -and
      $_.CommandLine -match 'generate_mirror_dashboard.py' -and
      $_.CommandLine -match '--watch-seconds'
    } |
    Select-Object -First 1

  if ($existing) {
    return [PSCustomObject]@{
      Action = 'already-running'
      ProcessId = $existing.ProcessId
    }
  }

  $proc = Start-Process -FilePath python -ArgumentList @(
    $dashboardScript,
    '--watch-seconds', '20'
  ) -WorkingDirectory $root -WindowStyle Hidden -PassThru

  return [PSCustomObject]@{
    Action = 'started'
    ProcessId = $proc.Id
  }
}

$results = @()

$dashboard = Ensure-DashboardWatcher
$results += [PSCustomObject]@{
  Site = 'dashboard'
  Action = $dashboard.Action
  ProcessId = $dashboard.ProcessId
}

foreach ($site in $sites) {
  $runnerPath = Join-Path $siteMirrorRoot "$site\runner.json"
  $runner = Get-JsonFile -Path $runnerPath
  $activePython = Get-ActiveMirrorPython -Site $site

  if ($activePython) {
    $results += [PSCustomObject]@{
      Site = $site
      Action = 'already-running'
      ProcessId = $activePython.ProcessId
    }
    continue
  }

  if ($runner -and "$($runner.status)".ToLowerInvariant() -eq 'done') {
    $results += [PSCustomObject]@{
      Site = $site
      Action = 'already-done'
      ProcessId = $null
    }
    continue
  }

  $proc = Start-Process -FilePath powershell -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $siteRunnerScript,
    '-Site', $site
  ) -WorkingDirectory $root -WindowStyle Hidden -PassThru

  $results += [PSCustomObject]@{
    Site = $site
    Action = if ($runner) { 'resumed' } else { 'started' }
    ProcessId = $proc.Id
  }
}

$results | Format-Table -AutoSize
