program test_platform_cross_ci_matrix_contract;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing;

const
  SCRIPT_PATH_FROM_TEST = '../../../scripts/platform-cross-ci-matrix.sh';
  SCRIPT_PATH_FROM_ROOT = 'core/scripts/platform-cross-ci-matrix.sh';

var
  T: TTestRunner;

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
  LLines: TStringList;
begin
  LPath := ResolvePath(SCRIPT_PATH_FROM_TEST, SCRIPT_PATH_FROM_ROOT);
  Check(FileExists(LPath), 'platform cross CI matrix script must exist: ' + LPath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LPath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure TestScriptIncludesAllTargetArchitectures;
const
  EXPECTED_ENTRIES: array[0..2] of string = (
    'riscv64-linux',
    'aarch64-linux',
    'arm32-linux'
  );
var
  LScript: string;
  I: Integer;
begin
  LScript := LoadScriptText;
  for I := Low(EXPECTED_ENTRIES) to High(EXPECTED_ENTRIES) do
    CheckContains(LScript, EXPECTED_ENTRIES[I],
      'cross CI matrix script must include expected target architecture');
end;

procedure TestScriptIncludesAllModuleGates;
const
  EXPECTED_MODULES: array[0..12] of string = (
    'platform.time',
    'platform.memory',
    'platform.sync',
    'platform.thread',
    'platform.io',
    'platform.process',
    'platform.files',
    'platform.fs',
    'platform.path',
    'platform.env',
    'platform.mmap',
    'platform.random',
    'platform.socket'
  );
var
  LScript: string;
  I: Integer;
begin
  LScript := LoadScriptText;
  for I := Low(EXPECTED_MODULES) to High(EXPECTED_MODULES) do
    CheckContains(LScript, EXPECTED_MODULES[I],
      'cross CI matrix script must reference expected platform module');
end;

procedure TestScriptEnforcesSkipLogAndSummaryContract;
var
  LScript: string;
begin
  LScript := LoadScriptText;

  CheckContains(LScript, 'set -euo pipefail',
    'cross CI matrix script must enable strict bash options');
  CheckContains(LScript, 'mktemp',
    'cross CI matrix script must create temp directory for logs');
  CheckContains(LScript, 'make -c',
    'cross CI matrix script must invoke make inside each test directory');
  CheckContains(LScript, 'forced-compile',
    'cross CI matrix script must document forced-compile evidence tier');
  CheckContains(LScript, 'pass_count',
    'cross CI matrix script must track pass count');
  CheckContains(LScript, 'fail_count',
    'cross CI matrix script must track fail count');
  CheckContains(LScript, 'skip_count',
    'cross CI matrix script must track skip count');
  CheckContains(LScript, 'color_pass',
    'cross CI matrix script must define colored PASS output');
  CheckContains(LScript, 'color_fail',
    'cross CI matrix script must define colored FAIL output');
  CheckContains(LScript, 'color_skip',
    'cross CI matrix script must define colored SKIP output');
  CheckContains(LScript, 'log_path',
    'cross CI matrix script must retain failing log paths');
  CheckContains(LScript, 'status',
    'cross CI matrix script must print a status column in the summary');
  CheckContains(LScript, 'summary',
    'cross CI matrix script must print a final summary');
  CheckContains(LScript, 'failed logs',
    'cross CI matrix script must print failing log locations');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.cross_ci_matrix_contract');
  T.Run('script includes all target architectures',
    @TestScriptIncludesAllTargetArchitectures);
  T.Run('script references all platform modules',
    @TestScriptIncludesAllModuleGates);
  T.Run('script enforces skip/log/summary contract',
    @TestScriptEnforcesSkipLogAndSummaryContract);
  T.Summary;
end.
