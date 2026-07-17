program test_lockfree_bitset;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.lockfree.bitset;

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

procedure TestBasicSetClear;
var
  BS: TConcurrentBitSet;
begin
  WriteLn('--- TestBasicSetClear ---');
  BS := TConcurrentBitSet.Create(128);
  try
    Check(not BS.TestBit(0), 'bit 0 initially clear');
    Check(BS.SetBit(0) = bsOk, 'set bit 0');
    Check(BS.TestBit(0), 'bit 0 is set');
    Check(BS.ClearBit(0) = bsOk, 'clear bit 0');
    Check(not BS.TestBit(0), 'bit 0 is clear');
  finally
    BS.Free;
  end;
end;

procedure TestMultipleBits;
var
  BS: TConcurrentBitSet;
  I: Integer;
begin
  WriteLn('--- TestMultipleBits ---');
  BS := TConcurrentBitSet.Create(256);
  try
    for I := 0 to 255 do
      BS.SetBit(I);
    for I := 0 to 255 do
      Check(BS.TestBit(I), 'bit ' + IntToStr(I));
    Check(BS.PopCount = 256, 'popcount = 256');
  finally
    BS.Free;
  end;
end;

procedure TestFlip;
var
  BS: TConcurrentBitSet;
begin
  WriteLn('--- TestFlip ---');
  BS := TConcurrentBitSet.Create;
  try
    Check(not BS.TestBit(42), 'bit 42 initially clear');
    BS.FlipBit(42);
    Check(BS.TestBit(42), 'bit 42 flipped to set');
    BS.FlipBit(42);
    Check(not BS.TestBit(42), 'bit 42 flipped back to clear');
  finally
    BS.Free;
  end;
end;

procedure TestTestAndSet;
var
  BS: TConcurrentBitSet;
begin
  WriteLn('--- TestTestAndSet ---');
  BS := TConcurrentBitSet.Create;
  try
    Check(not BS.TestAndSet(10), 'test-and-set returns false (was clear)');
    Check(BS.TestAndSet(10), 'test-and-set returns true (was set)');
    Check(BS.TestBit(10), 'bit is set');
  finally
    BS.Free;
  end;
end;

procedure TestTestAndClear;
var
  BS: TConcurrentBitSet;
begin
  WriteLn('--- TestTestAndClear ---');
  BS := TConcurrentBitSet.Create;
  try
    BS.SetBit(20);
    Check(BS.TestAndClear(20), 'test-and-clear returns true (was set)');
    Check(not BS.TestAndClear(20), 'test-and-clear returns false (was clear)');
    Check(not BS.TestBit(20), 'bit is clear');
  finally
    BS.Free;
  end;
end;

procedure TestClear;
var
  BS: TConcurrentBitSet;
  I: Integer;
begin
  WriteLn('--- TestClear ---');
  BS := TConcurrentBitSet.Create(128);
  try
    for I := 0 to 127 do
      BS.SetBit(I);
    BS.Clear;
    for I := 0 to 127 do
      Check(not BS.TestBit(I), 'bit ' + IntToStr(I) + ' cleared');
    Check(BS.PopCount = 0, 'popcount = 0');
  finally
    BS.Free;
  end;
end;

procedure TestGrow;
var
  BS: TConcurrentBitSet;
begin
  WriteLn('--- TestGrow ---');
  BS := TConcurrentBitSet.Create(32);  // Small initial size
  try
    BS.SetBit(100);  // Should trigger growth
    Check(BS.TestBit(100), 'bit 100 set after grow');
    BS.SetBit(500);  // Should trigger more growth
    Check(BS.TestBit(500), 'bit 500 set after grow');
    Check(BS.TestBit(100), 'bit 100 still set');
  finally
    BS.Free;
  end;
end;

procedure TestIndexOutOfRange;
var
  BS: TConcurrentBitSet;
begin
  WriteLn('--- TestIndexOutOfRange ---');
  BS := TConcurrentBitSet.Create;
  try
    Check(BS.ClearBit(999) = bsIndexOutOfRange, 'clear out of range');
    Check(not BS.TestBit(999), 'test out of range returns false');
    Check(not BS.TestBit(-1), 'test negative returns false');
  finally
    BS.Free;
  end;
end;

procedure TestLargeScale;
var
  BS: TConcurrentBitSet;
  I, LN: Integer;
begin
  WriteLn('--- TestLargeScale ---');
  LN := 10000;
  BS := TConcurrentBitSet.Create(LN);
  try
    for I := 0 to LN - 1 do
      BS.SetBit(I);
    Check(BS.PopCount = LN, 'popcount = ' + IntToStr(LN));
    for I := 0 to LN - 1 do
      Check(BS.TestBit(I), 'bit ' + IntToStr(I));
  finally
    BS.Free;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicSetClear;
  TestMultipleBits;
  TestFlip;
  TestTestAndSet;
  TestTestAndClear;
  TestClear;
  TestGrow;
  TestIndexOutOfRange;
  TestLargeScale;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
