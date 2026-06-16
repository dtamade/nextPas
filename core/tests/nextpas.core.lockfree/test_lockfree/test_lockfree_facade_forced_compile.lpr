program test_lockfree_facade_forced_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.lockfree;

type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntMpsc = specialize TMpscQueue<Integer>;
  TIntStack = specialize TLockFreeStack<Integer>;
  TIntDeque = specialize TWorkStealingDeque<Integer>;
  TIntSegQueue = specialize TSegQueue<Integer>;
  TIntSpmc = specialize TSpmcQueue<Integer>;

var
  GSpsc: TIntSpsc;
  GMpmc: TIntMpmc;
  GMpsc: TIntMpsc;
  GStack: TIntStack;
  GDeque: TIntDeque;
  GSegQueue: TIntSegQueue;
  GSpmc: TIntSpmc;
  GValue: Integer;
  GInput: array[0..1] of Integer;
  GOutput: array[0..1] of Integer;
  GCount: PtrUInt;

procedure TouchSpscFacade;
begin
  GSpsc := TIntSpsc.Create(2);
  try
    GInput[0] := 1;
    GInput[1] := 2;
    if GSpsc.TryEnqueue(1) then
      GValue := 1;
    if GSpsc.TryDequeue(GValue) then
      GValue := GValue + 1;
    if GSpsc.EnqueueWait(2) then
      GValue := GValue + 1;
    if GSpsc.DequeueWait(GValue) then
      GValue := GValue + 1;
    if GSpsc.EnqueueTimeout(3, 0) then
      GValue := GValue + 1;
    if GSpsc.DequeueTimeout(GValue, 0) then
      GValue := GValue + 1;
    GCount := GSpsc.EnqueueBatch(GInput);
    GCount := GCount + GSpsc.DequeueBatch(GOutput, 2);
    GCount := GCount + GSpsc.Capacity + GSpsc.ApproxCount;
    if GSpsc.IsEmpty or GSpsc.IsFull then
      GValue := GValue + 1;
    GSpsc.Close;
    if GSpsc.IsClosed then
      GValue := GValue + 1;
  finally
    GSpsc.Free;
  end;
end;

procedure TouchMpmcFacade;
begin
  GMpmc := TIntMpmc.Create(2);
  try
    GInput[0] := 1;
    GInput[1] := 2;
    if GMpmc.TryEnqueue(1) then
      GValue := 1;
    if GMpmc.TryDequeue(GValue) then
      GValue := GValue + 1;
    if GMpmc.EnqueueWait(2) then
      GValue := GValue + 1;
    if GMpmc.DequeueWait(GValue) then
      GValue := GValue + 1;
    if GMpmc.EnqueueTimeout(3, 0) then
      GValue := GValue + 1;
    if GMpmc.DequeueTimeout(GValue, 0) then
      GValue := GValue + 1;
    GCount := GMpmc.EnqueueBatch(GInput);
    GCount := GCount + GMpmc.DequeueBatch(GOutput, 2);
    GCount := GCount + GMpmc.Capacity + GMpmc.ApproxCount;
    if GMpmc.IsEmpty or GMpmc.IsFull then
      GValue := GValue + 1;
    GMpmc.Close;
    if GMpmc.IsClosed then
      GValue := GValue + 1;
  finally
    GMpmc.Free;
  end;
end;

procedure TouchMpscFacade;
begin
  GMpsc := TIntMpsc.Create;
  try
    GMpsc.Enqueue(1);
    if GMpsc.TryDequeue(GValue) then
      GValue := GValue + 1;
    GMpsc.Enqueue(2);
    if GMpsc.DequeueWait(GValue) then
      GValue := GValue + 1;
    GMpsc.Enqueue(3);
    if GMpsc.DequeueTimeout(GValue, 0) then
      GValue := GValue + 1;
    if GMpsc.IsEmpty then
      GValue := GValue + 1;
    GMpsc.Close;
    if GMpsc.IsClosed then
      GValue := GValue + 1;
  finally
    GMpsc.Free;
  end;
end;

procedure TouchStackFacade;
begin
  GStack := TIntStack.Create(2);
  try
    if GStack.TryPush(1) then
      GValue := 1;
    if GStack.TryPop(GValue) then
      GValue := GValue + 1;
    GCount := GCount + GStack.ApproxCount;
    if GStack.IsEmpty then
      GValue := GValue + 1;
  finally
    GStack.Free;
  end;
end;

procedure TouchDequeFacade;
begin
  GDeque := TIntDeque.Create(2);
  try
    if GDeque.TryPush(1) then
      GValue := 1;
    if GDeque.TryPop(GValue) then
      GValue := GValue + 1;
    if GDeque.TrySteal(GValue) then
      GValue := GValue + 1;
    GCount := GCount + GDeque.Capacity + GDeque.ApproxCount;
    if GDeque.IsEmpty then
      GValue := GValue + 1;
  finally
    GDeque.Free;
  end;
end;

procedure TouchSegQueueFacade;
begin
  GSegQueue := TIntSegQueue.Create;
  try
    GSegQueue.Enqueue(1);
    if GSegQueue.TryDequeue(GValue) then
      GValue := GValue + 1;
    GCount := GCount + GSegQueue.ApproxCount;
    if GSegQueue.IsEmpty then
      GValue := GValue + 1;
  finally
    GSegQueue.Free;
  end;
end;

procedure TouchSpmcFacade;
begin
  GSpmc := TIntSpmc.Create(2);
  try
    if GSpmc.TryEnqueue(1) then
      GValue := 1;
    if GSpmc.TryDequeue(GValue) then
      GValue := GValue + 1;
    if GSpmc.EnqueueWait(2) then
      GValue := GValue + 1;
    if GSpmc.DequeueWait(GValue) then
      GValue := GValue + 1;
    if GSpmc.EnqueueTimeout(3, 0) then
      GValue := GValue + 1;
    if GSpmc.DequeueTimeout(GValue, 0) then
      GValue := GValue + 1;
    GCount := GCount + GSpmc.Capacity + GSpmc.ApproxCount;
    if GSpmc.IsEmpty or GSpmc.IsFull then
      GValue := GValue + 1;
  finally
    GSpmc.Free;
  end;
end;

begin
  TouchSpscFacade;
  TouchMpmcFacade;
  TouchMpscFacade;
  TouchStackFacade;
  TouchDequeFacade;
  TouchSegQueueFacade;
  TouchSpmcFacade;
end.
