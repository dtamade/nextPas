program test_fs_watch_wine;

{ L2 fs.watch Windows host / Wine evidence.
  - Wine: create/multi may soft-residual.
  - Real Windows (GHA): create + two-dir multi-path hard after platform RDCW fix.
  truth=wine-runtime-smoke when under Wine; real-windows when native. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.fs.watch,
  nextpas.core.path,
  nextpas.core.platform.process,
  nextpas.core.text.conv
{$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base
  , nextpas.core.platform.windows.ffi
{$ENDIF}
  ;

var
  T: TTestSuite;
  GUnderWine: Boolean;

{$IFDEF NEXTPAS_WINDOWS}

function RunningUnderWine: Boolean;
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

procedure SoftOrHard(AGot: Boolean; const AName: string);
begin
  if AGot then
    Check(True, AName)
  else if GUnderWine then
  begin
    WriteLn('  ~ ', AName, ' residual under Wine (soft)');
    Check(True, AName + ' (wine soft path exercised)');
  end
  else
    Check(False, AName + ' (hard on real Windows)');
end;

procedure TestWatchCreateClose;
var
  W: IFsWatcher;
begin
  W := Watch;
  Check(W <> nil, 'Watch non-nil');
  W.Close;
end;

procedure TestWatchPollTimeout;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  GTmp: string;
begin
  GTmp := GetTempDir + '/np_fsw_w' + IntToStr(platform_getpid);
  MkdirAll(GTmp);
  try
    W := Watch;
    W.Add(GTmp);
    Check(not W.Poll(E, TDuration.FromMilliseconds(80)), 'poll timeout False');
    W.Close;
  finally
    RemoveAll(GTmp);
  end;
end;

procedure TestWatchCreateEvent;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  GTmp: string;
  Got: Boolean;
  I: Integer;
begin
  GTmp := GetTempDir + '/np_fsw_e' + IntToStr(platform_getpid);
  MkdirAll(GTmp);
  try
    W := Watch;
    W.Add(GTmp);
    WriteFileText(GTmp + '/probe.txt', 'x');
    Got := False;
    for I := 1 to 40 do
      if W.Poll(E, TDuration.FromMilliseconds(100)) then
      begin
        Got := E.Created or E.Modified;
        if Got then
          Break;
      end;
    SoftOrHard(Got, 'L2 create event');
    W.Close;
  finally
    RemoveAll(GTmp);
  end;
end;

procedure TestWatchTwoDirMultiPath;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  A, B: string;
  N, I: Integer;
begin
  A := GetTempDir + '/np_fsw_a' + IntToStr(platform_getpid);
  B := GetTempDir + '/np_fsw_b' + IntToStr(platform_getpid);
  MkdirAll(A);
  MkdirAll(B);
  try
    W := Watch;
    W.Add(A);
    W.Add(B);
    WriteFileText(A + '/fa.txt', '1');
    WriteFileText(B + '/fb.txt', '2');
    N := 0;
    for I := 1 to 50 do
      if W.Poll(E, TDuration.FromMilliseconds(100)) then
      begin
        Inc(N);
        if N >= 2 then
          Break;
      end;
    SoftOrHard(N >= 2, 'L2 two-dir multi-path events');
    W.Remove(B);
    W.Close;
  finally
    RemoveAll(A);
    RemoveAll(B);
  end;
end;

{$ELSE}

procedure TestSkipHost;
begin
  Check(True, 'host is not Windows; wine suite is cross-target only');
end;

{$ENDIF}

begin
{$IFDEF NEXTPAS_WINDOWS}
  GUnderWine := RunningUnderWine;
  if GUnderWine then
    WriteLn('fs.watch L2: host=wine; create/multi may soft')
  else
    WriteLn('fs.watch L2: host=real-windows; create/multi hard');
{$ENDIF}
  T := TTestSuite.Create('fs.watch L2 wine-runtime-smoke');
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('create close', @TestWatchCreateClose);
  T.Test('poll timeout', @TestWatchPollTimeout);
  T.Test('create event', @TestWatchCreateEvent);
  T.Test('two-dir multi-path', @TestWatchTwoDirMultiPath);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
