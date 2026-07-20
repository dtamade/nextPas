program test_platform_wine_ci_matrix_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.test;

const
  SCRIPT_PATH_FROM_TEST = '../../../scripts/platform-wine-ci-matrix.sh';
  SCRIPT_PATH_FROM_ROOT = 'core/scripts/platform-wine-ci-matrix.sh';

var
  T: TTestSuite;

function ResolvePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function LoadScriptText: string;
var
  LPath: string;
begin
  LPath := ResolvePath(SCRIPT_PATH_FROM_TEST, SCRIPT_PATH_FROM_ROOT);
  Check(FileExists(LPath), 'platform Wine CI matrix script must exist: ' + LPath);
  Result := LowerCase(FsReadFileText(LPath));
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure TestScriptIncludesAllModuleMappings;
const
  EXPECTED_ENTRIES: array[0..20] of string = (
    'platform.time core/tests/nextpas.core.platform.time/test_platform_time_wine',
    'platform.memory core/tests/nextpas.core.platform.memory/test_platform_memory_wine',
    'platform.sync core/tests/nextpas.core.platform.sync/test_platform_sync_wine',
    'platform.thread core/tests/nextpas.core.platform.thread/test_platform_thread_wine',
    'platform.io core/tests/nextpas.core.platform.io/test_platform_io_wine',
    'platform.process core/tests/nextpas.core.platform.process/test_platform_process_wine',
    'platform.files core/tests/nextpas.core.platform.files/test_platform_files_wine',
    'platform.fs core/tests/nextpas.core.platform.fs/test_platform_fs_wine',
    'platform.path core/tests/nextpas.core.platform.path/test_platform_path_wine',
    'platform.env core/tests/nextpas.core.platform.env/test_platform_env_wine',
    'platform.mmap core/tests/nextpas.core.platform.mmap/test_platform_mmap_wine',
    'platform.random core/tests/nextpas.core.platform.random/test_platform_random_wine',
    'platform.socket core/tests/nextpas.core.platform.socket/test_platform_socket_wine',
    'platform.error core/tests/nextpas.core.platform.error/test_platform_error_wine',
    'platform.fmt core/tests/nextpas.core.platform.fmt/test_platform_fmt_wine',
    'platform.info core/tests/nextpas.core.platform.info/test_platform_info_wine',
    'platform.which core/tests/nextpas.core.platform.which/test_platform_which_wine',
    'platform.dl core/tests/nextpas.core.platform.dl/test_platform_dl_wine',
    'platform.pipe core/tests/nextpas.core.platform.pipe/test_platform_pipe_wine',
    'platform.args core/tests/nextpas.core.platform.args/test_platform_args_wine',
    'io.reactor.iocp core/tests/nextpas.core.io.uring/test_reactor_iocp_wine'
  );
var
  LScript: string;
  I: Integer;
begin
  LScript := LoadScriptText;
  for I := Low(EXPECTED_ENTRIES) to High(EXPECTED_ENTRIES) do
    CheckContains(LScript, EXPECTED_ENTRIES[I],
      'Wine CI matrix script must include expected module mapping');
end;

procedure TestScriptEnforcesSkipLogAndSummaryContract;
var
  LScript: string;
begin
  LScript := LoadScriptText;

  CheckContains(LScript, 'set -euo pipefail',
    'Wine CI matrix script must enable strict bash options');
  CheckContains(LScript, 'which wine',
    'Wine CI matrix script must detect wine availability');
  CheckContains(LScript, 'skip: wine not available',
    'Wine CI matrix script must print the exact skip banner when Wine is unavailable');
  CheckContains(LScript, 'exit 0',
    'Wine CI matrix script must support graceful skip exit');
  CheckContains(LScript, 'mktemp',
    'Wine CI matrix script must persist per-module output to temp logs');
  CheckContains(LScript, 'make -c',
    'Wine CI matrix script must invoke make inside each module test directory');
  CheckContains(LScript, 'wine-runtime-smoke',
    'Wine CI matrix script must invoke per-module wine-runtime-smoke targets');
  CheckContains(LScript, 'wine-runtime-smoke requires wine|skip:',
    'Wine CI matrix must SKIP only when Wine-missing markers appear in logs');
  CheckContains(LScript, 'make failed (exit',
    'Wine CI matrix must surface non-Wine make failures as FAIL with exit code');
  CheckContains(LScript, 'pass_count',
    'Wine CI matrix script must track pass count');
  CheckContains(LScript, 'fail_count',
    'Wine CI matrix script must track fail count');
  CheckContains(LScript, 'skip_count',
    'Wine CI matrix script must track skip count');
  CheckContains(LScript, 'color_pass',
    'Wine CI matrix script must define colored PASS output');
  CheckContains(LScript, 'color_fail',
    'Wine CI matrix script must define colored FAIL output');
  CheckContains(LScript, 'color_skip',
    'Wine CI matrix script must define colored SKIP output');
  CheckContains(LScript, 'log_path',
    'Wine CI matrix script must retain failing log paths');
  CheckContains(LScript, 'module',
    'Wine CI matrix script must print a summary table header');
  CheckContains(LScript, 'status',
    'Wine CI matrix script must print a status column in the summary table');
  CheckContains(LScript, 'summary',
    'Wine CI matrix script must print a final summary');
  CheckContains(LScript, 'failed logs',
    'Wine CI matrix script must print failing log locations');
end;

procedure TestCrossModuleTestAbiGuards;
{ Platform wine/macOS GHA depend on these test-harness ABI choices.
  Keep them under platform contracts so test-module lands cannot silently
  regress Windows stdcall or Darwin TThreadID without breaking a platform
  focused gate. }
const
  EXPECT_FROM_TEST = '../../../src/nextpas.core.test.expect.pas';
  EXPECT_FROM_ROOT = 'core/src/nextpas.core.test.expect.pas';
  RUNNER_FROM_TEST = '../../../src/nextpas.core.test.runner.pas';
  RUNNER_FROM_ROOT = 'core/src/nextpas.core.test.runner.pas';
var
  LExpect: string;
  LRunner: string;
begin
  LExpect := LowerCase(FsReadFileText(ResolvePath(EXPECT_FROM_TEST, EXPECT_FROM_ROOT)));
  LRunner := LowerCase(FsReadFileText(ResolvePath(RUNNER_FROM_TEST, RUNNER_FROM_ROOT)));

  CheckContains(LExpect, '{$ifdef windows}stdcall{$else}cdecl{$endif}',
    'TExpectationBase IUnknown must use stdcall on Windows (wine compile)');
  Check(Pos('{$ifndef windows}cdecl{$endif}', LExpect) = 0,
    'expect must not use IFNDEF-WINDOWS cdecl-only form (empty convention on Win)');

  CheckContains(LRunner, 'tthreadid(0)',
    'parallel runner must use TThreadID(0) (Darwin aarch64)');
  Check(Pos('lthreads[i] := 0;', LRunner) = 0,
    'runner must not assign bare 0 to LThreads (Darwin ShortInt trap)');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.wine_ci_matrix_contract');
  T.Test('script includes all Wine module mappings', @TestScriptIncludesAllModuleMappings);
  T.Test('script enforces skip/log/summary contract',
    @TestScriptEnforcesSkipLogAndSummaryContract);
  T.Test('cross-module test ABI guards (stdcall + TThreadID)',
    @TestCrossModuleTestAbiGuards);
  if not T.Run then Halt(1);
end.
