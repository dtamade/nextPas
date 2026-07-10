program test_lockfree_msqueue;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.lockfree.msqueue;

type
  TIntQueue = specialize TLockFreeMsQueueImpl<Integer>;

var
  GTests, GPassed: Integer;

procedure Check(ACond: Boolean; const AName: string);
begin
  Inc(GTests);
  if ACond then
    Inc(GPassed)
  else
    WriteLn('  FAIL: ', AName);
end;

procedure TestBasicEnqueueDequeue;
var
  LQ: TIntQueue;
  LVal: Integer;
begin
  WriteLn('--- TestBasicEnqueueDequeue ---');
  LQ := TIntQueue.Create;
  try
    Check(LQ.IsEmpty, 'empty initially');
    Check(LQ.TryEnqueue(42), 'enqueue 42');
    Check(not LQ.IsEmpty, 'not empty after enqueue');
    Check(LQ.TryDequeue(LVal) and (LVal = 42), 'dequeue 42');
    Check(LQ.IsEmpty, 'empty after dequeue');
    Check(not LQ.TryDequeue(LVal), 'dequeue from empty returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestFIFO;
var
  LQ: TIntQueue;
  LVal, I: Integer;
begin
  WriteLn('--- TestFIFO ---');
  LQ := TIntQueue.Create;
  try
    for I := 1 to 10 do
      Check(LQ.TryEnqueue(I), 'enqueue');
    for I := 1 to 10 do
    begin
      Check(LQ.TryDequeue(LVal), 'dequeue');
      Check(LVal = I, 'fifo order');
    end;
    Check(LQ.IsEmpty, 'empty after drain');
  finally
    LQ.Free;
  end;
end;

procedure TestLargeVolume;
var
  LQ: TIntQueue;
  LVal, I, LN: Integer;
begin
  WriteLn('--- TestLargeVolume ---');
  LN := 10000;
  LQ := TIntQueue.Create(8);  // small initial capacity to test grow
  try
    for I := 1 to LN do
      LQ.TryEnqueue(I);
    Check(LQ.ApproxCount = LN, 'count after enqueue');
    for I := 1 to LN do
    begin
      Check(LQ.TryDequeue(LVal), 'dequeue');
      Check(LVal = I, 'value');
    end;
    Check(LQ.IsEmpty, 'empty after drain');
  finally
    LQ.Free;
  end;
end;

procedure TestClose;
var
  LQ: TIntQueue;
begin
  WriteLn('--- TestClose ---');
  LQ := TIntQueue.Create;
  try
    LQ.TryEnqueue(1);
    LQ.Close;
    Check(LQ.IsClosed, 'is closed');
    Check(not LQ.TryEnqueue(2), 'enqueue after close fails');
  finally
    LQ.Free;
  end;
end;

procedure TestAlternatingEnqueueDequeue;
var
  LQ: TIntQueue;
  LVal, I: Integer;
begin
  WriteLn('--- TestAlternatingEnqueueDequeue ---');
  LQ := TIntQueue.Create;
  try
    for I := 1 to 100 do
    begin
      Check(LQ.TryEnqueue(I), 'enqueue');
      Check(LQ.TryDequeue(LVal) and (LVal = I), 'dequeue');
    end;
    Check(LQ.IsEmpty, 'empty');
  finally
    LQ.Free;
  end;
end;

procedure TestSum;
var
  LQ: TIntQueue;
  LTotal, LSum, LVal: Integer;
  I: Integer;
begin
  WriteLn('--- TestSum ---');
  LTotal := 5000;
  LQ := TIntQueue.Create;
  try
    for I := 1 to LTotal do
      LQ.TryEnqueue(I);
    LSum := 0;
    while LQ.TryDequeue(LVal) do
      Inc(LSum, LVal);
    Check(LSum = LTotal * (LTotal + 1) div 2, 'sum matches');
  finally
    LQ.Free;
  end;
end;

procedure TestManagedTypeRejected;
var
  LQ: specialize TLockFreeMsQueueImpl<string>;
  LRaised: Boolean;
begin
  WriteLn('--- TestManagedTypeRejected ---');
  LQ := nil;
  LRaised := False;
  try
    LQ := specialize TLockFreeMsQueueImpl<string>.Create;
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  LQ.Free;
  Check(LRaised, 'managed element type rejected');
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicEnqueueDequeue;
  TestFIFO;
  TestLargeVolume;
  TestClose;
  TestAlternatingEnqueueDequeue;
  TestSum;
  TestManagedTypeRejected;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
