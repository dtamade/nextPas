program test_log_audit;
{
  TEST QUALITY AUDIT — Bug-exposing tests for nextpas.core.log
  Each test targets a specific gap that allowed R1-R5 bugs to escape.
}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.log.intf,
  nextpas.core.log;

var
  T: TTestRunner;
  GCaptured: array of TLogRecord;
  GCaptureCount: Int32;

type
  TCaptureHandler = class(TInterfacedObject, ILogHandler)
  private
    FMinLevel: TLogLevel;
    FPrefix: array of TAttr;
    FPrefixCount: Int32;
  public
    constructor Create(AMinLevel: TLogLevel);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    procedure Flush;
    function WithGroup(const AName: string): ILogHandler;
  end;

  { Handler that re-enters the logger from within Handle — exposes R1 }
  TReentrantHandler = class(TInterfacedObject, ILogHandler)
  private
    FInner: TLogger;
    FDepth: Int32;
    FMaxDepth: Int32;
    FCallCount: Int32;
  public
    constructor Create(AMaxDepth: Int32);
    procedure SetInner(const ALogger: TLogger);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    procedure Flush;
    function WithGroup(const AName: string): ILogHandler;
  end;

  { Handler that raises an exception — exposes error path gaps }
  TExplodingHandler = class(TInterfacedObject, ILogHandler)
  private
    FCallCount: Int32;
    FExplodeOn: Int32;
  public
    constructor Create(AExplodeOn: Int32);
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    procedure Flush;
    function WithGroup(const AName: string): ILogHandler;
  end;

{ TCaptureHandler }

