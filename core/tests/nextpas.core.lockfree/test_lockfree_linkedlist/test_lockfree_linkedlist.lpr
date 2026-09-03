program test_lockfree_linkedlist;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.text.conv,
  nextpas.core.atomic,
  nextpas.core.lockfree.linkedlist;

type
  TIntLinkedList = specialize TConcurrentLinkedListImpl<Integer>;

  PListWriterCtx = ^TListWriterCtx;
  TListWriterCtx = record
    List: TIntLinkedList;
    Iterations: Int32;
  end;

  PListReaderCtx = ^TListReaderCtx;
  TListReaderCtx = record
    List: TIntLinkedList;
    Iterations: Int32;
    InvalidOutput: PInt32;
  end;

var
  GTests, GPassed: Integer;

function ListWriterProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PListWriterCtx;
  LI, LValue: Int32;
begin
  LCtx := PListWriterCtx(AArg);
  for LI := 1 to LCtx^.Iterations do
  begin
    LValue := LI mod 64;
    LCtx^.List.Insert(LValue);
    LCtx^.List.Remove(LValue);
  end;
  Result := nil;
end;

function ListReaderProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PListReaderCtx;
  LI, LValue: Int32;
begin
  LCtx := PListReaderCtx(AArg);
  for LI := 1 to LCtx^.Iterations do
  begin
    LCtx^.List.Contains(LI mod 64);
    LValue := -1;
    if (not LCtx^.List.Get(0, LValue)) and (LValue <> 0) then
      atomic_store(LCtx^.InvalidOutput^, 1, mo_release);
  end;
  Result := nil;
end;

procedure Check(ACond: Boolean; const AName: string);
begin
  Inc(GTests);
  if ACond then
    Inc(GPassed)
  else
    WriteLn('  FAIL: ', AName);
end;

procedure TestBasicInsertContains;
var
  LL: TIntLinkedList;
begin
  WriteLn('--- TestBasicInsertContains ---');
  LL := TIntLinkedList.Create;
  try
    Check(LL.IsEmpty, 'empty initially');
    Check(LL.Insert(42) = llOk, 'insert 42');
    Check(not LL.IsEmpty, 'not empty');
    Check(LL.Count = 1, 'count = 1');
    Check(LL.Contains(42), 'contains 42');
    Check(not LL.Contains(99), 'not contains 99');
  finally
    LL.Free;
  end;
end;

procedure TestSortedInsert;
var
  LL: TIntLinkedList;
  LVal: Integer;
begin
  WriteLn('--- TestSortedInsert ---');
  LL := TIntLinkedList.Create;
  try
    LL.Insert(30);
    LL.Insert(10);
    LL.Insert(20);
    // Should be sorted: 10, 20, 30
    Check(LL.Get(0, LVal) and (LVal = 10), 'first = 10');
    Check(LL.Get(1, LVal) and (LVal = 20), 'second = 20');
    Check(LL.Get(2, LVal) and (LVal = 30), 'third = 30');
    Check(LL.Count = 3, 'count = 3');
  finally
    LL.Free;
  end;
end;

procedure TestDuplicateInsert;
var
  LL: TIntLinkedList;
begin
  WriteLn('--- TestDuplicateInsert ---');
  LL := TIntLinkedList.Create;
  try
    LL.Insert(42);
    Check(LL.Insert(42) = llExists, 'duplicate returns exists');
    Check(LL.Count = 1, 'count still 1');
  finally
    LL.Free;
  end;
end;

procedure TestRemove;
var
  LL: TIntLinkedList;
  LVal: Integer;
begin
  WriteLn('--- TestRemove ---');
  LL := TIntLinkedList.Create;
  try
    LL.Insert(10);
    LL.Insert(20);
    LL.Insert(30);
    Check(LL.Remove(20) = llOk, 'remove 20');
    Check(not LL.Contains(20), 'not contains 20');
    Check(LL.Count = 2, 'count = 2');
    Check(LL.Get(0, LVal) and (LVal = 10), 'first = 10');
    Check(LL.Get(1, LVal) and (LVal = 30), 'second = 30');
    Check(LL.Remove(99) = llNotFound, 'remove missing');
  finally
    LL.Free;
  end;
end;

procedure TestRemoveHead;
var
  LL: TIntLinkedList;
  LVal: Integer;
begin
  WriteLn('--- TestRemoveHead ---');
  LL := TIntLinkedList.Create;
  try
    LL.Insert(10);
    LL.Insert(20);
    LL.Remove(10);
    Check(LL.Count = 1, 'count = 1');
    Check(LL.Get(0, LVal) and (LVal = 20), 'head = 20');
  finally
    LL.Free;
  end;
