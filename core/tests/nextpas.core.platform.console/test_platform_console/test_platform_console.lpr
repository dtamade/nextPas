program test_platform_console;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.console,
  nextpas.core.platform.pipe,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.platform.console');
  T.Run('is_terminal stdout', @TestIsTerminalStdout);
  T.Run('invalid fd', @TestInvalidFd);
  T.Run('get size', @TestGetSize);
  T.Run('enable ansi', @TestEnableAnsi);
  T.Run('pipe not terminal', @TestPipeNotTerminal);
  T.Summary;
end.