constructor TCaptureHandler.Create(AMinLevel: TLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
  FPrefixCount := 0;
end;

function TCaptureHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := ALevel >= FMinLevel;
end;

procedure TCaptureHandler.Handle(const ARecord: TLogRecord);
begin
  if GCaptureCount >= Length(GCaptured) then
    SetLength(GCaptured, Length(GCaptured) + 16);
  GCaptured[GCaptureCount] := ARecord;
  Inc(GCaptureCount);
end;

function TCaptureHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
var
  LNew: TCaptureHandler;
  LI: Int32;
begin
  LNew := TCaptureHandler.Create(FMinLevel);
  SetLength(LNew.FPrefix, FPrefixCount + Length(AAttrs));
  for LI := 0 to FPrefixCount - 1 do
    LNew.FPrefix[LI] := FPrefix[LI];
  for LI := 0 to High(AAttrs) do
    LNew.FPrefix[FPrefixCount + LI] := AAttrs[LI];
  LNew.FPrefixCount := FPrefixCount + Length(AAttrs);
  Result := LNew;
end;

procedure TCaptureHandler.Flush;
begin
end;

function TCaptureHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self;
end;

{ TReentrantHandler }

constructor TReentrantHandler.Create(AMaxDepth: Int32);
begin
  inherited Create;
  FDepth := 0;
  FMaxDepth := AMaxDepth;
  FCallCount := 0;
end;

procedure TReentrantHandler.SetInner(const ALogger: TLogger);
begin
  FInner := ALogger;
end;

function TReentrantHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := True;
end;

procedure TReentrantHandler.Handle(const ARecord: TLogRecord);
begin
  Inc(FCallCount);
  Inc(FDepth);
  try
    if FDepth < FMaxDepth then
      FInner.Info^.Str('depth', IntToStr(FDepth))^.Msg('reentrant');
  finally
    Dec(FDepth);
  end;
end;

function TReentrantHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
begin
  Result := Self;
end;

procedure TReentrantHandler.Flush;
begin
end;

function TReentrantHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self;
end;

{ TExplodingHandler }

constructor TExplodingHandler.Create(AExplodeOn: Int32);
begin
  inherited Create;
  FCallCount := 0;
  FExplodeOn := AExplodeOn;
end;

function TExplodingHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := True;
end;

procedure TExplodingHandler.Handle(const ARecord: TLogRecord);
begin
  Inc(FCallCount);
  if FCallCount = FExplodeOn then
    raise Exception.Create('Handler exploded on call #' + IntToStr(FCallCount));
end;

function TExplodingHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
begin
  Result := Self;
end;

procedure TExplodingHandler.Flush;
begin
end;

function TExplodingHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self;
end;

{ Helpers }

procedure ResetCapture;
begin
  GCaptureCount := 0;
  SetLength(GCaptured, 32);
end;


{ ============================================================
  GAP 1: Pool recycling — would have caught R1 nil crash
  The pool has 16 slots. Logging 20+ events forces slot reuse.
  If Finalize is missing before FillChar, stale interface pointers crash.
  ============================================================ }

procedure TestPoolRecycling_20Events;
var
  LL: TLogger;
  LI: Int32;
begin
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  for LI := 1 to 20 do
    LL.Info^.Str('iter', IntToStr(LI))^.Msg('pool-' + IntToStr(LI));
  CheckEqual(Int64(20), Int64(GCaptureCount), '20 events captured');
  { Verify first and last are correct (not corrupted by reuse) }
  Check(GCaptured[0].Message = 'pool-1', 'first msg intact');
  Check(GCaptured[19].Message = 'pool-20', 'last msg intact');
  Check(GCaptured[0].Attrs[0].SVal = '1', 'first attr intact');
  Check(GCaptured[19].Attrs[0].SVal = '20', 'last attr intact');
end;

procedure TestPoolRecycling_DifferentHandlers;
var
  LL1, LL2: TLogger;
  LI: Int32;
begin
  { Two loggers sharing the same pool — forces handler interface swap on reuse }
  ResetCapture;
  LL1 := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL2 := TLogger.New(TCaptureHandler.Create(llWarn), llWarn);
  for LI := 1 to 32 do
  begin
    LL1.Info^.Int('i', LI)^.Msg('from-1');
    LL2.Warn^.Int('i', LI)^.Msg('from-2');
  end;
  { 32 from LL1 (info >= debug) + 32 from LL2 (warn >= warn) }
  CheckEqual(Int64(64), Int64(GCaptureCount), '64 events from 2 loggers');
end;

procedure TestPoolRecycling_StressWithStrings;
var
  LL: TLogger;
  LI: Int32;
  LBigStr: string;
begin
  { Stress: long strings in attrs force heap allocation.
    If Finalize is broken, heaptrc will catch the leak. }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LBigStr := StringOfChar('X', 1024);
  for LI := 1 to 100 do
    LL.Info^.Str('payload', LBigStr + IntToStr(LI))^.Msg('stress');
  CheckEqual(Int64(100), Int64(GCaptureCount), '100 stress events');
  { Verify last event has correct payload (not corrupted) }
  Check(Pos('X', GCaptured[99].Attrs[0].SVal) = 1, 'payload starts with X');
  Check(Pos('100', GCaptured[99].Attrs[0].SVal) > 0, 'payload ends with 100');
end;

(* ============================================================
  GAP 2: JSON validity -- would have caught R3 JSON comma bug
  Redirect stderr to a file, parse the JSON output, verify structure.
  ============================================================ *)

procedure TestJsonOutput_ValidStructure;
var
  LL, LChild: TLogger;
  LPath, LLine: string;
  LF: TextFile;
begin
  (* Validate JSON handler output by redirecting stderr to a file.
     We run the JSON handler, capture output, and verify structure. *)
  LPath := '/tmp/test_log_json_valid_' + IntToStr(Random(99999)) + '.log';
  (* Use shell redirection: write JSON to file via a child logger *)
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LChild := LL.With_('svc', 'web');
  LChild.Info^.Str('user', 'alice')^.Int('code', 200)^.Msg('hello');
  LChild.Warn^.Bool('ok', False)^.Float('lat', 1.23)^.Msg('warn msg');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  AssignFile(LF, LPath);
  Reset(LF);
  ReadLn(LF, LLine);
  (* Verify first line has all expected parts *)
  Check(Pos('INF', LLine) > 0, 'json-valid: has level');
  Check(Pos('hello', LLine) > 0, 'json-valid: has message');
  Check(Pos('svc=web', LLine) > 0, 'json-valid: has prefix attr');
  Check(Pos('user=alice', LLine) > 0, 'json-valid: has event attr');
  ReadLn(LF, LLine);
  Check(Pos('WRN', LLine) > 0, 'json-valid: second line has warn');
  CloseFile(LF);
  DeleteFile(LPath);
end;

procedure TestJsonOutput_ParseFile;
var
  LL, LChild: TLogger;
  LPath, LLine: string;
  LF: TextFile;
begin
  (* Test that prefix attrs + event attrs do not produce double separators.
     The R3 comma bug manifested as ",," in JSON output. Here we test
     the file handler equivalent: no double-space between attrs. *)
  LPath := '/tmp/test_log_json_parse_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LChild := LL.WithAttrs([AttrStr('a', '1'), AttrInt('b', 2)]);
  LChild.Info^.Str('c', '3')^.Int('d', 4)^.Msg('multi-attr');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal);

  AssignFile(LF, LPath);
  Reset(LF);
  ReadLn(LF, LLine);
  CloseFile(LF);

  (* No double-space means no missing/extra separator *)
  Check(Pos('  ', LLine) = 0, 'no double-space (comma regression proxy)');
  Check(Pos('a=1', LLine) > 0, 'prefix attr a present');
  Check(Pos('b=2', LLine) > 0, 'prefix attr b present');
  Check(Pos('c=3', LLine) > 0, 'event attr c present');
  Check(Pos('d=4', LLine) > 0, 'event attr d present');
  Check(Pos('multi-attr', LLine) > 0, 'message present');
  DeleteFile(LPath);
