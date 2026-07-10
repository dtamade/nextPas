{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_counting_bloom;

uses
  SysUtils,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.lockfree.counting_bloom;

var
  GPassed, GFailed: Int32;
  GConcurrentFilter: TCountingBloomFilter;
  GConcurrentStart: Int32;
  GConcurrentRemoveOk: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure Test_Empty;
var
  LCBF: TCountingBloomFilter;
begin
  WriteLn('--- Empty ---');
  LCBF := TCountingBloomFilter.Create(1024, 4);
  try
    Check(LCBF.Count = 0, 'empty count = 0');
    Check(not LCBF.Contains('anything'), 'empty not contains');
    LCBF.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LCBF.Free;
    end;
  end;
end;

procedure Test_AddContains;
var
  LCBF: TCountingBloomFilter;
begin
  WriteLn('--- Add/Contains ---');
  LCBF := TCountingBloomFilter.Create(1024, 4);
  try
    Check(LCBF.Add('hello') = cbfOk, 'Add(hello) = ok');
    Check(LCBF.Add('world') = cbfOk, 'Add(world) = ok');
    Check(LCBF.Add('foo') = cbfOk, 'Add(foo) = ok');
    Check(LCBF.Count = 3, 'count = 3');
    Check(LCBF.Contains('hello'), 'contains hello');
    Check(LCBF.Contains('world'), 'contains world');
    Check(LCBF.Contains('foo'), 'contains foo');
    Check(not LCBF.Contains('bar'), 'not contains bar');
    LCBF.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LCBF.Free;
    end;
  end;
end;

procedure Test_Remove;
var
  LCBF: TCountingBloomFilter;
begin
  WriteLn('--- Remove ---');
  LCBF := TCountingBloomFilter.Create(1024, 4);
  try
    LCBF.Add('a');
    LCBF.Add('b');
    LCBF.Add('c');
    Check(LCBF.Count = 3, 'count = 3');
    Check(LCBF.Remove('b') = cbfOk, 'Remove(b) = ok');
    Check(LCBF.Count = 2, 'count = 2');
    Check(not LCBF.Contains('b'), 'not contains b after remove');
    Check(LCBF.Contains('a'), 'still contains a');
    Check(LCBF.Contains('c'), 'still contains c');
    Check(LCBF.Remove('b') = cbfNotFound, 'Remove(b) again = not found');
    Check(LCBF.Remove('xyz') = cbfNotFound, 'Remove(xyz) = not found');
    LCBF.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LCBF.Free;
    end;
  end;
end;

procedure Test_DuplicateAdd;
var
  LCBF: TCountingBloomFilter;
begin
  WriteLn('--- Duplicate Add ---');
  LCBF := TCountingBloomFilter.Create(1024, 4);
  try
    LCBF.Add('x');
    LCBF.Add('x');
    LCBF.Add('x');
    Check(LCBF.Count = 3, 'count = 3 (added 3 times)');
    Check(LCBF.Contains('x'), 'contains x');
    { Remove once — should still be "contained" because counters > 0 }
    LCBF.Remove('x');
    Check(LCBF.Count = 2, 'count = 2 after 1 remove');
    Check(LCBF.Contains('x'), 'still contains x (counter > 0)');
    LCBF.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LCBF.Free;
    end;
  end;
end;

procedure Test_Reset;
var
  LCBF: TCountingBloomFilter;
begin
  WriteLn('--- Reset ---');
  LCBF := TCountingBloomFilter.Create(1024, 4);
  try
    LCBF.Add('a');
    LCBF.Add('b');
    Check(LCBF.Count = 2, 'count = 2');
    LCBF.Reset;
    Check(LCBF.Count = 0, 'count = 0 after reset');
    Check(not LCBF.Contains('a'), 'not contains a after reset');
    Check(not LCBF.Contains('b'), 'not contains b after reset');
    LCBF.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LCBF.Free;
    end;
  end;
end;

procedure Test_ManyItems;
var
  LCBF: TCountingBloomFilter;
  I: Int32;
begin
  WriteLn('--- Many Items ---');
  LCBF := TCountingBloomFilter.Create(65536, 4);
  try
    for I := 0 to 999 do
      LCBF.Add('item-' + IntToStr(I));
    Check(LCBF.Count = 1000, 'count = 1000');
    for I := 0 to 999 do
      Check(LCBF.Contains('item-' + IntToStr(I)), 'contains item-' + IntToStr(I));
    LCBF.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LCBF.Free;
    end;
  end;
end;

function ConcurrentRemoveWorker(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  while AtomicLoad32(GConcurrentStart, moAcquire) = 0 do
    CpuPause;
  if GConcurrentFilter.Remove('shared') = cbfOk then
    AtomicFetchAdd32(GConcurrentRemoveOk, 1, moRelaxed);
end;

procedure Test_ConcurrentRemoveDoesNotUnderflow;
const
  THREAD_COUNT = 8;
var
  LHandles: array[0..THREAD_COUNT - 1] of TPlatformThreadHandle;
  LIndex: Int32;
  LReturnValue: Pointer;
begin
  WriteLn('--- Concurrent Remove ---');
  GConcurrentFilter := TCountingBloomFilter.Create(1024, 4);
  GConcurrentStart := 0;
  GConcurrentRemoveOk := 0;
  try
    GConcurrentFilter.Add('shared');
    for LIndex := 0 to THREAD_COUNT - 1 do
      Check(platform_thread_create(LHandles[LIndex], @ConcurrentRemoveWorker, nil) = 0,
        'create concurrent remover');
    AtomicStore32(GConcurrentStart, 1, moRelease);
    for LIndex := 0 to THREAD_COUNT - 1 do
      Check(platform_thread_join(LHandles[LIndex], LReturnValue) = 0,
        'join concurrent remover');
    Check(GConcurrentRemoveOk = 1, 'exactly one concurrent remove succeeds');
    Check(GConcurrentFilter.Count = 0, 'concurrent remove count does not underflow');
    Check(not GConcurrentFilter.Contains('shared'), 'removed key is not contained');
  finally
    GConcurrentFilter.Free;
    GConcurrentFilter := nil;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;
  WriteLn('=== CountingBloomFilter Tests ===');
  Test_Empty;
  Test_AddContains;
  Test_Remove;
  Test_DuplicateAdd;
  Test_Reset;
  Test_ManyItems;
  Test_ConcurrentRemoveDoesNotUnderflow;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
