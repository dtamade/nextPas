program test_ring_buffer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.ring_buffer;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LBuf: TRingBuffer;
begin
  LBuf := TRingBuffer.Create(8, SizeOf(Integer));
  try
    Check(LBuf.Capacity = 8, 'capacity=8');
    Check(LBuf.ElementSize = SizeOf(Integer), 'element size');
    Check(LBuf.Count = 0, 'initial count=0');
    Check(LBuf.IsEmpty, 'initial empty');
    Check(not LBuf.IsFull, 'initial not full');
  finally
    LBuf.Free;
  end;
end;

procedure TestCreatePow2;
var
  LBuf: TRingBuffer;
begin
  LBuf := TRingBuffer.Create(16, SizeOf(Byte));
  try
    Check(LBuf.Capacity = 16, 'pow2 capacity');
  finally
    LBuf.Free;
  end;
end;

procedure TestCreateNonPow2;
var
  LBuf: TRingBuffer;
begin
  LBuf := TRingBuffer.Create(10, SizeOf(Byte));
  try
    Check(LBuf.Capacity = 10, 'non-pow2 capacity');
  finally
    LBuf.Free;
  end;
end;

{ --- 单元素 Push/Pop --- }

procedure TestPushPopSingle;
var
  LBuf: TRingBuffer;
  LVal, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 42;
    Check(LBuf.Push(@LVal), 'push should succeed');
    Check(LBuf.Count = 1, 'count=1 after push');
    Check(not LBuf.IsEmpty, 'not empty after push');

    LOut := 0;
    Check(LBuf.Pop(@LOut), 'pop should succeed');
    Check(LOut = 42, 'popped value=42');
    Check(LBuf.Count = 0, 'count=0 after pop');
    Check(LBuf.IsEmpty, 'empty after pop');
  finally
    LBuf.Free;
  end;
end;

procedure TestPushPopSequence;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 1 to 4 do
      Check(LBuf.Push(@I), 'push ' + IntToStr(I));
    Check(LBuf.IsFull, 'full after 4 pushes');
    Check(LBuf.Count = 4, 'count=4');

    for I := 1 to 4 do
    begin
      LOut := 0;
      Check(LBuf.Pop(@LOut), 'pop ' + IntToStr(I));
      Check(LOut = I, 'value=' + IntToStr(I));
    end;
    Check(LBuf.IsEmpty, 'empty after 4 pops');
  finally
    LBuf.Free;
  end;
end;

{ --- TryPush / TryPop --- }

procedure TestTryPushFull;
var
  LBuf: TRingBuffer;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(2, SizeOf(Integer));
  try
    I := 1; Check(LBuf.TryPush(@I) = rrOk, 'try push 1');
    I := 2; Check(LBuf.TryPush(@I) = rrOk, 'try push 2');
    I := 3; Check(LBuf.TryPush(@I) = rrFull, 'try push 3 should be full');
  finally
    LBuf.Free;
  end;
end;

procedure TestTryPopEmpty;
var
  LBuf: TRingBuffer;
  LOut: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    Check(LBuf.TryPop(@LOut) = rrEmpty, 'try pop from empty');
  finally
    LBuf.Free;
  end;
end;

procedure TestTryPushNilArg;
var
  LBuf: TRingBuffer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    Check(LBuf.TryPush(nil) = rrBadArg, 'nil push should be bad arg');
  finally
    LBuf.Free;
  end;
end;

{ --- Peek --- }

procedure TestPeek;
var
  LBuf: TRingBuffer;
  LVal, LPeek: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 99;
    LBuf.Push(@LVal);

    LPeek := 0;
    Check(LBuf.Peek(@LPeek), 'peek should succeed');
    Check(LPeek = 99, 'peek value=99');
    Check(LBuf.Count = 1, 'peek does not remove');
  finally
    LBuf.Free;
  end;
end;

procedure TestPeekWithOffset;
var
  LBuf: TRingBuffer;
  I, LPeek: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 10 to 12 do
      LBuf.Push(@I);

    LPeek := 0;
    Check(LBuf.Peek(@LPeek, 0), 'peek offset 0');
    Check(LPeek = 10, 'offset 0 = 10');

    Check(LBuf.Peek(@LPeek, 1), 'peek offset 1');
    Check(LPeek = 11, 'offset 1 = 11');

    Check(LBuf.Peek(@LPeek, 2), 'peek offset 2');
    Check(LPeek = 12, 'offset 2 = 12');

    Check(not LBuf.Peek(@LPeek, 3), 'peek offset 3 out of range');
  finally
    LBuf.Free;
  end;