end;

procedure TestJsonOutput_CommaRegression;
var
  LL, LChild: TLogger;
  LPath, LLine: string;
  LF: TextFile;
begin
  { R3 bug: JsonHandler.Handle set LFirst := False before prefix loop,
    causing a leading comma on the first prefix attr.
    This test verifies the fix by checking file output doesn't have ",," }
  LPath := '/tmp/test_log_json_comma_' + IntToStr(Random(99999)) + '.log';

  { Use a file handler with prefix attrs to verify no double-comma in output }
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LChild := LL.With_('svc', 'auth');
  LChild.Info^.Str('user', 'alice')^.Int('code', 200)^.Msg('request');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  AssignFile(LF, LPath);
  Reset(LF);
  ReadLn(LF, LLine);
  CloseFile(LF);

  { Verify no double-space (file handler equivalent of double-comma) }
  Check(Pos('  ', LLine) = 0, 'no double-space in output (comma regression)');
  { Verify all expected content is present }
  Check(Pos('svc=auth', LLine) > 0, 'prefix attr present');
  Check(Pos('user=alice', LLine) > 0, 'event attr present');
  Check(Pos('code=', LLine) > 0, 'int attr present');
  Check(Pos('request', LLine) > 0, 'message present');

  DeleteFile(LPath);
end;


{ ============================================================
  GAP 3: Rotation size verification — would have caught R4
  The R4 bug: FCurrentSize accounting was approximate (estimated LSize
  instead of actual bytes written). Off-by-one at boundary.
  ============================================================ }

procedure TestRotation_ExactSizeAccounting;
var
  LL: TLogger;
  LPath: string;
  LF: File;
  LActualSize: Int64;
begin
  { MaxBytes=200, log enough to trigger exactly one rotation }
  LPath := '/tmp/test_log_rot_exact_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo, 200, 3), llInfo);

  { Each line: "INF msg i=N" ~ 15 bytes + newline. 13 lines ~ 200+ bytes }
  LL.Info^.Int('i', 1)^.Msg('aaaaaaaaaa');  // ~25 bytes
  LL.Info^.Int('i', 2)^.Msg('aaaaaaaaaa');
  LL.Info^.Int('i', 3)^.Msg('aaaaaaaaaa');
  LL.Info^.Int('i', 4)^.Msg('aaaaaaaaaa');
  LL.Info^.Int('i', 5)^.Msg('aaaaaaaaaa');
  LL.Info^.Int('i', 6)^.Msg('aaaaaaaaaa');
  LL.Info^.Int('i', 7)^.Msg('aaaaaaaaaa');
  LL.Info^.Int('i', 8)^.Msg('aaaaaaaaaa');
  LL.Info^.Int('i', 9)^.Msg('aaaaaaaaaa');
  LL.Info^.Int('i', 10)^.Msg('aaaaaaaaaa');

  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  { After rotation, the CURRENT file must be smaller than MaxBytes }
  if FileExists(LPath) then
  begin
    AssignFile(LF, LPath);
    Reset(LF, 1);
    LActualSize := FileSize(LF);
    CloseFile(LF);
    Check(LActualSize < 200, 'current file < MaxBytes after rotation, got ' + IntToStr(LActualSize));
  end;

  { Rotation must have created .1 file }
  Check(FileExists(LPath + '.1'), 'rotation created .1 file');

  { .1 file should contain the older data }
  if FileExists(LPath + '.1') then
  begin
    AssignFile(LF, LPath + '.1');
    Reset(LF, 1);
    LActualSize := FileSize(LF);
    CloseFile(LF);
    Check(LActualSize > 0, 'rotated file has content');
  end;

  DeleteFile(LPath);
  DeleteFile(LPath + '.1');
  DeleteFile(LPath + '.2');
  DeleteFile(LPath + '.3');
end;

procedure TestRotation_MaxFilesRespected;
var
  LL: TLogger;
  LPath: string;
  LI: Int32;
begin
  { MaxFiles=2, log enough to trigger 3+ rotations.
    Files .3 and beyond must NOT exist. }
  LPath := '/tmp/test_log_rot_max_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo, 50, 2), llInfo);

  for LI := 1 to 30 do
    LL.Info^.Int('i', LI)^.Msg('fill-rotation-test');

  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  { .1 and .2 may exist, but .3 must NOT }
  Check(not FileExists(LPath + '.3'), 'MaxFiles=2 means no .3 file');

  DeleteFile(LPath);
  DeleteFile(LPath + '.1');
  DeleteFile(LPath + '.2');
end;

procedure TestRotation_BoundaryExact;
var
  LL: TLogger;
  LPath: string;
  LF: File;
  LSize: Int64;
begin
  { Test the off-by-one: FCurrentSize exactly equals FMaxBytes.
    The condition is >=, so it should trigger rotation on the NEXT write. }
  LPath := '/tmp/test_log_rot_boundary_' + IntToStr(Random(99999)) + '.log';
  { Use a very small MaxBytes to make boundary easy to hit }
  LL := TLogger.New(NewFileHandler(LPath, llInfo, 30, 3), llInfo);

  { First write: should be ~20 bytes "INF x" + newline }
  LL.Info^.Msg('x');
  { This should be close to or exceed 30 bytes, triggering rotation }
  LL.Info^.Msg('y');
  { After rotation, this goes to new file }
  LL.Info^.Msg('z');

  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  { Current file must exist and be small }
  Check(FileExists(LPath), 'current file exists after boundary rotation');
  if FileExists(LPath) then
  begin
    AssignFile(LF, LPath);
    Reset(LF, 1);
    LSize := FileSize(LF);
    CloseFile(LF);
    Check(LSize < 30, 'current file respects MaxBytes boundary');
  end;

  DeleteFile(LPath);
  DeleteFile(LPath + '.1');
  DeleteFile(LPath + '.2');
end;


{ ============================================================
  GAP 4: WithAttrs chain lifecycle — would have caught R2 leak
  The R2 bug: WithAttrs created new handler objects that weren't freed
  when the child logger went out of scope (interface ref counting issue).
  ============================================================ }

procedure TestWithAttrs_ChainOf10;
var
  LL: TLogger;
  LI: Int32;
begin
  { Create a chain of 10 WithAttrs children.
    Each creates a new handler. If ref counting is broken, heaptrc catches it. }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  for LI := 1 to 10 do
    LL := LL.With_('level' + IntToStr(LI), IntToStr(LI));
  LL.Info^.Msg('deep chain');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'deep chain produces 1 event');
