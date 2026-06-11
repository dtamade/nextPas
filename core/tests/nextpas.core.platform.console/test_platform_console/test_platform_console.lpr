program test_platform_console;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.platform.console,
  nextpas.core.platform.pipe,
  nextpas.core.testing;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
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

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestIsTerminalStdout;
begin
  // In CI, stdout may not be a terminal — just verify it doesn't crash
  platform_console_is_terminal(1);
  Check(True, 'is_terminal(1) did not crash');
end;

procedure TestInvalidFd;
begin
  Check(not platform_console_is_terminal(-1), 'fd=-1 not terminal');
  Check(not platform_console_is_terminal(999), 'fd=999 not terminal');
end;

procedure TestGetSize;
var
  Size: TPlatformConsoleSize;
  R: Int32;
begin
  R := platform_console_get_size(Size);
  if platform_console_is_terminal(1) then
  begin
    Check(R = 0, 'get_size returns 0 on terminal');
    Check(Size.Cols > 0, 'cols > 0');
    Check(Size.Rows > 0, 'rows > 0');
  end
  else
    Check(True, 'not a terminal, skip size check');
end;

procedure TestEnableAnsi;
begin
  // On POSIX this is a no-op, always returns 0
  Check(platform_console_enable_ansi = 0, 'enable_ansi returns 0');
end;

procedure TestPipeNotTerminal;
var
  P: TPlatformPipe;
begin
  Check(platform_pipe_create(P) = 0, 'create pipe');
  Check(not platform_console_is_terminal(P.ReadFd), 'pipe read not terminal');
  Check(not platform_console_is_terminal(P.WriteFd), 'pipe write not terminal');
  platform_pipe_close(P);
end;

procedure TestWindowsConsoleSourceContract;
var
  LConsole: string;
  LWindowsBranch: string;
begin
  LConsole := LoadSourceText('src/nextpas.core.platform.console.pas');
  LWindowsBranch := SliceBetween(LConsole, '{$ifdef nextpas_windows}',
    '{$if not defined(nextpas_unix) and not defined(nextpas_windows)}');

  CheckContains(LWindowsBranch, 'function windowsconsolehandlefromfd',
    'Windows console must map public std fds to standard handles internally');
  CheckContains(LWindowsBranch, 'std_input_handle',
    'Windows console must use STD_INPUT_HANDLE for fd 0');
  CheckContains(LWindowsBranch, 'std_output_handle',
    'Windows console must use STD_OUTPUT_HANDLE for fd 1');
  CheckContains(LWindowsBranch, 'std_error_handle',
    'Windows console must use STD_ERROR_HANDLE for fd 2');
  CheckContains(LWindowsBranch, 'enable_virtual_terminal_input',
    'Windows raw mode must enable virtual-terminal input');
  CheckContains(LWindowsBranch, 'enable_line_input',
    'Windows raw mode must disable line input');
  CheckContains(LWindowsBranch, 'enable_echo_input',
    'Windows raw mode must disable echo input');
  CheckContains(LWindowsBranch, 'readfile(',
    'Windows console read must use nextPas-owned ReadFile binding');
  CheckContains(LWindowsBranch, 'writefile(',
    'Windows console write must use nextPas-owned WriteFile binding');
  CheckContains(LWindowsBranch, 'waitforsingleobject',
    'Windows console wait must use WaitForSingleObject');
  CheckContains(LWindowsBranch, 'cwtimeout',
    'Windows console wait must map timeout result');
  CheckContains(LWindowsBranch, 'error_invalid_handle',
    'invalid Windows std fd must return stable invalid-handle semantics');
  CheckAbsent(LWindowsBranch, 'windows raw mode / io / wait',
    'Windows console branch must not document raw/io/wait as stubs');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.console');
  T.Run('is_terminal stdout', @TestIsTerminalStdout);
  T.Run('invalid fd', @TestInvalidFd);
  T.Run('get size', @TestGetSize);
  T.Run('enable ansi', @TestEnableAnsi);
  T.Run('pipe not terminal', @TestPipeNotTerminal);
  T.Run('Windows console source contract', @TestWindowsConsoleSourceContract);
  T.Summary;
end.