end;

procedure TestPeekEmpty;
var
  LBuf: TRingBuffer;
  LOut: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    Check(not LBuf.Peek(@LOut), 'peek from empty should fail');
  finally
    LBuf.Free;
  end;
end;

{ --- Clear --- }

procedure TestClear;
var
  LBuf: TRingBuffer;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 1 to 3 do
      LBuf.Push(@I);
    Check(LBuf.Count = 3, 'count=3 before clear');

    LBuf.Clear;
    Check(LBuf.Count = 0, 'count=0 after clear');
    Check(LBuf.IsEmpty, 'empty after clear');
  finally
    LBuf.Free;
  end;
end;

{ --- Resize --- }

procedure TestResizeGrow;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 1 to 4 do
      LBuf.Push(@I);

    Check(LBuf.Resize(8), 'resize grow should succeed');
    Check(LBuf.Capacity = 8, 'new capacity=8');
    Check(LBuf.Count = 4, 'count preserved');

    for I := 1 to 4 do
    begin
      LOut := 0;
      Check(LBuf.Pop(@LOut), 'pop after resize ' + IntToStr(I));
      Check(LOut = I, 'value preserved');
    end;
  finally
    LBuf.Free;
  end;
end;

procedure TestResizeShrink;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(8, SizeOf(Integer));
  try
    for I := 1 to 3 do
      LBuf.Push(@I);

    Check(LBuf.Resize(3), 'resize shrink to count should succeed');
    Check(LBuf.Capacity = 3, 'new capacity=3');
    Check(LBuf.Count = 3, 'count preserved');

    for I := 1 to 3 do
    begin
      LOut := 0;
      Check(LBuf.Pop(@LOut), 'pop after shrink');
      Check(LOut = I, 'value preserved');
    end;
  finally
    LBuf.Free;
  end;
end;

procedure TestResizeTruncate;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(8, SizeOf(Integer));
  try
    for I := 1 to 4 do
      LBuf.Push(@I);

    { Resize below count truncates to oldest elements }
    Check(LBuf.Resize(2), 'resize truncate should succeed');
    Check(LBuf.Capacity = 2, 'new capacity=2');
    Check(LBuf.Count = 2, 'count truncated to 2');

    { Oldest elements preserved }
    LOut := 0;
    Check(LBuf.Pop(@LOut), 'pop after truncate');
    Check(LOut = 1, 'oldest element=1');
    LOut := 0;
    Check(LBuf.Pop(@LOut), 'pop second');
    Check(LOut = 2, 'second oldest=2');
    Check(LBuf.IsEmpty, 'empty after popping truncated');
  finally
    LBuf.Free;
  end;
end;

procedure TestBoundaryResizeFullToLarger;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    { Fill to capacity. }
    for I := 1 to 4 do
      LBuf.Push(@I);
    Check(LBuf.IsFull, 'should be full at capacity 4');
    Check(LBuf.Count = 4, 'count=4');

    { Grow while full — all 4 elements must survive. }
    Check(LBuf.Resize(8), 'resize full to larger');
    Check(LBuf.Capacity = 8, 'new capacity=8');
    Check(LBuf.Count = 4, 'count preserved');
    Check(not LBuf.IsFull, 'no longer full');

    { Verify element order. }
    for I := 1 to 4 do
    begin
      LOut := 0;
      Check(LBuf.Pop(@LOut), 'pop after grow ' + IntToStr(I));
      Check(LOut = I, 'element order ' + IntToStr(I));
    end;
    Check(LBuf.IsEmpty, 'empty after all pops');
  finally
    LBuf.Free;
  end;
end;

{ --- 批量 Push/Pop --- }