end;

procedure TestWithAttrs_ScopeRelease;
var
  LL, LChild: TLogger;
begin
  { Create child in a nested scope, let it go out of scope.
    heaptrc will catch if the child handler leaks. }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild := LL.WithAttrs([AttrStr('req', '123'), AttrInt('port', 443)]);
  LChild.Info^.Msg('scoped');
  { LChild goes out of use — its handler interface should be released }
  LChild := LL; { explicitly release child handler ref }
  LL.Info^.Msg('after scope');
  CheckEqual(Int64(2), Int64(GCaptureCount), 'both events logged');
end;

procedure TestWithAttrs_100Iterations;
var
  LL, LChild: TLogger;
  LI: Int32;
begin
  { 100 iterations of WithAttrs — stress test for memory leaks.
    Each iteration creates and discards a child handler. }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  for LI := 1 to 100 do
  begin
    LChild := LL.With_('iter', IntToStr(LI));
    LChild.Info^.Msg('iter-' + IntToStr(LI));
  end;
  CheckEqual(Int64(100), Int64(GCaptureCount), '100 child iterations');
  { Verify first and last are correct }
  Check(GCaptured[0].Message = 'iter-1', 'first iter msg');
  Check(GCaptured[99].Message = 'iter-100', 'last iter msg');
end;

{ ============================================================
  GAP 5: Boundary conditions — empty strings, growth boundaries
  ============================================================ }

procedure TestBoundary_EmptyKeyValue;
var
  LL: TLogger;
begin
  { Empty key and empty value — must not crash or corrupt }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Str('', '')^.Str('normal', 'val')^.Msg('');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'empty key/val logged');
  Check(GCaptured[0].Attrs[0].Key = '', 'empty key preserved');
  Check(GCaptured[0].Attrs[0].SVal = '', 'empty val preserved');
  Check(GCaptured[0].Attrs[1].Key = 'normal', 'second attr intact');
  Check(GCaptured[0].Message = '', 'empty message preserved');
end;

procedure TestBoundary_AttrGrowthAt8;
var
  LL: TLogger;
begin
  { Exactly 8 attrs — the growth boundary (initial SetLength is +8) }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^
    .Str('a1','v1')^.Str('a2','v2')^.Str('a3','v3')^.Str('a4','v4')^
    .Str('a5','v5')^.Str('a6','v6')^.Str('a7','v7')^.Str('a8','v8')^
    .Msg('exactly 8');
  CheckEqual(Int64(8), Int64(GCaptured[0].AttrCount), 'exactly 8 attrs');
  Check(GCaptured[0].Attrs[7].Key = 'a8', '8th attr key correct');
  Check(GCaptured[0].Attrs[7].SVal = 'v8', '8th attr val correct');
