# SPDX-License-Identifier: GPL-2.0-or-later
<#
  Runs the FPCUnit tests against several server versions using throw-away
  Podman/Docker containers.

  Usage:  pwsh tests/run-matrix.ps1 [-Only mysql:8.4,mariadb:11] [-Keep]

  Prerequisites: backend built (backend/build), tests built (tests/bin/qbr_tests.exe),
  MSYS2 mingw64 at C:\msys64 for the runtime DLLs.
#>
param(
  [string[]]$Only,
  [switch]$Keep
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $PSScriptRoot 'bin\qbr_tests.exe'
if (-not (Test-Path $exe)) { throw "Build the tests first: $exe not found" }

$engine = if (Get-Command podman -ErrorAction SilentlyContinue) { 'podman' } else { 'docker' }
$password = if ($env:QBR_TEST_PASSWORD) { $env:QBR_TEST_PASSWORD } else { 'qbr-test' }

# image, env var for the root password, admin client used for readiness checks
$matrix = @(
  @{ Image = 'mysql:5.7';   PwdVar = 'MYSQL_ROOT_PASSWORD';   Admin = 'mysqladmin' },
  @{ Image = 'mysql:8.0';   PwdVar = 'MYSQL_ROOT_PASSWORD';   Admin = 'mysqladmin' },
  @{ Image = 'mysql:8.4';   PwdVar = 'MYSQL_ROOT_PASSWORD';   Admin = 'mysqladmin' },
  @{ Image = 'mysql:9';     PwdVar = 'MYSQL_ROOT_PASSWORD';   Admin = 'mysqladmin' },
  @{ Image = 'mariadb:10.11'; PwdVar = 'MARIADB_ROOT_PASSWORD'; Admin = 'mariadb-admin' },
  @{ Image = 'mariadb:11.4';  PwdVar = 'MARIADB_ROOT_PASSWORD'; Admin = 'mariadb-admin' }
)
if ($Only) { $matrix = $matrix | Where-Object { $Only -contains $_.Image } }

$env:PATH = "C:\msys64\mingw64\bin;" + (Join-Path $root 'backend\build') + ";" + $env:PATH
$results = @()
$port = 34000

foreach ($m in $matrix) {
  $port++
  $name = 'qbr-matrix-' + ($m.Image -replace '[^a-zA-Z0-9]', '-')
  Write-Host "=== $($m.Image) on port $port"
  & $engine rm -f $name 2>$null | Out-Null
  & $engine run -d --name $name -p "${port}:3306" -e "$($m.PwdVar)=$password" "docker.io/library/$($m.Image)" | Out-Null

  $ready = $false
  for ($i = 0; $i -lt 60; $i++) {
    $out = & $engine exec $name $m.Admin ping -uroot "-p$password" 2>&1 | Out-String
    if ($out -match 'alive') { $ready = $true; break }
    Start-Sleep 3
  }
  if (-not $ready) {
    $results += [pscustomobject]@{ Server = $m.Image; Result = 'server did not start'; Details = '' }
    if (-not $Keep) { & $engine rm -f $name | Out-Null }
    continue
  }
  # the entrypoint restarts the server once after initialisation; wait until it is stable
  Start-Sleep 3

  $env:QBR_TEST_PORT = "$port"
  $log = & $exe --all --format=plain 2>&1 | Out-String
  $run = [regex]::Match($log, 'Number of run tests:\s+(\d+)').Groups[1].Value
  $err = [regex]::Match($log, 'Number of errors:\s+(\d+)').Groups[1].Value
  $fail = [regex]::Match($log, 'Number of failures:\s+(\d+)').Groups[1].Value
  $status = if ($run -and $err -eq '0' -and $fail -eq '0') { 'PASS' } else { 'FAIL' }
  $details = if ($status -eq 'FAIL') { ($log -split "`n" | Select-String 'Failed:|Exception|Assertion|Message' | Select-Object -First 5) -join ' | ' } else { '' }
  # the application itself: connect through the ported code, once via the command line path and
  # once by driving the connect dialog (needs app/bin/qbr.exe and `python tools/prepare_runtime.py`)
  $app = Join-Path $root 'app\bin\qbr.exe'
  $appResult = 'n/a'
  if (Test-Path $app) {
    $dataDir = Join-Path ([IO.Path]::GetTempPath()) "qbr-matrix-data"
    New-Item -ItemType Directory -Force $dataDir | Out-Null
    $ok = @()
    foreach ($mode in 'selftest-connect', 'selftest-dialog') {
      $report = Join-Path $dataDir "$mode.txt"
      Remove-Item $report -ErrorAction SilentlyContinue
      $p = Start-Process -FilePath $app -PassThru -WindowStyle Hidden -ArgumentList @(
        '-datadir', $dataDir, '-u', 'root', '-p', $password, '-h', '127.0.0.1', '-P', "$port", "--$mode", $report)
      if (-not $p.WaitForExit(60000)) { $p.Kill() }
      $text = if (Test-Path $report) { (Get-Content $report -Raw).Trim() } else { 'no report' }
      $ok += ($text -match '^(dialog )?connected')
    }
    $appResult = if ($ok -notcontains $false) { 'PASS' } else { 'FAIL' }
  }
  $results += [pscustomobject]@{ Server = $m.Image; Result = "$status ($run tests)"; App = $appResult; Details = $details }

  if (-not $Keep) { & $engine rm -f $name | Out-Null }
}

$results | Format-Table -AutoSize -Wrap
if ($results | Where-Object { $_.Result -notlike "PASS*" -or $_.App -eq "FAIL" }) { exit 1 }
