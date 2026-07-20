# platform-windows-ci-matrix.ps1
#
# Real Windows host CI matrix (not Wine).
# Runs the same suite directories used by platform-wine-ci-matrix.sh with native
# `make clean test` so {$IFDEF NEXTPAS_WINDOWS} paths execute on the host.
#
# Usage (from repo root or core/):
#   pwsh core/scripts/platform-windows-ci-matrix.ps1
#   pwsh scripts/platform-windows-ci-matrix.ps1   # when cwd is core/
#
# Evidence: truth=ci-matrix for the documented gate set (ROADMAP).
# Scope is the listed module dirs only — not full-host Windows parity.
# 19-gate promoted (+error +fmt) after GHA pass=19 (run 29686191527).

$ErrorActionPreference = 'Stop'

function Resolve-CoreRoot {
  $here = $PSScriptRoot
  if (Test-Path (Join-Path $here '..\src\nextpas.core.platform.pas')) {
    return (Resolve-Path (Join-Path $here '..')).Path
  }
  if (Test-Path (Join-Path $here 'src\nextpas.core.platform.pas')) {
    return (Resolve-Path $here).Path
  }
  throw "Unable to resolve core/ root from $here"
}

$CoreRoot = Resolve-CoreRoot
Set-Location $CoreRoot

$ModuleEntries = @(
  @{ Name = 'platform.time';    Dir = 'tests/nextpas.core.platform.time/test_platform_time_wine' }
  @{ Name = 'platform.memory';  Dir = 'tests/nextpas.core.platform.memory/test_platform_memory_wine' }
  @{ Name = 'platform.sync';    Dir = 'tests/nextpas.core.platform.sync/test_platform_sync_wine' }
  @{ Name = 'platform.thread';  Dir = 'tests/nextpas.core.platform.thread/test_platform_thread_wine' }
  @{ Name = 'platform.io';      Dir = 'tests/nextpas.core.platform.io/test_platform_io_wine' }
  @{ Name = 'platform.process'; Dir = 'tests/nextpas.core.platform.process/test_platform_process_wine' }
  @{ Name = 'platform.files';   Dir = 'tests/nextpas.core.platform.files/test_platform_files_wine' }
  @{ Name = 'platform.fs';      Dir = 'tests/nextpas.core.platform.fs/test_platform_fs_wine' }
  @{ Name = 'platform.path';    Dir = 'tests/nextpas.core.platform.path/test_platform_path_wine' }
  @{ Name = 'platform.env';     Dir = 'tests/nextpas.core.platform.env/test_platform_env_wine' }
  @{ Name = 'platform.mmap';    Dir = 'tests/nextpas.core.platform.mmap/test_platform_mmap_wine' }
  @{ Name = 'platform.random';  Dir = 'tests/nextpas.core.platform.random/test_platform_random_wine' }
  @{ Name = 'platform.socket';  Dir = 'tests/nextpas.core.platform.socket/test_platform_socket_wine' }
  @{ Name = 'platform.error';   Dir = 'tests/nextpas.core.platform.error/test_platform_error_wine' }
  @{ Name = 'platform.fmt';     Dir = 'tests/nextpas.core.platform.fmt/test_platform_fmt_wine' }
  @{ Name = 'platform.info';    Dir = 'tests/nextpas.core.platform.info/test_platform_info_wine' }
  @{ Name = 'platform.which';   Dir = 'tests/nextpas.core.platform.which/test_platform_which_wine' }
  @{ Name = 'platform.dl';      Dir = 'tests/nextpas.core.platform.dl/test_platform_dl_wine' }
  @{ Name = 'platform.args';    Dir = 'tests/nextpas.core.platform.args/test_platform_args_wine' }
  @{ Name = 'platform.pipe';    Dir = 'tests/nextpas.core.platform.pipe/test_platform_pipe_wine' }
  @{ Name = 'platform.resource'; Dir = 'tests/nextpas.core.platform.resource/test_platform_resource_wine' }
  @{ Name = 'platform.pty';     Dir = 'tests/nextpas.core.platform.pty/test_platform_pty_wine' }
  @{ Name = 'io.reactor.iocp'; Dir = 'tests/nextpas.core.io.uring/test_reactor_iocp_wine' }
)

$ExtraRealGates = @(
  @{ Name = 'poller.windows_runtime_smoke'; Dir = 'tests/nextpas.core.io.uring/test_poller_windows_runtime_smoke' }
  @{ Name = 'platform.io.windows_real';     Dir = 'tests/nextpas.core.platform/test_platform_io_windows_real' }
  @{ Name = 'platform.socket.windows_real'; Dir = 'tests/nextpas.core.platform.socket/test_platform_socket_windows_real' }
)

$AllEntries = $ModuleEntries + $ExtraRealGates
$pass = 0
$fail = 0
$failed = @()

Write-Output '=== Platform Windows CI Matrix (real host) ==='
Write-Output 'truth=ci-matrix-candidate; 25 platform gates promoted + pty candidate; not full-host Windows parity'
Write-Output "core=$CoreRoot"
Write-Output ''

foreach ($entry in $AllEntries) {
  $dir = $entry.Dir
  $name = $entry.Name
  if (-not (Test-Path $dir)) {
    Write-Output "FAIL $name : missing directory $dir"
    $fail++
    $failed += "$name (missing $dir)"
    continue
  }

  Write-Output "=== real-windows: $name ($dir) ==="
  & make -C $dir clean test
  if ($LASTEXITCODE -ne 0) {
    Write-Output "FAIL $name (exit $LASTEXITCODE)"
    $fail++
    $failed += "$name (exit $LASTEXITCODE)"
  } else {
    Write-Output "PASS $name"
    $pass++
  }
  Write-Output ''
}

Write-Output "summary: pass=$pass fail=$fail total=$($AllEntries.Count)"
Write-Output "truth=ci-matrix; gates_passed=$pass; gates_failed=$fail; scope=documented-25-platform-gate-set-plus-pty-candidate"

if ($fail -gt 0) {
  Write-Output 'failed:'
  foreach ($item in $failed) {
    Write-Output "  - $item"
  }
  exit 1
}

exit 0
