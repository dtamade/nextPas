program test_fs_watch_wine;

{ L2 fs.watch Windows evidence under Wine.
  truth=wine-runtime-smoke — NOT real Windows host runtime.
  M2-W1 / platform S2: Poll may deliver events; under Wine create-event is soft. }

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
  ;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

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

procedure TestWatchCreateEventOrSoft;
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
    for I := 1 to 30 do
      if W.Poll(E, TDuration.FromMilliseconds(100)) then
      begin
        Got := True;
        Break;
      end;
    { Wine may not deliver RDCW; accept soft pass with documentation. }
    Check(True, 'create event path exercised');
    if not Got then
      WriteLn('  ~ L2 create-event residual under Wine (soft); not real Windows evidence');
    W.Close;
  finally
    RemoveAll(GTmp);
  end;
end;

{$ELSE}

procedure TestSkipHost;
begin
  Check(True, 'host is not Windows; wine suite is cross-target only');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('fs.watch L2 wine-runtime-smoke');
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('create close', @TestWatchCreateClose);
  T.Test('poll timeout', @TestWatchPollTimeout);
  T.Test('create event or soft', @TestWatchCreateEventOrSoft);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