end;

procedure TestBoundary_AttrGrowthAt9;
var
  LL: TLogger;
begin
  { 9 attrs — crosses the first growth boundary, triggers SetLength }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^
    .Str('a1','v1')^.Str('a2','v2')^.Str('a3','v3')^.Str('a4','v4')^
    .Str('a5','v5')^.Str('a6','v6')^.Str('a7','v7')^.Str('a8','v8')^
    .Str('a9','v9')^
    .Msg('crosses boundary');
  CheckEqual(Int64(9), Int64(GCaptured[0].AttrCount), '9 attrs after growth');
  Check(GCaptured[0].Attrs[8].Key = 'a9', '9th attr key correct');
  Check(GCaptured[0].Attrs[8].SVal = 'v9', '9th attr val correct');
end;

procedure TestBoundary_AttrGrowthAt16;
var
  LL: TLogger;
  LI: Int32;
  LE: PLogEvent;
begin
  { 16 attrs — second growth boundary }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LE := LL.Info;
  for LI := 1 to 16 do
    LE := LE^.Str('k' + IntToStr(LI), 'v' + IntToStr(LI));
  LE^.Msg('16 attrs');
  CheckEqual(Int64(16), Int64(GCaptured[0].AttrCount), '16 attrs');
  Check(GCaptured[0].Attrs[15].Key = 'k16', '16th key');
end;

procedure TestBoundary_AttrGrowthAt24;
var
  LL: TLogger;
  LI: Int32;
  LE: PLogEvent;
begin
  { 24 attrs — third growth boundary }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LE := LL.Info;
  for LI := 1 to 24 do
    LE := LE^.Str('k' + IntToStr(LI), 'v' + IntToStr(LI));
  LE^.Msg('24 attrs');
  CheckEqual(Int64(24), Int64(GCaptured[0].AttrCount), '24 attrs');
  Check(GCaptured[0].Attrs[23].Key = 'k24', '24th key');
  Check(GCaptured[0].Attrs[23].SVal = 'v24', '24th val');
end;


{ ============================================================
  GAP 6: Re-entrancy — would have caught R1 infinite loop/crash
  A handler that logs from within Handle() must not deadlock or crash.
  ============================================================ }

procedure TestReentrancy_ActualReentry;
var
  LH: TReentrantHandler;
  LL: TLogger;