end;

procedure TestRemoveAll;
var
  LL: TIntLinkedList;
begin
  WriteLn('--- TestRemoveAll ---');
  LL := TIntLinkedList.Create;
  try
    LL.Insert(10);
    LL.Insert(20);
    LL.Insert(30);
    LL.Remove(10);
    LL.Remove(20);
    LL.Remove(30);
    Check(LL.IsEmpty, 'empty after remove all');
    Check(LL.Count = 0, 'count = 0');
  finally
    LL.Free;
  end;
end;

procedure TestGet;
var
  LL: TIntLinkedList;
  LVal: Integer;
begin
  WriteLn('--- TestGet ---');
  LL := TIntLinkedList.Create;
  try
    LVal := 123;
    Check(not LL.Get(0, LVal), 'get from empty');
    Check(LVal = 0, 'failed get clears output');
    LL.Insert(10);
    LL.Insert(20);
    Check(LL.Get(0, LVal) and (LVal = 10), 'get 0');
    Check(LL.Get(1, LVal) and (LVal = 20), 'get 1');
    Check(not LL.Get(2, LVal), 'get out of range');
    Check(not LL.Get(-1, LVal), 'get negative');
  finally
    LL.Free;
  end;
end;

procedure TestConcurrentReadWrite;
const
  ITERATIONS = 20000;
var
  LL: TIntLinkedList;
  LWriterRec, LReaderRec: TPlatformThreadRecord;
  LWriterCtx: TListWriterCtx;
  LReaderCtx: TListReaderCtx;
  LInvalidOutput: Int32;
begin
  WriteLn('--- TestConcurrentReadWrite ---');
  LL := TIntLinkedList.Create;
  try
    LInvalidOutput := 0;
    LWriterCtx.List := LL;
    LWriterCtx.Iterations := ITERATIONS;
    LReaderCtx.List := LL;
    LReaderCtx.Iterations := ITERATIONS;
    LReaderCtx.InvalidOutput := @LInvalidOutput;
    Check(platform_thread_spawn(LWriterRec, @ListWriterProc,
      @LWriterCtx) = 0, 'spawn list writer');
    Check(platform_thread_spawn(LReaderRec, @ListReaderProc,
      @LReaderCtx) = 0, 'spawn list reader');
    Check(platform_thread_wait(LWriterRec) = 0, 'join list writer');
    Check(platform_thread_wait(LReaderRec) = 0, 'join list reader');
    Check(atomic_load(LInvalidOutput, mo_acquire) = 0,
      'Concurrent failed reads keep deterministic output');
  finally
    LL.Free;
  end;
end;

procedure TestClear;
var
  LL: TIntLinkedList;
begin
  WriteLn('--- TestClear ---');
  LL := TIntLinkedList.Create;
  try
    LL.Insert(10);
    LL.Insert(20);
    LL.Clear;
    Check(LL.IsEmpty, 'empty after clear');
    Check(LL.Count = 0, 'count = 0');
    // Can still insert after clear
    LL.Insert(42);
    Check(LL.Count = 1, 'count = 1 after re-insert');
  finally
    LL.Free;
  end;
end;

procedure TestManyInserts;
var
  LL: TIntLinkedList;
  I, LN: Integer;
begin
  WriteLn('--- TestManyInserts ---');
  LN := 1000;
  LL := TIntLinkedList.Create;
  try
    // Insert in reverse order
    for I := LN downto 1 do
      LL.Insert(I);
    Check(LL.Count = LN, 'count = ' + IntToStr(LN));
    // Should be sorted
    for I := 1 to LN do
      Check(LL.Contains(I), 'contains ' + IntToStr(I));
  finally
    LL.Free;
  end;
end;

procedure TestInsertRemoveInsert;
var
  LL: TIntLinkedList;
begin
  WriteLn('--- TestInsertRemoveInsert ---');
  LL := TIntLinkedList.Create;
  try
    LL.Insert(42);
    LL.Remove(42);
    Check(LL.Insert(42) = llOk, 're-insert');
    Check(LL.Contains(42), 'contains after re-insert');
    Check(LL.Count = 1, 'count = 1');
  finally
    LL.Free;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicInsertContains;
  TestSortedInsert;
  TestDuplicateInsert;
  TestRemove;
  TestRemoveHead;
  TestRemoveAll;
  TestGet;
  TestConcurrentReadWrite;
  TestClear;
  TestManyInserts;
  TestInsertRemoveInsert;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
