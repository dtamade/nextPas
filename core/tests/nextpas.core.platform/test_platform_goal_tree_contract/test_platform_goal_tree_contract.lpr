program test_platform_goal_tree_contract;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing;

const
  GOAL_TREE_PATH_FROM_TEST = '../../../docs/platform/goal-tree.md';
  GOAL_TREE_PATH_FROM_ROOT = 'core/docs/platform/goal-tree.md';
  RUNTIME_TRUTH_MATRIX_PATH_FROM_TEST = '../../../docs/platform/runtime-truth-matrix.md';
  RUNTIME_TRUTH_MATRIX_PATH_FROM_ROOT = 'core/docs/platform/runtime-truth-matrix.md';
  POLLER_GATE_MAKEFILE_FROM_TEST =
    '../../nextpas.core.platform.io/test_platform_windows_poller_compile_gate/Makefile';
  POLLER_GATE_MAKEFILE_FROM_ROOT =
    'core/tests/nextpas.core.platform.io/test_platform_windows_poller_compile_gate/Makefile';
  FILES_GATE_MAKEFILE_FROM_TEST =
    '../../nextpas.core.platform.files/test_platform_files/Makefile';
  FILES_GATE_MAKEFILE_FROM_ROOT =
    'core/tests/nextpas.core.platform.files/test_platform_files/Makefile';
  MMAP_GATE_MAKEFILE_FROM_TEST =
    '../../nextpas.core.platform.mmap/test_platform_mmap/Makefile';
  MMAP_GATE_MAKEFILE_FROM_ROOT =
    'core/tests/nextpas.core.platform.mmap/test_platform_mmap/Makefile';

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

function LoadDocText: string;
var
  LPath: string;
  LLines: TStringList;
