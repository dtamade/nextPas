program test_platform_console_wine;

{ Windows host / Wine smoke for platform.console (ci-matrix gate).
  Hard asserts: invalid fd / nil write / write 4 bytes → value/sentinel -1.
  Soft: is_terminal/get_size when not a real console. }

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.console,
  nextpas.core.platform.error
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base
  , nextpas.core.platform.windows.ffi
  {$ENDIF}
  ;

var
  LPassed, LFailed: Int32;
  LUnderWine: Boolean;

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

function RunningUnderWine: Boolean;
{$IFDEF NEXTPAS_WINDOWS}
var
  LNtdll: HMODULE;
  LProc: FARPROC;
begin
  LNtdll := GetModuleHandleW(PWideChar(UnicodeString('ntdll.dll')));
  if (LNtdll = nil) or (LNtdll = HMODULE(PtrInt(-1))) then
    Exit(False);
  LProc := GetProcAddress(LNtdll, 'wine_get_version');
  Result := LProc <> nil;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

var
  LSize: TPlatformConsoleSize;
  LRet: Int32;
  LIsTerminal: Boolean;
begin
  WriteLn('=== platform.console Windows/Wine smoke ===');
  LPassed := 0;
  LFailed := 0;
  LUnderWine := RunningUnderWine;
  if LUnderWine then
    WriteLn('truth=wine-runtime-smoke; not real Windows runtime ready')
  else
    WriteLn('truth=ci-matrix-host; hard value/sentinel asserts');

  WriteLn('Test 1: is_terminal on stdout');
  LIsTerminal := platform_console_is_terminal(1);
  WriteLn('    stdout is_terminal: ', LIsTerminal);
  Check(True, 'is_terminal does not crash');

  WriteLn('Test 2: is_terminal on invalid fd');
  Check(not platform_console_is_terminal(-1), 'invalid fd is_terminal false');

  WriteLn('Test 3: get_size on stdout');
  LRet := platform_console_get_size(LSize);
  WriteLn('    get_size returned: ', LRet, ' rows=', LSize.Rows, ' cols=', LSize.Cols);
  Check(True, 'get_size does not crash');

  WriteLn('Test 4: enable_ansi');
  LRet := platform_console_enable_ansi;
  Check(LRet = 0, 'enable_ansi returns 0');

  WriteLn('Test 5: console_write stdout (hard)');
  LRet := platform_console_write(1, PAnsiChar('test'), 4);
  Check(LRet = 4, 'console_write returns 4');

  WriteLn('Test 6: console_write nil (hard value/sentinel)');
  LRet := platform_console_write(1, nil, 4);
  Check(LRet = -1, 'nil write returns -1');

  WriteLn('Test 7: console_write invalid fd (hard value/sentinel)');
  LRet := platform_console_write(-1, PAnsiChar('x'), 1);
  Check(LRet = -1, 'invalid fd write returns -1');

  WriteLn('Test 8: console_read zero length');
  LRet := platform_console_read(0, nil, 0);
  Check(LRet = 0, 'read zero length returns 0');

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
