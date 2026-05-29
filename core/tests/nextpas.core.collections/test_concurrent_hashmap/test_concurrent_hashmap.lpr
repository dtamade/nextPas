program test_concurrent_hashmap;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}cthreads,{$endif}
  SysUtils, Classes,
  nextpas.core.testing,
  nextpas.core.collections.concurrent.hashmap;

type
  TIntConcMap = specialize TConcurrentHashMap<Integer, Integer>;
  TStrConcMap = specialize TConcurrentHashMap<string, Integer>;

function HashInt(const A: Integer): UInt32;
begin
  Result := UInt32(A) * 2654435761;
end;

function EqInt(const A, B: Integer): Boolean;
begin
  Result := A = B;
end;

function HashStr(const A: string): UInt32;
var i: Integer;
begin
  Result := 2166136261;
  for i := 1 to Length(A) do
    Result := (Result xor UInt32(Ord(A[i]))) * 16777619;
end;

function EqStr(const A, B: string): Boolean;
begin
  Result := A = B;
end;

var
  T: TTestRunner;

procedure TestPutGet;
var M: TIntConcMap; i, v: Integer; ok: Boolean;
begin
  M := TIntConcMap.Create(@HashInt, @EqInt);
  try
    for i := 0 to 999 do M.Put(i, i * 10);
    CheckEqual(Int64(1000), Int64(M.Count), 'count');
    ok := True;
    for i := 0 to 999 do
      if not M.TryGetValue(i, v) or (v <> i * 10) then ok := False;
    Check(ok, 'all values correct');
  finally M.Free; end;
end;

procedure TestUpdate;
var M: TIntConcMap; v: Integer;
begin
  M := TIntConcMap.Create(@HashInt, @EqInt);
  try
    M.Put(1, 10); M.Put(1, 99);
    Check(M.TryGetValue(1, v), 'get'); CheckEqual(Int64(99), Int64(v), 'updated');
  finally M.Free; end;
end;

procedure TestRemove;
var M: TIntConcMap;
begin
  M := TIntConcMap.Create(@HashInt, @EqInt);
  try
    M.Put(1, 10); M.Put(2, 20); M.Put(3, 30);
    Check(M.Remove(2), 'remove 2');
    Check(not M.ContainsKey(2), 'not contains 2');
    CheckEqual(Int64(2), Int64(M.Count), 'count');
  finally M.Free; end;
end;

procedure TestGetOrInsert;
var M: TIntConcMap; v: Integer;
begin
  M := TIntConcMap.Create(@HashInt, @EqInt);
  try
    v := M.GetOrInsert(1, 42);
    CheckEqual(Int64(42), Int64(v), 'new');
    M.Put(1, 100);
    v := M.GetOrInsert(1, 99);
    CheckEqual(Int64(100), Int64(v), 'existing');
  finally M.Free; end;
end;

procedure TestClear;
var M: TIntConcMap;
begin
  M := TIntConcMap.Create(@HashInt, @EqInt);
  try
    M.Put(1, 1); M.Put(2, 2); M.Put(3, 3);
    M.Clear;
    CheckEqual(Int64(0), Int64(M.Count), 'count');
    Check(not M.ContainsKey(1), 'not contains');
  finally M.Free; end;
end;

procedure TestStringKey;
var M: TStrConcMap; i, v: Integer; ok: Boolean;
begin
  M := TStrConcMap.Create(@HashStr, @EqStr);
  try
    for i := 0 to 99 do M.Put('key' + IntToStr(i), i);
    CheckEqual(Int64(100), Int64(M.Count), 'count');
    ok := True;
    for i := 0 to 99 do
      if not M.TryGetValue('key' + IntToStr(i), v) or (v <> i) then ok := False;
    Check(ok, 'string keys correct');
  finally M.Free; end;
end;

{ Multi-threaded stress test }

var
  GMap: TIntConcMap;

type
  TWriterThread = class(TThread)
  private FStart, FEnd: Integer;
  protected procedure Execute; override;
  public constructor Create(AStart, AEnd: Integer);
  end;

  TReaderThread = class(TThread)
  private FStart, FEnd, FHits: Integer;
  protected procedure Execute; override;
  public
    constructor Create(AStart, AEnd: Integer);
    property Hits: Integer read FHits;
  end;

constructor TWriterThread.Create(AStart, AEnd: Integer);
begin
  FStart := AStart; FEnd := AEnd;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TWriterThread.Execute;
var i: Integer;
begin
  for i := FStart to FEnd do GMap.Put(i, i * 2);
end;

constructor TReaderThread.Create(AStart, AEnd: Integer);
begin
  FStart := AStart; FEnd := AEnd; FHits := 0;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TReaderThread.Execute;
var i, v, pass: Integer;
begin
  for pass := 1 to 5 do
    for i := FStart to FEnd do
      if GMap.TryGetValue(i, v) then Inc(FHits);
end;

procedure TestMultiThreadStress;
const
  NUM_ITEMS = 10000;
  NUM_WRITERS = 4;
  NUM_READERS = 4;
  PER_WRITER = NUM_ITEMS div NUM_WRITERS;
var
  Writers: array[0..NUM_WRITERS-1] of TWriterThread;
  Readers: array[0..NUM_READERS-1] of TReaderThread;
  i: Integer;
  ok: Boolean;
begin
  GMap := TIntConcMap.Create(@HashInt, @EqInt);
  try
    for i := 0 to NUM_WRITERS - 1 do
      Writers[i] := TWriterThread.Create(i * PER_WRITER, (i + 1) * PER_WRITER - 1);
    for i := 0 to NUM_READERS - 1 do
      Readers[i] := TReaderThread.Create(0, NUM_ITEMS - 1);

    for i := 0 to NUM_WRITERS - 1 do Writers[i].WaitFor;
    for i := 0 to NUM_READERS - 1 do Readers[i].WaitFor;

    CheckEqual(Int64(NUM_ITEMS), Int64(GMap.Count), 'count');
    ok := True;
    for i := 0 to NUM_ITEMS - 1 do
      if not GMap.ContainsKey(i) then ok := False;
    Check(ok, 'all keys present');

    for i := 0 to NUM_WRITERS - 1 do Writers[i].Free;
    for i := 0 to NUM_READERS - 1 do Readers[i].Free;
  finally GMap.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.concurrent.hashmap');
  T.Run('Put/Get', @TestPutGet);
  T.Run('Update', @TestUpdate);
  T.Run('Remove', @TestRemove);
  T.Run('GetOrInsert', @TestGetOrInsert);
  T.Run('Clear', @TestClear);
  T.Run('String key', @TestStringKey);
  T.Run('Multi-thread stress (4W+4R)', @TestMultiThreadStress);
  T.Summary;
end.