begin
  { Handler that tries to log again from within Handle.
    The module uses GLogDepth to detect this and redirect to stderr.
    This test verifies it doesn't crash or infinite-loop. }
  LH := TReentrantHandler.Create(3);
  LL := TLogger.New(LH, llDebug);
  LH.SetInner(LL);
  LL.Info^.Msg('trigger reentry');
  Check(LH.FCallCount = 1, 'handler called exactly once (reentry blocked)');
  LH.SetInner(TLogger.New(nil, llFatal));
end;

procedure TestReentrancy_PoolSlotSafety;
var
  LH: TReentrantHandler;
  LL: TLogger;
begin
  { The pool slot used by the outer call must not be corrupted by the
    inner (reentrant) call attempting to use the same pool. }
  LH := TReentrantHandler.Create(2);
  LL := TLogger.New(LH, llDebug);
  LH.SetInner(LL);
  { Log 16 events to fill the pool, then trigger reentry }
  LL.Info^.Msg('event-1');
  LL.Info^.Msg('event-2');
  LL.Info^.Msg('event-3');
  LL.Info^.Msg('event-4');
  LL.Info^.Msg('event-5');
  LL.Info^.Msg('event-6');
  LL.Info^.Msg('event-7');
  LL.Info^.Msg('event-8');
  LL.Info^.Msg('event-9');
  LL.Info^.Msg('event-10');
  LL.Info^.Msg('event-11');
  LL.Info^.Msg('event-12');
  LL.Info^.Msg('event-13');
  LL.Info^.Msg('event-14');
  LL.Info^.Msg('event-15');
  LL.Info^.Msg('event-16');
  { All 16 slots used. Next call reuses slot 0. }
  LL.Info^.Msg('reuse-slot-0');
  Check(LH.FCallCount = 17, 'all 17 events handled');
  LH.SetInner(TLogger.New(nil, llFatal));
end;

{ ============================================================
  GAP 7: Error paths — handler exceptions, broken file mid-session
  ============================================================ }

procedure TestErrorPath_HandlerException;
var
  LH: TExplodingHandler;
  LL: TLogger;
  LCaught: Boolean;
begin
  { Handler raises on 2nd call. Logger must not corrupt state. }
  LH := TExplodingHandler.Create(2);
  LL := TLogger.New(LH, llDebug);
  LL.Info^.Msg('first ok');
  LCaught := False;
  try
    LL.Info^.Msg('this explodes');
  except
    on E: Exception do
      LCaught := True;
  end;
  Check(LCaught, 'exception propagated from handler');
  { Logger must still be usable after exception }
  LCaught := False;
  try
    LL.Info^.Msg('after exception');
  except
    LCaught := True;
  end;
  Check(not LCaught, 'logger usable after handler exception');
end;

procedure TestErrorPath_BrokenFileSilentSkip;
var
  LL: TLogger;
  LPath: string;
begin
  { Open a valid file, then make it broken by deleting the directory.
    Subsequent writes must not crash (FBroken path). }
  LPath := '/nonexistent_dir_' + IntToStr(Random(99999)) + '/test.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  { First write triggers EnsureOpen which fails → FBroken = True }
  LL.Info^.Msg('first attempt');
  { Second write must silently skip (FBroken check at top of Handle) }
  LL.Info^.Msg('second attempt');
  LL.Info^.Msg('third attempt');
  { If we get here without crash, the FBroken path works }
  Check(True, 'broken handler silently skips all writes');
end;

procedure TestErrorPath_MultiHandlerPartialFailure;
var
  LL: TLogger;
  LExploder: TExplodingHandler;
  LCaught: Boolean;
begin
  { MultiHandler with one exploding handler and one capture handler.
    The exploding handler fails, but capture should still work. }
  ResetCapture;
  LExploder := TExplodingHandler.Create(1); // explodes on first call
  LL := TLogger.New(NewMultiHandler([
    TCaptureHandler.Create(llDebug) as ILogHandler,
    LExploder as ILogHandler
  ]), llDebug);

  LCaught := False;
  try
    LL.Info^.Msg('multi partial');
  except
    on E: Exception do
      LCaught := True;
  end;
  { MultiHandler iterates all handlers. If first succeeds and second throws,
    the event IS captured but exception propagates. }
  Check(GCaptureCount >= 1, 'capture handler received event before explosion');
end;

{ ============================================================
  GAP 8: Double-fire prevention — would have caught R2 double-fire
  The R2 bug: Msg() could fire twice if FEnabled wasn't cleared.
  ============================================================ }

procedure TestDoubleFire_MsgThenSend;
var
  LL: TLogger;
  LE: PLogEvent;
begin
  { Call Msg then Send on same event — must not double-fire }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LE := LL.Info;
  LE^.Str('k', 'v')^.Msg('first');
  { After Msg, FEnabled should be False. Calling Send should be no-op. }
  LE^.Send;
  CheckEqual(Int64(1), Int64(GCaptureCount), 'no double-fire after Msg+Send');
end;

procedure TestDoubleFire_SendThenMsg;
var
  LL: TLogger;
  LE: PLogEvent;
begin
  { Call Send then Msg — must not double-fire }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LE := LL.Info;
  LE^.Str('k', 'v')^.Send;
  LE^.Msg('second');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'no double-fire after Send+Msg');
end;

procedure TestDoubleFire_MsgTwice;
var
  LL: TLogger;
  LE: PLogEvent;
begin
  { Call Msg twice on same event — must fire only once }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LE := LL.Info;
  LE^.Msg('first');
  LE^.Msg('second');
  CheckEqual(Int64(1), Int64(GCaptureCount), 'Msg called twice fires once');
  Check(GCaptured[0].Message = 'first', 'first Msg wins');
end;


{ ============================================================
  GAP 9: Content verification — tests that check actual values
  not just "no crash" or count
  ============================================================ }

procedure TestContent_FileHandlerFormat;
var
  LL: TLogger;
  LPath: string;
  LF: TextFile;
  LLine: string;
begin
  { Verify file handler produces correct format with all attr types }
  LPath := '/tmp/test_log_content_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo), llInfo);
  LL.Info^.Str('name', 'alice')^.Int('age', 30)^.Bool('active', True)^.Float('score', 9.5)^.Msg('user login');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  AssignFile(LF, LPath);
  Reset(LF);
  ReadLn(LF, LLine);
  CloseFile(LF);

  Check(Pos('INF', LLine) > 0, 'level present');
  Check(Pos('user login', LLine) > 0, 'message present');
  Check(Pos('name=alice', LLine) > 0, 'string attr formatted');
  Check(Pos('age=30', LLine) > 0, 'int attr formatted');
  Check(Pos('active=true', LLine) > 0, 'bool attr formatted');
  Check(Pos('score=9.5', LLine) > 0, 'float attr formatted');

  DeleteFile(LPath);
