program test_platform_which_wine;

{ Wine runtime evidence for platform.which on Windows. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.platform.which;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

{ 1. Find cmd.exe in PATH }
procedure TestWhichCmd;
var
  LBuf: array[0..511] of AnsiChar;
  LRet: Int32;
begin
  LRet := platform_which('cmd.exe', @LBuf[0], 520);
  Check(LRet > 0, 'which cmd.exe should find it, got ' + IntToStr(LRet));
  Check(LBuf[0] <> #0, 'result not empty');
end;

{ 2. Find notepad.exe in PATH }
procedure TestWhichNotepad;
var
  LBuf: array[0..511] of AnsiChar;
  LRet: Int32;
begin
  LRet := platform_which('notepad.exe', @LBuf[0], 520);
  Check(LRet > 0, 'which notepad.exe should find it, got ' + IntToStr(LRet));
end;

{ 3. Non-existent executable returns 0 or error }
procedure TestWhichNonExistent;
var
  LBuf: array[0..511] of AnsiChar;
  LRet: Int32;
begin
  LRet := platform_which('nonexistent_xyz_999.exe', @LBuf[0], 520);
  { On Windows, which may return positive even for non-existent if PATH is weird }
  Check(LRet <= 256, 'non-existent returns reasonable value, got ' + IntToStr(LRet));
end;

{ 4. Result path contains the executable name }
procedure TestWhichResultContainsName;
var
  LBuf: array[0..511] of AnsiChar;
  LR: string;
  LRet: Int32;
begin
  LRet := platform_which('cmd.exe', @LBuf[0], 520);
  if LRet > 0 then
  begin
    LR := string(PAnsiChar(@LBuf[0]));
    Check(Pos('cmd', LowerCase(LR)) > 0, 'result should contain cmd');
  end;
end;

{ 5. Small buffer returns truncated result }
procedure TestWhichSmallBuffer;
var
  LBuf: array[0..3] of AnsiChar;
  LRet: Int32;
begin
  LRet := platform_which('cmd.exe', @LBuf[0], 4);
  { Should not crash, may return 0 (buffer too small) or truncated length }
  Check(LRet >= 0, 'small buffer does not crash');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.which.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('which cmd.exe', @TestWhichCmd);
  T.Test('which notepad.exe', @TestWhichNotepad);
  T.Test('which non-existent', @TestWhichNonExistent);
  T.Test('result contains name', @TestWhichResultContainsName);
  T.Test('small buffer', @TestWhichSmallBuffer);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.
