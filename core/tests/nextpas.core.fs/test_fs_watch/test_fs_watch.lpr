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

function PollAny(const W: IFsWatcher; out E: TFsWatchEvent;
  const ATries: Integer = 30): Boolean;
var
  I: Integer;
begin
  for I := 1 to ATries do
    if W.Poll(E, TDuration.FromMilliseconds(100)) then
      Exit(True);
  Result := False;
end;

function PollMatch(const W: IFsWatcher; const ASubstr: string;
  out E: TFsWatchEvent; const ATries: Integer = 40): Boolean;
var
  I: Integer;
begin
  for I := 1 to ATries do
    if W.Poll(E, TDuration.FromMilliseconds(100)) then
      if (ASubstr = '') or (Pos(ASubstr, E.Name) > 0) then
        Exit(True);
  Result := False;
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
begin
  W := Watch;
  W.Add(GTmp);
  WriteFileText(GTmp + '/created.txt', 'hi');
  Check(PollAny(W, E), 'received watch event after create');
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

procedure TestWatchMultiPathDisambiguate;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  D1, D2: string;
begin
  D1 := GTmp + '/m1';
  D2 := GTmp + '/m2';
  MkdirAll(D1);
  MkdirAll(D2);
  W := Watch;
  W.Add(D1);
  W.Add(D2);
  WriteFileText(D1 + '/a.txt', '1');
  Check(PollMatch(W, 'm1', E), 'multi-path saw m1 event path');
  WriteFileText(D2 + '/b.txt', '2');
  Check(PollMatch(W, 'm2', E), 'multi-path saw m2 event path');
  W.Close;
end;

procedure TestWatchDeleteEvent;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  P: string;
  Got: Boolean;
begin
  P := GTmp + '/todel.txt';
  WriteFileText(P, 'x');
  W := Watch;
  W.Add(GTmp);
  Remove(P);
  Got := PollMatch(W, 'todel', E);
  Check(Got, 'delete event received');
  Check(E.Deleted or (Pos('todel', E.Name) > 0), 'delete flag or name');
  W.Close;
end;

procedure TestWatchModifyEvent;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  P: string;
  Got: Boolean;
begin
  P := GTmp + '/mod.txt';
  WriteFileText(P, 'v1');
  W := Watch;
  W.Add(GTmp);
  WriteFileText(P, 'v2-longer');
  Got := PollMatch(W, 'mod', E);
  Check(Got, 'modify event received');
  Check(E.Modified or E.Created or (Pos('mod', E.Name) > 0),
    'modify-related flags');
  W.Close;
end;

procedure TestAddTreeNestedCreate;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  Nested: string;
  Got: Boolean;
begin
  Nested := GTmp + '/tree/a/b';
  MkdirAll(Nested);
  W := Watch;
  W.AddTree(GTmp + '/tree');
  WriteFileText(Nested + '/leaf.txt', 'deep');
  Got := PollMatch(W, 'leaf', E);
  Check(Got, 'AddTree nested create event');
  Check(Pos('tree', E.Name) > 0, 'event path under tree');
  W.Close;
end;

procedure TestAddTreeNotDirRaises;
var
  W: IFsWatcher;
  Raised: Boolean;
  F: string;
begin
  F := GTmp + '/notadir.txt';
  WriteFileText(F, 'x');
  W := Watch;
  Raised := False;
  try
    W.AddTree(F);
  except
    on E: EArgumentError do
      Raised := True;
  end;
  Check(Raised, 'AddTree on file raises');
  W.Close;
end;

procedure TestAddTreeAutoMount;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  Root, NewDir: string;
  Got: Boolean;
begin
  Root := GTmp + '/auto';
  MkdirAll(Root);
  W := Watch;
  W.AddTree(Root);
  NewDir := Root + '/later';
  MkdirAll(NewDir);
  { drain mkdir event (may auto-mount) }
  PollAny(W, E, 10);
  WriteFileText(NewDir + '/late.txt', 'y');
  Got := PollMatch(W, 'late', E);
  Check(Got, 'auto-mount after runtime mkdir sees file');
  W.Close;
end;

procedure TestClosedWatcherRaises;
var
  W: IFsWatcher;
  E: TFsWatchEvent;
  Raised: Boolean;
begin
  W := Watch;
  W.Close;
  Raised := False;
  try
    W.Add(GTmp);
  except
    on Ex: EInvalidOperationError do
      Raised := True;
  end;
  Check(Raised, 'Add after Close raises');
  Raised := False;
  try
    W.Poll(E, TDuration.FromMilliseconds(10));
  except
    on Ex: EInvalidOperationError do
      Raised := True;
  end;
  Check(Raised, 'Poll after Close raises');
end;

begin
  Setup;
  try
    T := TTestSuite.Create('nextpas.core.fs.watch');
    T.Test('create close', @TestWatchCreateClose);
    T.Test('poll timeout', @TestWatchTimeout);
    T.Test('create event', @TestWatchCreateEvent);
    T.Test('empty path', @TestWatchEmptyPathRaises);
    T.Test('multi path disambiguate', @TestWatchMultiPathDisambiguate);
    T.Test('delete event', @TestWatchDeleteEvent);
    T.Test('modify event', @TestWatchModifyEvent);
    T.Test('AddTree nested create', @TestAddTreeNestedCreate);
    T.Test('AddTree not dir', @TestAddTreeNotDirRaises);
    T.Test('AddTree auto-mount', @TestAddTreeAutoMount);
    T.Test('closed raises', @TestClosedWatcherRaises);
    if not T.Run then
      Halt(1);
  finally
    Cleanup;
  end;
end.
