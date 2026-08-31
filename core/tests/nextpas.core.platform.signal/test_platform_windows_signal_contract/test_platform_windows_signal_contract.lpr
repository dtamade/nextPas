program test_platform_windows_signal_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.test;

var
  T: TTestSuite;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  if FileExists('../../../' + ARelativePath) then
    Exit('../../../' + ARelativePath);
  if FileExists('core/' + ARelativePath) then
    Exit('core/' + ARelativePath);
  Result := '../../../' + ARelativePath;
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  Result := FsReadFileText(LSourcePath);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

function SliceBetween(const ASource, AStartToken, AEndToken: string): string;
var
  LStart: SizeInt;
  LEndPos: SizeInt;
begin
  LStart := Pos(AStartToken, ASource);
  Check(LStart > 0, 'start token exists: ' + AStartToken);
  LEndPos := Pos(AEndToken, Copy(ASource, LStart + Length(AStartToken),
    Length(ASource)));
  Check(LEndPos > 0, 'end token exists: ' + AEndToken);
  Result := Copy(ASource, LStart, Length(AStartToken) + LEndPos - 1);
end;

procedure TestWindowsFfiOwnsConsoleHandler;
var
  LBase: string;
  LFfi: string;
begin
  LBase := LoadSourceText('src/nextpas.core.platform.windows.base.pas');
  LFfi := LoadSourceText('src/nextpas.core.platform.windows.ffi.pas');
  CheckContains(LBase, 'CTRL_C_EVENT', 'base must define console Ctrl+C');
  CheckContains(LBase, 'CTRL_BREAK_EVENT', 'base must define console Ctrl+Break');
  CheckContains(LBase, 'TConsoleCtrlHandlerRoutine',
    'base must define typed console control handler routine');
  CheckContains(LFfi, 'SetConsoleCtrlHandler',
    'FFI must expose SetConsoleCtrlHandler');
  CheckContains(LFfi, 'GenerateConsoleCtrlEvent',
    'FFI must expose GenerateConsoleCtrlEvent for platform_signal_raise');
  CheckContains(LFfi, 'TConsoleCtrlHandlerRoutine',
    'SetConsoleCtrlHandler must use nextPas-owned typed handler');
end;

procedure TestWindowsSignalBranchIsNotStub;
var
  LSignal: string;
  LWindowsBranch: string;
  LImplStart: SizeInt;
begin
  LSignal := LoadSourceText('src/nextpas.core.platform.signal.pas');
  { First {$IFDEF NEXTPAS_WINDOWS} guards the PLATFORM_SIGBREAK constant;
    the implementation branch is the second occurrence later in the file. }
  LImplStart := Pos('{$IFDEF NEXTPAS_WINDOWS}', LSignal);
  LImplStart := Pos('{$IFDEF NEXTPAS_WINDOWS}',
    Copy(LSignal, LImplStart + 1, Length(LSignal))) + LImplStart;
  LWindowsBranch := SliceBetween(Copy(LSignal, LImplStart, Length(LSignal)),
    '{$IFDEF NEXTPAS_WINDOWS}', '{$IF not defined(NEXTPAS_LINUX)');
  CheckAbsent(LWindowsBranch, 'Result := -1',
    'Windows signal branch must not return bare stub errors');
  CheckAbsent(LWindowsBranch, 'use SetConsoleCtrlHandler directly',
    'upper layers must not be told to call WinAPI directly');
  CheckContains(LWindowsBranch, 'SetConsoleCtrlHandler',
    'Windows signal branch must install console control handler internally');
  CheckContains(LWindowsBranch, 'GenerateConsoleCtrlEvent',
    'Windows signal branch must raise via GenerateConsoleCtrlEvent');
  CheckContains(LWindowsBranch, 'nextpas.core.platform.error',
    'Windows signal branch must use platform.error for PLATFORM_ERR_*');
  CheckContains(LWindowsBranch, 'PLATFORM_SIGINT',
    'Windows signal branch must map Ctrl+C to PLATFORM_SIGINT');
  CheckContains(LWindowsBranch, 'PLATFORM_SIGBREAK',
    'Windows signal branch must map Ctrl+Break');
  CheckContains(LWindowsBranch, 'PLATFORM_ERR_UNSUPPORTED',
    'unsupported POSIX signals must return stable PLATFORM_ERR_UNSUPPORTED');
end;

procedure TestSignalConstantsDocumentWindowsBreak;
var
  LSignal: string;
begin
  LSignal := LoadSourceText('src/nextpas.core.platform.signal.pas');
  CheckContains(LSignal, 'PLATFORM_SIGBREAK',
    'platform signal facade must expose Ctrl+Break signal on Windows');
  CheckContains(LSignal, 'Windows console control',
    'Windows signal comments must state console-control semantics');
end;

procedure TestTuiTerminalChecksSignalHookResult;
var
  LTerminal: string;
begin
  LTerminal := LoadSourceText('src/nextpas.core.tui.terminal.pas');
  CheckContains(LTerminal, 'platform_signal_set(PLATFORM_SIGTERM, @SigtermHandler) = 0',
    'terminal must only mark SIGTERM hooked when platform hook succeeds');
  CheckContains(LTerminal, 'platform_signal_set(PLATFORM_SIGWINCH, @SigwinchHandler) = 0',
    'terminal must only mark SIGWINCH hooked when platform hook succeeds');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.windows.signal_contract');
  T.Test('Windows FFI owns console handler', @TestWindowsFfiOwnsConsoleHandler);
  T.Test('Windows signal branch is not stub', @TestWindowsSignalBranchIsNotStub);
  T.Test('Windows Ctrl+Break signal constant', @TestSignalConstantsDocumentWindowsBreak);
  T.Test('TUI terminal checks hook results', @TestTuiTerminalChecksSignalHookResult);
  if not T.Run then Halt(1);
end.