procedure TestBatchPushPop;
var
  LBuf: TRingBuffer;
  LData: array[0..4] of Integer;
  LOut: array[0..4] of Integer;
  LPushed, LPopped: SizeUInt;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(8, SizeOf(Integer));
  try
    for I := 0 to 4 do
      LData[I] := (I + 1) * 10;

    Check(LBuf.Push(@LData[0], 5, LPushed), 'batch push 5');
    Check(LPushed = 5, 'pushed=5');
    Check(LBuf.Count = 5, 'count=5');

    FillChar(LOut, SizeOf(LOut), 0);
    Check(LBuf.Pop(@LOut[0], 5, LPopped), 'batch pop 5');
    Check(LPopped = 5, 'popped=5');

    for I := 0 to 4 do
      Check(LOut[I] = (I + 1) * 10, 'batch value ' + IntToStr(I));
  finally
    LBuf.Free;
  end;
end;

procedure TestBatchPushPartial;
var
  LBuf: TRingBuffer;
  LData: array[0..9] of Integer;
  LPushed: SizeUInt;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 0 to 9 do
      LData[I] := I;

    Check(LBuf.Push(@LData[0], 10, LPushed), 'batch push partial');
    Check(LPushed = 4, 'only 4 pushed (capacity limit)');
    Check(LBuf.IsFull, 'full after partial push');
  finally
    LBuf.Free;
  end;
end;

procedure TestBatchPopPartial;
var
  LBuf: TRingBuffer;
  LData: Integer;
  LOut: array[0..9] of Integer;
  LPopped: SizeUInt;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(8, SizeOf(Integer));
  try
    for I := 1 to 3 do
    begin
      LData := I * 100;
      LBuf.Push(@LData);
    end;

    FillChar(LOut, SizeOf(LOut), 0);
    Check(LBuf.Pop(@LOut[0], 10, LPopped), 'batch pop partial');
    Check(LPopped = 3, 'only 3 popped');
    Check(LOut[0] = 100, 'out[0]=100');
    Check(LOut[1] = 200, 'out[1]=200');
    Check(LOut[2] = 300, 'out[2]=300');
  finally
    LBuf.Free;
  end;
end;

{ --- Wrap-around (pow2 和 non-pow2) --- }

procedure TestWrapAroundPow2;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 1 to 4 do
      LBuf.Push(@I);
    for I := 1 to 4 do
      LBuf.Pop(@LOut);

    for I := 10 to 13 do
      Check(LBuf.Push(@I), 'wrap push ' + IntToStr(I));
    Check(LBuf.IsFull, 'full after wrap');

    for I := 10 to 13 do
    begin
      LOut := 0;
      Check(LBuf.Pop(@LOut), 'wrap pop');
      Check(LOut = I, 'wrap value=' + IntToStr(I));
    end;
  finally
    LBuf.Free;
  end;
end;

procedure TestWrapAroundNonPow2;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(5, SizeOf(Integer));
  try
    for I := 1 to 5 do
      LBuf.Push(@I);
    for I := 1 to 5 do
      LBuf.Pop(@LOut);

    for I := 10 to 14 do
      Check(LBuf.Push(@I), 'wrap push non-pow2');
    Check(LBuf.IsFull, 'full after non-pow2 wrap');

    for I := 10 to 14 do
    begin
      LOut := 0;
      Check(LBuf.Pop(@LOut), 'wrap pop non-pow2');
      Check(LOut = I, 'wrap value non-pow2');
    end;
  finally
    LBuf.Free;
  end;
end;

{ --- GetElementAt / SetElementAt --- }

procedure TestGetSetElementAt;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 1 to 3 do
      LBuf.Push(@I);

    LOut := 0;
    Check(LBuf.GetElementAt(0, @LOut), 'get[0]');
    Check(LOut = 1, 'elem[0]=1');
    Check(LBuf.GetElementAt(2, @LOut), 'get[2]');
    Check(LOut = 3, 'elem[2]=3');
    Check(not LBuf.GetElementAt(3, @LOut), 'get[3] out of range');

    I := 99;
    Check(LBuf.SetElementAt(1, @I), 'set[1]=99');
    LOut := 0;
    Check(LBuf.GetElementAt(1, @LOut), 'get[1] after set');
    Check(LOut = 99, 'elem[1]=99');
  finally
    LBuf.Free;
  end;
end;

{ --- FindElement / ContainsElement --- }

procedure TestFindAndContains;
var
  LBuf: TRingBuffer;
  I, LSearch: Integer;
