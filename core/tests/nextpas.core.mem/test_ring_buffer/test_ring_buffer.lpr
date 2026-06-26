program test_ring_buffer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.ring_buffer;

var
  T: TTestSuite;

procedure TestCreateAndBasicProps;
var
  LRing: TRingBuffer;
begin
  LRing := TRingBuffer.Create(8, 4);
  try
    Check(LRing.Capacity = 8, 'Capacity should be 8');
    Check(LRing.ElementSize = 4, 'ElementSize should be 4');
    Check(LRing.Count = 0, 'Count should be 0');
    Check(LRing.IsEmpty, 'Should be empty');
    Check(not LRing.IsFull, 'Should not be full');
  finally
    LRing.Free;
  end;
end;

procedure TestPushPopSingle;
var
  LRing: TRingBuffer;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 42;
    Check(LRing.Push(@LVal), 'Push should succeed');
    Check(LRing.Count = 1, 'Count should be 1');
    Check(not LRing.IsEmpty, 'Should not be empty');

    LVal := 0;
    Check(LRing.Pop(@LVal), 'Pop should succeed');
    Check(LVal = 42, 'Popped value should be 42');
    Check(LRing.Count = 0, 'Count should be 0');
    Check(LRing.IsEmpty, 'Should be empty');
  finally
    LRing.Free;
  end;
end;

procedure TestPushUntilFull;
var
  LRing: TRingBuffer;
  LVal: Integer;
  LI: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for LI := 1 to 4 do
    begin
      LVal := LI * 10;
      Check(LRing.Push(@LVal), 'Push ' + IntToStr(LI) + ' should succeed');
    end;
    Check(LRing.IsFull, 'Should be full after 4 pushes');
    Check(LRing.Count = 4, 'Count should be 4');

    LVal := 99;
    Check(not LRing.Push(@LVal), 'Push on full ring should fail');
  finally
    LRing.Free;
  end;
end;

procedure TestPopEmpty;
var
  LRing: TRingBuffer;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 0;
    Check(not LRing.Pop(@LVal), 'Pop on empty ring should fail');
  finally
    LRing.Free;
  end;
end;

procedure TestWrapAround;
var
  LRing: TRingBuffer;
  LVal: Integer;
  LI: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    { Fill and drain twice to exercise wrap-around }
    for LI := 0 to 1 do
    begin
      LVal := 100 + LI;
      Check(LRing.Push(@LVal), 'Push should succeed');
      Check(LRing.Pop(@LVal), 'Pop should succeed');
      Check(LVal = 100 + LI, 'Value should match');
    end;
    Check(LRing.IsEmpty, 'Should be empty after wrap-around cycle');

    { Fill completely, drain, fill again }
    for LI := 1 to 4 do
    begin
      LVal := LI;
      Check(LRing.Push(@LVal), 'Push ' + IntToStr(LI));
    end;
    for LI := 1 to 4 do
    begin
      Check(LRing.Pop(@LVal), 'Pop ' + IntToStr(LI));
      Check(LVal = LI, 'Value should be ' + IntToStr(LI));
    end;
    for LI := 5 to 8 do
    begin
      LVal := LI;
      Check(LRing.Push(@LVal), 'Push round 2 ' + IntToStr(LI));
    end;
    Check(LRing.Pop(@LVal), 'Pop round 2');
    Check(LVal = 5, 'First pop of round 2 should be 5');
  finally
    LRing.Free;
  end;
end;

procedure TestTryPushTryPop;
var
  LRing: TRingBuffer;
  LVal: Integer;
  LRes: TRingOpResult;
begin
  LRing := TRingBuffer.Create(2, SizeOf(Integer));
  try
    LVal := 1;
    LRes := LRing.TryPush(@LVal);
    Check(LRes = rrOk, 'TryPush should succeed');

    LVal := 2;
    LRes := LRing.TryPush(@LVal);
    Check(LRes = rrOk, 'TryPush 2 should succeed');

    LVal := 3;
    LRes := LRing.TryPush(@LVal);
    Check(LRes = rrFull, 'TryPush on full should return rrFull');

    LVal := 0;
    LRes := LRing.TryPop(@LVal);
    Check(LRes = rrOk, 'TryPop should succeed');
    Check(LVal = 1, 'First pop should be 1');

    LRes := LRing.TryPop(@LVal);
    Check(LRes = rrOk, 'TryPop 2 should succeed');
    Check(LVal = 2, 'Second pop should be 2');

    LRes := LRing.TryPop(@LVal);
    Check(LRes = rrEmpty, 'TryPop on empty should return rrEmpty');
  finally
    LRing.Free;
  end;
end;

procedure TestPeek;
var
  LRing: TRingBuffer;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 10;
    LRing.Push(@LVal);
    LVal := 20;
    LRing.Push(@LVal);

    LVal := 0;
    Check(LRing.Peek(@LVal), 'Peek should succeed');
    Check(LVal = 10, 'Peek should return first element');
    Check(LRing.Count = 2, 'Peek should not remove element');

    LVal := 0;
    Check(LRing.Peek(@LVal, 1), 'Peek offset 1 should succeed');
    Check(LVal = 20, 'Peek offset 1 should return second element');

    Check(not LRing.Peek(@LVal, 2), 'Peek offset 2 should fail (out of range)');
  finally
    LRing.Free;
  end;
end;

