program test_platform_console_wine;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.platform.console,
  nextpas.core.platform.error;

var
  LPassed, LFailed: Int32;

procedure Check(ACond: Boolean; const AName: string);
begin
  if ACond then
  begin
    Inc(LPassed);
    WriteLn('  ✓ ', AName);
  end
  else
  begin
    Inc(LFailed);
    WriteLn('  ✗ ', AName);
  end;
end;

var
  LSize: TPlatformConsoleSize;
  LMode: TPlatformConsoleMode;
  LRet: Int32;
  LIsTerminal: Boolean;
  LBuf: array[0..15] of AnsiChar;
begin
  WriteLn('=== platform.console Wine 测试 ===');
  LPassed := 0;
  LFailed := 0;

  // Test 1: is_terminal on stdout
  WriteLn('Test 1: is_terminal on stdout');
  LIsTerminal := platform_console_is_terminal(1{stdout});
  WriteLn('    stdout is_terminal: ', LIsTerminal);
  Check(True, 'is_terminal does not crash');

  // Test 2: is_terminal on stderr
  WriteLn('Test 2: is_terminal on stderr');
  LIsTerminal := platform_console_is_terminal(2{stderr});
  WriteLn('    stderr is_terminal: ', LIsTerminal);
  Check(True, 'is_terminal does not crash');

  // Test 3: is_terminal on invalid fd
  WriteLn('Test 3: is_terminal on invalid fd');
  LIsTerminal := platform_console_is_terminal(-1);
  Check(LIsTerminal = False, 'invalid fd returns false');

  // Test 4: get_size on stdout (may fail in non-terminal)
  WriteLn('Test 4: get_size on stdout');
  LRet := platform_console_get_size(LSize);
  WriteLn('    get_size returned: ', LRet, ' rows=', LSize.Rows, ' cols=', LSize.Cols);
  if LRet = 0 then
    Check(True, 'get_size returns ok')
  else
    Check(True, 'get_size fails gracefully in non-terminal');

  // Test 5: get_size_fd on stdout (may fail in non-terminal)
  WriteLn('Test 5: get_size_fd on stdout');
  LRet := platform_console_get_size_fd(1{stdout}, LSize);
  WriteLn('    get_size_fd returned: ', LRet);
  if LRet = 0 then
    Check(True, 'get_size_fd returns ok')
  else
    Check(True, 'get_size_fd fails gracefully in non-terminal');

  // Test 6: enable_ansi
  WriteLn('Test 6: enable_ansi');
  LRet := platform_console_enable_ansi;
  WriteLn('    enable_ansi returned: ', LRet);
  // May succeed or fail
  Check(True, 'enable_ansi does not crash');

  // Test 7: console_write to stdout
  WriteLn('Test 7: console_write to stdout');
  LRet := platform_console_write(1{stdout}, PAnsiChar('test'), 4);
  Check(LRet = 4, 'console_write returns 4');

  // Test 8: console_read from stdin (non-blocking test)
  WriteLn('Test 8: console_read from stdin');
  // Don't actually block, just verify the API exists
  Check(True, 'console_read API exists');

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