begin
  LBuf := TRingBuffer.Create(8, SizeOf(Integer));
  try
    for I := 1 to 5 do
      LBuf.Push(@I);

    LSearch := 3;
    Check(LBuf.FindElement(@LSearch) = 2, 'find 3 at index 2');
    Check(LBuf.ContainsElement(@LSearch), 'contains 3');

    LSearch := 99;
    Check(LBuf.FindElement(@LSearch) = -1, 'find 99 not found');
    Check(not LBuf.ContainsElement(@LSearch), 'not contains 99');
  finally
    LBuf.Free;
  end;
end;

{ --- DropElements --- }

procedure TestDropElements;
var
  LBuf: TRingBuffer;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(8, SizeOf(Integer));
  try
    for I := 1 to 5 do
      LBuf.Push(@I);

    Check(LBuf.DropElements(2) = 2, 'drop 2');
    Check(LBuf.Count = 3, 'count=3 after drop');

    LOut := 0;
    Check(LBuf.Pop(@LOut), 'pop after drop');
    Check(LOut = 3, 'first remaining=3');
  finally
    LBuf.Free;
  end;
end;

procedure TestDropMoreThanCount;
var
  LBuf: TRingBuffer;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 1 to 2 do
      LBuf.Push(@I);

    Check(LBuf.DropElements(10) = 2, 'drop capped to count');
    Check(LBuf.IsEmpty, 'empty after over-drop');
  finally
    LBuf.Free;
  end;
end;

{ --- GetContiguousWriteSpan / ReadSpan --- }

procedure TestContiguousSpans;
var
  LBuf: TRingBuffer;
  LPtr: Pointer;
  LLen: SizeUInt;
  I, LOut: Integer;
begin
  LBuf := TRingBuffer.Create(8, SizeOf(Integer));
  try
    LBuf.GetContiguousWriteSpan(LPtr, LLen);
    Check(LPtr <> nil, 'write span ptr not nil');
    Check(LLen = 8, 'write span len=8 (empty buffer)');

    for I := 1 to 5 do
      LBuf.Push(@I);

    LBuf.GetContiguousReadSpan(LPtr, LLen);
    Check(LPtr <> nil, 'read span ptr not nil');
    Check(LLen >= 1, 'read span has data');

    for I := 1 to 5 do
    begin
      LOut := 0;
      LBuf.Pop(@LOut);
    end;

    LBuf.GetContiguousReadSpan(LPtr, LLen);
    Check(LLen = 0, 'read span len=0 when empty');
  finally
    LBuf.Free;
  end;
end;

{ --- 状态查询属性 --- }

procedure TestUsageRatio;
var
  LBuf: TRingBuffer;
  I: Integer;
  LRatio: Single;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LRatio := LBuf.GetUsageRatio;
    Check(LRatio < 0.01, 'empty ratio ~0');

    for I := 1 to 2 do
      LBuf.Push(@I);
    LRatio := LBuf.GetUsageRatio;
    Check((LRatio > 0.49) and (LRatio < 0.51), 'half ratio ~0.5');
    Check((LBuf.GetUsagePercent > 49) and (LBuf.GetUsagePercent < 51), 'half percent ~50');
  finally
    LBuf.Free;
  end;
end;

procedure TestAvailableSpace;
var
  LBuf: TRingBuffer;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    Check(LBuf.GetAvailableSpace = 4, 'full space=4');

    for I := 1 to 2 do
      LBuf.Push(@I);
    Check(LBuf.GetAvailableSpace = 2, 'space=2 after 2 pushes');
  finally
    LBuf.Free;
  end;
end;

{ --- 大元素 Large elements --- }

procedure TestLargeElements;
type
  TBigRecord = record
    Data: array[0..255] of Byte;
    ID: Integer;
  end;
var
  LBuf: TRingBuffer;
  LA, LB: TBigRecord;
  I: Integer;
  LAllMatch: Boolean;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(TBigRecord));
  try
    FillChar(LA, SizeOf(LA), 0);
    for I := 0 to 255 do
      LA.Data[I] := Byte(I);
    LA.ID := 12345;

    Check(LBuf.Push(@LA), 'push big record');
    FillChar(LB, SizeOf(LB), 0);
    Check(LBuf.Pop(@LB), 'pop big record');

    Check(LB.ID = 12345, 'big record ID preserved');
    LAllMatch := True;
    for I := 0 to 255 do
    begin
      if LB.Data[I] <> Byte(I) then
      begin
        LAllMatch := False;
        Break;
      end;
    end;
    Check(LAllMatch, 'big record data verified');
  finally
    LBuf.Free;
  end;