procedure TestClear;
var
  LRing: TRingBuffer;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 1;
    LRing.Push(@LVal);
    LVal := 2;
    LRing.Push(@LVal);
    Check(LRing.Count = 2, 'Count should be 2');

    LRing.Clear;
    Check(LRing.Count = 0, 'Count should be 0 after clear');
    Check(LRing.IsEmpty, 'Should be empty after clear');
  finally
    LRing.Free;
  end;
end;

procedure TestResize;
var
  LRing: TRingBuffer;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 1;
    LRing.Push(@LVal);
    LVal := 2;
    LRing.Push(@LVal);

    Check(LRing.Resize(8), 'Resize to 8 should succeed');
    Check(LRing.Capacity = 8, 'Capacity should be 8');
    Check(LRing.Count = 2, 'Count should be preserved');

    LVal := 0;
    Check(LRing.Pop(@LVal), 'Pop after resize');
    Check(LVal = 1, 'First element should survive resize');
    Check(LRing.Pop(@LVal), 'Pop 2 after resize');
    Check(LVal = 2, 'Second element should survive resize');
  finally
    LRing.Free;
  end;
end;

procedure TestBatchPushPop;
var
  LRing: TRingBuffer;
  LBuf: array[0..3] of Integer;
  LPushed, LPopped: SizeUInt;
  LI: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    for LI := 0 to 3 do
      LBuf[LI] := (LI + 1) * 10;

    Check(LRing.Push(@LBuf[0], 4, LPushed), 'Batch push 4 should succeed');
    Check(LPushed = 4, 'All 4 should be pushed');
    Check(LRing.IsFull, 'Should be full');

    FillChar(LBuf, SizeOf(LBuf), 0);
    Check(LRing.Pop(@LBuf[0], 4, LPopped), 'Batch pop 4 should succeed');
    Check(LPopped = 4, 'All 4 should be popped');

    for LI := 0 to 3 do
      Check(LBuf[LI] = (LI + 1) * 10, 'Batch element ' + IntToStr(LI) + ' should match');
  finally
    LRing.Free;
  end;
end;

procedure TestAvailableSpaceAndUsage;
var
  LRing: TRingBuffer;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(8, SizeOf(Integer));
  try
    Check(LRing.GetAvailableSpace = 8, 'All space should be available');
    Check(LRing.GetUsagePercent < 0.01, 'Usage should be ~0%');

    LVal := 1;
    LRing.Push(@LVal);
    LRing.Push(@LVal);
    Check(LRing.GetAvailableSpace = 6, '6 slots should remain');
    Check(LRing.Count = 2, 'Count should be 2');
  finally
    LRing.Free;
  end;
end;

procedure TestFindAndContains;
var
  LRing: TRingBuffer;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 10;
    LRing.Push(@LVal);
    LVal := 20;
    LRing.Push(@LVal);
    LVal := 30;
    LRing.Push(@LVal);

    LVal := 20;
    Check(LRing.FindElement(@LVal) >= 0, 'FindElement(20) should find it');
    Check(LRing.ContainsElement(@LVal), 'ContainsElement(20) should be true');

    LVal := 99;
    Check(LRing.FindElement(@LVal) < 0, 'FindElement(99) should not find it');
    Check(not LRing.ContainsElement(@LVal), 'ContainsElement(99) should be false');
  finally
    LRing.Free;
  end;
end;

procedure TestGetElementAt;
var
  LRing: TRingBuffer;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LVal := 10;
    LRing.Push(@LVal);
    LVal := 20;
    LRing.Push(@LVal);

    LVal := 0;
    Check(LRing.GetElementAt(0, @LVal), 'GetElementAt(0) should succeed');
    Check(LVal = 10, 'Element at 0 should be 10');

    LVal := 0;
    Check(LRing.GetElementAt(1, @LVal), 'GetElementAt(1) should succeed');
    Check(LVal = 20, 'Element at 1 should be 20');

    Check(not LRing.GetElementAt(2, @LVal), 'GetElementAt(2) should fail');
  finally
    LRing.Free;
  end;
end;

procedure TestContiguousSpans;
var
  LRing: TRingBuffer;
  LPtr: Pointer;
  LLen: SizeUInt;
  LVal: Integer;
begin
  LRing := TRingBuffer.Create(4, SizeOf(Integer));
  try
    LRing.GetContiguousWriteSpan(LPtr, LLen);
    Check(LLen <= 4, 'Write span should be <= capacity');

    LVal := 1;
    LRing.Push(@LVal);
    LVal := 2;
    LRing.Push(@LVal);

    LRing.GetContiguousReadSpan(LPtr, LLen);
    Check(LLen >= 1, 'Read span should be >= 1');
    Check(LPtr <> nil, 'Read span pointer should not be nil');
  finally
    LRing.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.ring_buffer');
  T.Test('Create and basic props', @TestCreateAndBasicProps);
  T.Test('Push/Pop single', @TestPushPopSingle);
  T.Test('Push until full', @TestPushUntilFull);
  T.Test('Pop empty', @TestPopEmpty);
  T.Test('Wrap-around', @TestWrapAround);
  T.Test('TryPush/TryPop', @TestTryPushTryPop);
  T.Test('Peek', @TestPeek);
  T.Test('Clear', @TestClear);
  T.Test('Resize', @TestResize);
  T.Test('Batch Push/Pop', @TestBatchPushPop);
  T.Test('Available space and usage', @TestAvailableSpaceAndUsage);
  T.Test('Find and Contains', @TestFindAndContains);
  T.Test('GetElementAt', @TestGetElementAt);
  T.Test('Contiguous spans', @TestContiguousSpans);
  T.Run;

  T.Summary;
end.