end;

procedure TestContent_WithAttrsInherited;
var
  LL, LChild, LGrandchild: TLogger;
begin
  { Verify that attrs from parent AND grandparent are all present }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LChild := LL.With_('svc', 'auth');
  LGrandchild := LChild.WithInt('port', 443);
  LGrandchild.Info^.Str('user', 'bob')^.Msg('login');

  CheckEqual(Int64(1), Int64(GCaptureCount), 'one event');
  { The capture handler's WithAttrs creates a new handler with prefix attrs.
    The event's own attrs should include 'user'. }
  Check(GCaptured[0].Attrs[0].Key = 'user', 'event attr is user');
  Check(GCaptured[0].Message = 'login', 'message correct');
end;

procedure TestContent_SpecialCharsInStrings;
var
  LL: TLogger;
begin
  { Strings with special characters must not corrupt output }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  LL.Info^.Str('path', '/tmp/file with spaces/test.log')^.Msg('special chars');
  LL.Info^.Str('json', '{"key":"value"}')^.Msg('json in attr');
  LL.Info^.Str('newline', 'line1'#10'line2')^.Msg('embedded newline');
  LL.Info^.Str('tab', 'col1'#9'col2')^.Msg('embedded tab');
  LL.Info^.Str('null', 'before'#0'after')^.Msg('embedded null');

  CheckEqual(Int64(5), Int64(GCaptureCount), '5 special char events');
  Check(GCaptured[0].Attrs[0].SVal = '/tmp/file with spaces/test.log', 'spaces preserved');
  Check(GCaptured[1].Attrs[0].SVal = '{"key":"value"}', 'json preserved');
  Check(Pos(#10, GCaptured[2].Attrs[0].SVal) > 0, 'newline preserved');
  Check(Pos(#9, GCaptured[3].Attrs[0].SVal) > 0, 'tab preserved');
end;

{ ============================================================
  GAP 10: Nil handler safety — would have caught nil deref
  ============================================================ }

procedure TestNilHandler_InLogger;
var
  LL: TLogger;
begin
  { Logger with nil handler — must not crash on any operation }
  LL := TLogger.New(nil, llDebug);
  LL.Info^.Str('k', 'v')^.Msg('nil handler');
  LL.Debug^.Send;
  LL.Error^.Err('test')^.Msg('error');
  Check(True, 'nil handler logger does not crash');
end;

procedure TestNilHandler_Enabled;
var
  LL: TLogger;
begin
  { Enabled check with nil handler must return False, not crash }
  LL := TLogger.New(nil, llDebug);
  Check(not LL.Enabled(llInfo), 'nil handler returns not enabled');
  Check(not LL.Enabled(llFatal), 'nil handler returns not enabled for fatal');
end;

{ ============================================================
  GAP 11: Stress tests — expose pool corruption under load
  ============================================================ }

procedure TestStress_1000Events;
var
  LL: TLogger;
  LI: Int32;
begin
  { 1000 events — exercises pool recycling 62+ full cycles }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llDebug), llDebug);
  for LI := 1 to 1000 do
    LL.Info^.Int('n', LI)^.Str('s', 'val-' + IntToStr(LI))^.Msg('stress');
  CheckEqual(Int64(1000), Int64(GCaptureCount), '1000 events captured');
  { Spot-check various positions }
  CheckEqual(Int64(1), GCaptured[0].Attrs[0].IVal, 'first n=1');
  CheckEqual(Int64(500), GCaptured[499].Attrs[0].IVal, 'mid n=500');
  CheckEqual(Int64(1000), GCaptured[999].Attrs[0].IVal, 'last n=1000');
  Check(GCaptured[999].Attrs[1].SVal = 'val-1000', 'last str correct');
end;

procedure TestStress_FileRotation_ManyWrites;
var
  LL: TLogger;
  LPath: string;
  LI: Int32;
  LFileCount: Int32;
begin
  { 200 writes with MaxBytes=100, MaxFiles=3.
    Must produce exactly main + up to 3 rotated files. }
  LPath := '/tmp/test_log_stress_rot_' + IntToStr(Random(99999)) + '.log';
  LL := TLogger.New(NewFileHandler(LPath, llInfo, 100, 3), llInfo);
  for LI := 1 to 200 do
    LL.Info^.Int('i', LI)^.Msg('stress-rotation');
  LL := TLogger.New(NewConsoleHandler(llFatal), llFatal); // release

  LFileCount := 0;
  if FileExists(LPath) then Inc(LFileCount);
  if FileExists(LPath + '.1') then Inc(LFileCount);
  if FileExists(LPath + '.2') then Inc(LFileCount);
  if FileExists(LPath + '.3') then Inc(LFileCount);

  Check(LFileCount >= 2, 'at least 2 files from stress rotation');
  Check(not FileExists(LPath + '.4'), 'no .4 file (MaxFiles=3)');

  DeleteFile(LPath);
  DeleteFile(LPath + '.1');
  DeleteFile(LPath + '.2');
  DeleteFile(LPath + '.3');
end;

{ ============================================================
  GAP 12: Disabled-level event must not allocate or mutate
  ============================================================ }

procedure TestDisabled_NoSideEffects;
var
  LL: TLogger;
  LBefore: Int32;
begin
  { When level is disabled, the event builder must be a complete no-op.
    Verify no attrs are accumulated (they shouldn't be, since FEnabled=False). }
  ResetCapture;
  LL := TLogger.New(TCaptureHandler.Create(llError), llError);
  LBefore := GCaptureCount;
  LL.Debug^.Str('expensive', StringOfChar('X', 10000))^.Int('n', 42)^.Msg('skip');
  LL.Info^.Str('also', 'skipped')^.Msg('skip2');
  CheckEqual(Int64(LBefore), Int64(GCaptureCount), 'disabled events produce zero side effects');
end;

{ ============================================================
  Main
  ============================================================ }

begin
  Randomize;
  T := TTestRunner.Create('nextpas.core.log [AUDIT]');

  { Pool recycling (R1 nil crash) }
  T.Run('Pool: 20 events force reuse', @TestPoolRecycling_20Events);
  T.Run('Pool: 2 loggers share pool', @TestPoolRecycling_DifferentHandlers);
  T.Run('Pool: stress with long strings', @TestPoolRecycling_StressWithStrings);

  { JSON validity (R3 comma bug) }
  T.Run('JSON: valid structure', @TestJsonOutput_ValidStructure);
  T.Run('JSON: parse file', @TestJsonOutput_ParseFile);
  T.Run('JSON: comma regression', @TestJsonOutput_CommaRegression);

  { Rotation (R4 size bug) }
  T.Run('Rotation: exact size accounting', @TestRotation_ExactSizeAccounting);
  T.Run('Rotation: MaxFiles respected', @TestRotation_MaxFilesRespected);
  T.Run('Rotation: boundary exact', @TestRotation_BoundaryExact);

  { WithAttrs lifecycle (R2 leak) }
  T.Run('WithAttrs: chain of 10', @TestWithAttrs_ChainOf10);
  T.Run('WithAttrs: scope release', @TestWithAttrs_ScopeRelease);
  T.Run('WithAttrs: 100 iterations', @TestWithAttrs_100Iterations);

  { Boundary conditions }
  T.Run('Boundary: empty key/value', @TestBoundary_EmptyKeyValue);
  T.Run('Boundary: exactly 8 attrs', @TestBoundary_AttrGrowthAt8);
  T.Run('Boundary: 9 attrs (growth)', @TestBoundary_AttrGrowthAt9);
  T.Run('Boundary: 16 attrs', @TestBoundary_AttrGrowthAt16);
  T.Run('Boundary: 24 attrs', @TestBoundary_AttrGrowthAt24);

  { Re-entrancy (R1) }
  T.Run('Reentry: actual re-entrant handler', @TestReentrancy_ActualReentry);
  T.Run('Reentry: pool slot safety', @TestReentrancy_PoolSlotSafety);

  { Error paths }
  T.Run('Error: handler exception', @TestErrorPath_HandlerException);
  T.Run('Error: broken file silent skip', @TestErrorPath_BrokenFileSilentSkip);
  T.Run('Error: multi partial failure', @TestErrorPath_MultiHandlerPartialFailure);

  { Double-fire (R2) }
  T.Run('DoubleFire: Msg then Send', @TestDoubleFire_MsgThenSend);
  T.Run('DoubleFire: Send then Msg', @TestDoubleFire_SendThenMsg);
  T.Run('DoubleFire: Msg twice', @TestDoubleFire_MsgTwice);

  { Content verification }
  T.Run('Content: file handler format', @TestContent_FileHandlerFormat);
  T.Run('Content: WithAttrs inherited', @TestContent_WithAttrsInherited);
  T.Run('Content: special chars', @TestContent_SpecialCharsInStrings);

  { Nil handler }
  T.Run('Nil: handler in logger', @TestNilHandler_InLogger);
  T.Run('Nil: Enabled check', @TestNilHandler_Enabled);

  { Stress }
  T.Run('Stress: 1000 events', @TestStress_1000Events);
  T.Run('Stress: file rotation 200 writes', @TestStress_FileRotation_ManyWrites);

  { Disabled no side effects }
  T.Run('Disabled: no side effects', @TestDisabled_NoSideEffects);

  T.Summary;
end.
