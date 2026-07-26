program test_platform_console;

{$I nextpas.core.settings.inc}

uses

  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.platform.console,
  nextpas.core.platform.pipe,
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi,
  {$ENDIF}
  nextpas.core.test;

var
  T: TTestSuite;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := '../../../' + ARelativePath;
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  Result := LowerCase(FsReadFileText(LSourcePath));
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

procedure TestGetSizeFd;
var
  Size: TPlatformConsoleSize;
  R: Int32;
begin
  R := platform_console_get_size_fd(1, Size);
  if platform_console_is_terminal(1) then
  begin
    Check(R = 0, 'get_size_fd(1) returns 0 on terminal');
    Check(Size.Cols > 0, 'cols > 0');
    Check(Size.Rows > 0, 'rows > 0');
  end
  else
    Check(True, 'not a terminal, skip size check');
end;

procedure TestSetRawRestore;
var
  LMode: TPlatformConsoleMode;
begin
  // set_raw on non-terminal should fail gracefully
  if not platform_console_is_terminal(0) then
  begin
    Check(platform_console_set_raw(0, LMode) <> 0, 'set_raw on non-terminal fails');
    Check(True, 'set_raw on non-terminal handled gracefully');
  end
  else
  begin
    // On terminal: set_raw then restore
    Check(platform_console_set_raw(0, LMode) = 0, 'set_raw succeeds');
    Check(platform_console_restore_raw(0, LMode) = 0, 'restore_raw succeeds');
  end;
end;

procedure TestWriteStdout;
var
  LBuf: array[0..3] of AnsiChar;
  R: Int32;
begin
  LBuf[0] := 't'; LBuf[1] := 'e'; LBuf[2] := 's'; LBuf[3] := 't';
  R := platform_console_write(1, @LBuf[0], 4);
  Check(R = 4, 'write to stdout returns 4');
end;

procedure TestWriteInvalidFd;
var
  LBuf: array[0..3] of AnsiChar;
  R: Int32;
begin
  LBuf[0] := 't'; LBuf[1] := 'e'; LBuf[2] := 's'; LBuf[3] := 't';
  R := platform_console_write(-1, @LBuf[0], 4);
  Check(R = -1, 'write to invalid fd returns -1 sentinel');
end;

procedure TestWaitReadablePipe;
var
  P: TPlatformPipe;
  LWait: TPlatformConsoleWait;
begin
  Check(platform_pipe_create(P) = 0, 'create pipe');
  // No data available, should timeout quickly
  LWait := platform_console_wait_readable(P.ReadFd, 10);
  Check(LWait = cwTimeout, 'wait with timeout returns cwTimeout');
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
  CheckContains(LWindowsBranch, 'exit(-1)',
    'Windows console read/write failures must use value/sentinel -1');
  CheckContains(LWindowsBranch, 'value/sentinel',
    'Windows console read/write must document value/sentinel semantics');
  CheckAbsent(LWindowsBranch, 'windows raw mode / io / wait',
    'Windows console branch must not document raw/io/wait as stubs');
end;

procedure TestPosixConsoleUnixSourceContract;
var
  LConsole: string;
begin
  LConsole := LoadSourceText('src/nextpas.core.platform.console.pas');
  CheckContains(LConsole, 'posix (linux/macos/freebsd)',
    'console docs must state POSIX path for Linux/macOS/FreeBSD');
  CheckContains(LConsole, 'platform_console_read/write are value/sentinel',
    'console docs must lock value/sentinel read/write contract');
  CheckContains(LConsole, 'nextpas_macos',
    'console must wire Darwin host base for termios');
  CheckContains(LConsole, 'nextpas_freebsd',
    'console must wire FreeBSD host base for termios');
end;

procedure TestConsoleReadWriteValueSentinelSourceContract;
var
  LConsole: string;
begin
  LConsole := LoadSourceText('src/nextpas.core.platform.console.pas');
  CheckContains(LConsole, 'exit(-1)',
    'console read/write must fail with -1 sentinel');
  CheckContains(LConsole, 'never return positive platform_err_*',
    'console docs must forbid positive PLATFORM_ERR_* as byte counts');
  CheckAbsent(LConsole, 'exit(platform_get_errno)',
    'console read/write must not return raw errno as byte count');
end;

procedure TestReadFromPipe;
var
  LPipe: TPlatformPipe;
  LBuf: array[0..31] of AnsiChar;
  LWritten: PtrInt;
  LRead: Int32;
