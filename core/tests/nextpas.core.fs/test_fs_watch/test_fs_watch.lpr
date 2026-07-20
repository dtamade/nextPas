program test_fs_watch;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.fs.watch,
  nextpas.core.platform.process,
  nextpas.core.text.conv;

var
  T: TTestSuite;
  GTmp: string;

procedure Setup;
begin
  GTmp := '/tmp/nextpas_fswatch_' + IntToStr(platform_getpid);
  MkdirAll(GTmp);
end;

procedure Cleanup;
begin
  RemoveAll(GTmp);
end;

procedure TestWatchCreateClose;
var
  W: IFsWatcher;
begin
  W := Watch;
  Check(W <> nil, 'Watch non-nil');
  W.Close;
end;

procedure TestWatchTimeout;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
begin
  W := Watch;
  W.Add(GTmp);
  Check(not W.Poll(E, TDuration.FromMilliseconds(50)), 'timeout False');
  W.Close;
end;

procedure TestWatchCreateEvent;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  Got: Boolean;
  I: Integer;
begin
  W := Watch;
  W.Add(GTmp);
  WriteFileText(GTmp + '/created.txt', 'hi');
  Got := False;
  for I := 1 to 20 do
  begin
    if W.Poll(E, TDuration.FromMilliseconds(100)) then
    begin
      Got := True;
      Break;
    end;
  end;
  Check(Got, 'received watch event after create');
  Check(E.Created or E.Modified or (E.Name <> ''), 'event has content');
  W.Close;
end;

procedure TestWatchEmptyPathRaises;
var
  W: IFsWatcher;
  Raised: Boolean;
begin
  W := Watch;
  Raised := False;
  try
    W.Add('');
  except
    on E: EArgumentError do
      Raised := True;
  end;
  Check(Raised, 'empty path raises');
  W.Close;
end;

begin
  Setup;
  try
    T := TTestSuite.Create('nextpas.core.fs.watch');
    T.Test('create close', @TestWatchCreateClose);
    T.Test('poll timeout', @TestWatchTimeout);
    T.Test('create event', @TestWatchCreateEvent);
    T.Test('empty path', @TestWatchEmptyPathRaises);
    if not T.Run then Halt(1);
  finally
    Cleanup;
  end;
end.