begin
  LPath := ResolvePath(GOAL_TREE_PATH_FROM_TEST, GOAL_TREE_PATH_FROM_ROOT);
  Check(FileExists(LPath), 'platform goal tree must exist: ' + LPath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LPath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

function LoadTextFile(const APathFromTest, APathFromRoot, AMessage: string): string;
var
  LPath: string;
  LLines: TStringList;
begin
  LPath := ResolvePath(APathFromTest, APathFromRoot);
  Check(FileExists(LPath), AMessage + ': ' + LPath);
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

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestWindowsStatusDoesNotOverstateRuntimeReadiness;
var
  LDoc: string;
begin
  LDoc := LoadDocText;

  CheckAbsent(LDoc, '| windows | x86_64           | 代码完成, 无 ci',
    'Windows Tier 1 status must not overstate runtime readiness');
  CheckContains(LDoc, 'Windows x86_64',
    'goal tree must keep a Windows x86_64 status entry');
  CheckContains(LDoc, 'source-contract',
    'goal tree must distinguish source-contract proof from runtime proof');
  CheckContains(LDoc, 'forced Windows compile',
    'goal tree must name the forced Windows compile boundary');
  CheckContains(LDoc, 'real-Windows runtime',
    'goal tree must name the remaining real-Windows runtime gap');
end;

procedure TestWindowsEvidenceNamesCurrentFocusedGates;
var
  LDoc: string;
begin
  LDoc := LoadDocText;

  CheckContains(LDoc, 'test_poller_windows_contract',
    'goal tree must record the IOCP/poller source-contract gate');
  CheckContains(LDoc, 'test_poller_windows_compile_gate',
    'goal tree must record the IOCP forced Windows compile gate');
  CheckContains(LDoc, 'test_platform_windows_poller_compile_gate',
    'goal tree must record the platform poller forced Windows compile gate');
  CheckContains(LDoc, 'test_async',
    'goal tree must record the Linux async consumer gate');
  CheckContains(LDoc, 'heaptrc',
    'goal tree must preserve leak-proof expectations for focused runtime gates');
end;

procedure TestIocpBoundaryIsTruthful;
var
  LDoc: string;
begin
  LDoc := LoadDocText;

  CheckContains(LDoc, 'IOCP read/write',
    'goal tree must describe the implemented IOCP operation subset');
  CheckContains(LDoc, 'unsupported',
    'goal tree must state that non-read/write IOCP operations remain unsupported');
  CheckContains(LDoc, 'Windows readiness poller',
    'goal tree must keep readiness poller status separate from IOCP completion status');
end;

procedure TestRuntimeTruthMatrixDoesNotOverstateWindowsRuntime;
var
  LMatrix: string;
begin
  LMatrix := LoadTextFile(RUNTIME_TRUTH_MATRIX_PATH_FROM_TEST,
    RUNTIME_TRUTH_MATRIX_PATH_FROM_ROOT,
    'platform runtime truth matrix must exist');

  CheckContains(LMatrix, 'wine-runtime-smoke',
    'Windows IOCP file smoke must be labeled as Wine-only evidence');
  CheckContains(LMatrix, 'not real Windows runtime ready',
    'Windows IOCP file smoke must preserve the real-Windows runtime gap');
  CheckAbsent(LMatrix,
    '| windows iocp asyncread/asyncwrite file completion | focused-runtime |',
    'Windows IOCP file completion must not claim bare focused-runtime without a real Windows host');
end;

procedure TestResourceEvidenceNamesCurrentFocusedGate;
var
  LDoc: string;
begin
  LDoc := LoadDocText;

  CheckContains(LDoc, 'test_platform_resource',
    'goal tree must record the platform resource focused gate');
  CheckContains(LDoc, 'Linux resource limits',
    'goal tree must name Linux resource-limit runtime proof');
  CheckContains(LDoc, 'Android resource limits',
    'goal tree must name Android resource-limit source/compile proof');
end;

procedure TestNamedWindowsPollerCompileGateForcesWindowsHost;
var
  LMakefile: string;
begin
  LMakefile := LoadTextFile(POLLER_GATE_MAKEFILE_FROM_TEST,
    POLLER_GATE_MAKEFILE_FROM_ROOT,
    'platform Windows poller compile gate Makefile must exist');

  CheckContains(LMakefile, 'force_windows_flags ?= -dnextpas_force_host_windows',
    'named Windows poller compile gate must define a force-Windows flag');
  CheckContains(LMakefile, '$(force_windows_flags)',
    'named Windows poller compile gate test build must compile the Windows branch');
end;

procedure TestAndroidFilesMmapCompileGatesAreWired;
var
  LFilesMakefile: string;
  LMmapMakefile: string;
begin
  LFilesMakefile := LoadTextFile(FILES_GATE_MAKEFILE_FROM_TEST,
    FILES_GATE_MAKEFILE_FROM_ROOT,
    'platform files Makefile must exist');
  LMmapMakefile := LoadTextFile(MMAP_GATE_MAKEFILE_FROM_TEST,
    MMAP_GATE_MAKEFILE_FROM_ROOT,
    'platform mmap Makefile must exist');

  CheckContains(LFilesMakefile, 'test_platform_files_android_compile.lpr',
    'platform files gate must compile its Android source-contract program');
  CheckContains(LFilesMakefile, 'nextpas_force_host_android',
    'platform files gate must force the Android host branch');
  CheckContains(LFilesMakefile, '-cn',
    'platform files Android gate must be compile-only');

  CheckContains(LMmapMakefile, 'test_platform_mmap_android_compile.lpr',
    'platform mmap gate must compile its Android source-contract program');
  CheckContains(LMmapMakefile, 'nextpas_force_host_android',
    'platform mmap gate must force the Android host branch');
  CheckContains(LMmapMakefile, '-cn',
    'platform mmap Android gate must be compile-only');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.goal_tree_contract');
  T.Run('Windows status does not overstate runtime readiness',
    @TestWindowsStatusDoesNotOverstateRuntimeReadiness);
  T.Run('Windows evidence names current focused gates',
    @TestWindowsEvidenceNamesCurrentFocusedGates);
  T.Run('IOCP boundary is truthful', @TestIocpBoundaryIsTruthful);
  T.Run('runtime truth matrix does not overstate Windows runtime',
    @TestRuntimeTruthMatrixDoesNotOverstateWindowsRuntime);
  T.Run('resource evidence names current focused gate',
    @TestResourceEvidenceNamesCurrentFocusedGate);
  T.Run('named Windows poller compile gate forces Windows host',
    @TestNamedWindowsPollerCompileGateForcesWindowsHost);
  T.Run('Android files/mmap compile gates are wired',
    @TestAndroidFilesMmapCompileGatesAreWired);
  T.Summary;
end.