begin
  Check(platform_pipe_create(LPipe) = 0, 'create pipe');

  { Write data to pipe using low-level write }
{$IFDEF NEXTPAS_UNIX}
  LWritten := write(Int32(LPipe.WriteFd), PAnsiChar('test'), 4);
  Check(LWritten = 4, 'wrote 4 bytes to pipe');
{$ENDIF}

  { Read from pipe using console_read }
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := platform_console_read(LPipe.ReadFd, @LBuf[0], 4);
  Check(LRead = 4, 'console_read returns 4 bytes');
  Check(LBuf[0] = 't', 'first byte = t');
  Check(LBuf[3] = 't', 'last byte = t');

  platform_pipe_close(LPipe);
end;

procedure TestWriteNilBuffer;
var
  R: Int32;
begin
  R := platform_console_write(1, nil, 4);
  Check(R = -1, 'write nil buffer returns -1 sentinel');
end;

procedure TestWriteZeroLength;
var
  LBuf: array[0..3] of AnsiChar;
  R: Int32;
begin
  LBuf[0] := 't';
  R := platform_console_write(1, @LBuf[0], 0);
  Check(R = 0, 'write zero length returns 0');
end;

procedure TestReadZeroLength;
var
  LBuf: array[0..3] of AnsiChar;
  R: Int32;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);
  R := platform_console_read(0, @LBuf[0], 0);
  Check(R = 0, 'read zero length returns 0');
end;

procedure TestReadNilBuffer;
var
  R: Int32;
begin
  { On Unix, read(nil) may return -1 (EFAULT) or crash; just verify it doesn't hang }
  R := platform_console_read(0, nil, 4);
  Check(True, 'read nil buffer did not hang');
end;

procedure TestWaitReadableInvalidFd;
var
  LWait: TPlatformConsoleWait;
begin
  LWait := platform_console_wait_readable(-1, 10);
  { On some systems, invalid fd may return cwTimeout instead of cwError }
  Check(LWait in [cwError, cwTimeout], 'wait on invalid fd returns error or timeout');
end;

procedure TestGetSizeInvalidFd;
var
  Size: TPlatformConsoleSize;
  R: Int32;
begin
  R := platform_console_get_size_fd(-1, Size);
  Check(R <> 0, 'get_size on invalid fd fails');
end;

procedure TestSetRawInvalidFd;
var
  LMode: TPlatformConsoleMode;
  R: Int32;
begin
  R := platform_console_set_raw(-1, LMode);
  Check(R <> 0, 'set_raw on invalid fd fails');
end;

procedure TestWriteLargeBuffer;
var
  Buf: array[0..4095] of AnsiChar;
  R: Int32;
  I: Integer;
begin
  for I := 0 to 4095 do
    Buf[I] := AnsiChar(Ord('A') + (I mod 26));
  R := platform_console_write(1, @Buf[0], 4096);
  Check(R >= 0, 'write large buffer succeeds');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.console');
  T.Test('is_terminal stdout', @TestIsTerminalStdout);
  T.Test('invalid fd', @TestInvalidFd);
  T.Test('get size', @TestGetSize);
  T.Test('enable ansi', @TestEnableAnsi);
  T.Test('pipe not terminal', @TestPipeNotTerminal);
  T.Test('Windows console source contract', @TestWindowsConsoleSourceContract);
  T.Test('POSIX console Unix source contract',
    @TestPosixConsoleUnixSourceContract);
  T.Test('console read/write value/sentinel source contract',
    @TestConsoleReadWriteValueSentinelSourceContract);
  T.Test('get size fd', @TestGetSizeFd);
  T.Test('set raw / restore raw', @TestSetRawRestore);
  T.Test('write stdout', @TestWriteStdout);
  T.Test('write invalid fd', @TestWriteInvalidFd);
  T.Test('wait readable pipe', @TestWaitReadablePipe);
  T.Test('read from pipe', @TestReadFromPipe);
  T.Test('write nil buffer', @TestWriteNilBuffer);
  T.Test('write zero length', @TestWriteZeroLength);
  T.Test('read zero length', @TestReadZeroLength);
  T.Test('read nil buffer', @TestReadNilBuffer);
  T.Test('wait readable invalid fd', @TestWaitReadableInvalidFd);
  T.Test('get size invalid fd', @TestGetSizeInvalidFd);
  T.Test('set_raw invalid fd', @TestSetRawInvalidFd);
  T.Test('write large buffer', @TestWriteLargeBuffer);
  if not T.Run then Halt(1);
end.