end;

{ --- byte-size 元素 --- }

procedure TestByteElements;
var
  LBuf: TRingBuffer;
  B, LOut: Byte;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(16, SizeOf(Byte));
  try
    for I := 0 to 15 do
    begin
      B := Byte(I);
      Check(LBuf.Push(@B), 'push byte ' + IntToStr(I));
    end;
    Check(LBuf.IsFull, 'full at 16 bytes');

    for I := 0 to 15 do
    begin
      LOut := 0;
      Check(LBuf.Pop(@LOut), 'pop byte');
      Check(LOut = Byte(I), 'byte value=' + IntToStr(I));
    end;
  finally
    LBuf.Free;
  end;
end;

{ --- wrap-around 批量 Push (数据跨越缓冲区末尾) --- }

procedure TestBatchPushWrapAround;
var
  LBuf: TRingBuffer;
  LData: array[0..5] of Integer;
  LOut: Integer;
  LPushed: SizeUInt;
  I: Integer;
begin
  LBuf := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for I := 1 to 3 do
      LBuf.Push(@I);
    for I := 1 to 3 do
      LBuf.Pop(@LOut);

    for I := 0 to 5 do
      LData[I] := (I + 1) * 10;

    LBuf.Push(@LData[0], 4, LPushed);
    Check(LPushed = 4, 'batch wrap push=4');
    Check(LBuf.IsFull, 'full after wrap batch push');

    for I := 0 to 3 do
    begin
      LOut := 0;
      LBuf.Pop(@LOut);
      Check(LOut = (I + 1) * 10, 'wrap batch value=' + IntToStr(LOut));
    end;
  finally
    LBuf.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.ring_buffer');

  { 基础生命周期 }
  T.Test('create/destroy basic', @TestCreateDestroy);
  T.Test('create pow2 capacity', @TestCreatePow2);
  T.Test('create non-pow2 capacity', @TestCreateNonPow2);

  { 单元素 Push/Pop }
  T.Test('push/pop single element', @TestPushPopSingle);
  T.Test('push/pop sequence fills and drains', @TestPushPopSequence);

  { TryPush / TryPop }
  T.Test('try push returns full', @TestTryPushFull);
  T.Test('try pop returns empty', @TestTryPopEmpty);
  T.Test('try push nil arg', @TestTryPushNilArg);

  { Peek }
  T.Test('peek basic', @TestPeek);
  T.Test('peek with offset', @TestPeekWithOffset);
  T.Test('peek empty fails', @TestPeekEmpty);

  { Clear }
  T.Test('clear resets state', @TestClear);

  { Resize }
  T.Test('resize grow preserves data', @TestResizeGrow);
  T.Test('resize shrink preserves data', @TestResizeShrink);
  T.Test('resize truncates to oldest elements', @TestResizeTruncate);
  T.Test('boundary resize full to larger', @TestBoundaryResizeFullToLarger);

  { 批量 Push/Pop }
  T.Test('batch push/pop 5 elements', @TestBatchPushPop);
  T.Test('batch push partial (capacity limit)', @TestBatchPushPartial);
  T.Test('batch pop partial (fewer available)', @TestBatchPopPartial);

  { Wrap-around }
  T.Test('wrap-around pow2 capacity', @TestWrapAroundPow2);
  T.Test('wrap-around non-pow2 capacity', @TestWrapAroundNonPow2);

  { GetElementAt / SetElementAt }
  T.Test('get/set element at index', @TestGetSetElementAt);

  { FindElement / ContainsElement }
  T.Test('find and contains element', @TestFindAndContains);

  { DropElements }
  T.Test('drop elements', @TestDropElements);
  T.Test('drop more than count', @TestDropMoreThanCount);

  { Contiguous spans }
  T.Test('contiguous write/read spans', @TestContiguousSpans);

  { 状态查询 }
  T.Test('usage ratio and percent', @TestUsageRatio);
  T.Test('available space', @TestAvailableSpace);

  { 大元素 / byte }
  T.Test('large 260-byte elements', @TestLargeElements);
  T.Test('byte-size elements pow2', @TestByteElements);

  { Batch wrap-around }
  T.Test('batch push wrap-around', @TestBatchPushWrapAround);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
