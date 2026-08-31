program test_stream;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.bytes,
  nextpas.core.mem;

var
  T: TTestSuite;

procedure TestAppendConsumeBasic;
var
  B: TByteStreamBuf;
  LData: TBytes;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 0);
  try
    CheckEqual(SizeUInt(0), B.Available, 'empty avail');
    CheckEqual(SizeUInt(0), B.Length, 'empty len');
    B.AppendByte($AA);
    B.AppendByte($BB);
    CheckEqual(SizeUInt(2), B.Available, 'len 2');
    CheckEqual(Byte($AA), B.Data[0], 'byte0');
    CheckEqual(Byte($BB), B.Data[1], 'byte1');
    CheckEqual(SizeUInt(1), B.Consume(1), 'consume 1');
    CheckEqual(SizeUInt(1), B.Available, 'remain 1');
    CheckEqual(Byte($BB), B.Data[0], 'after consume head');
    CheckEqual(SizeUInt(1), B.Consume(10), 'consume beyond = actual');
    CheckEqual(SizeUInt(0), B.Available, 'empty after full consume');
    // Data pointer should remain valid (nil-cap not dereferenced externally)
    LData := TBytes.Create(1, 2, 3, 4, 5);
    B.Append(@LData[0], Length(LData));
    CheckEqual(SizeUInt(5), B.Available, 'append after clear');
    CheckEqual(Byte(1), B.Data[0]);
    CheckEqual(Byte(5), B.Data[4]);
  finally
    B.Free;
  end;
end;

procedure TestTailSpaceAndReserveAppend;
var
  B: TByteStreamBuf;
  P: PByte;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 4096);
  try
    Check(B.Capacity >= 4096, 'initial cap');
    CheckEqual(B.Capacity, B.TailSpace, 'tail = cap when empty');
    P := B.ReserveAppend(100);
    Check(P <> nil, 'reserve ptr');
    P[0] := $11;
    P[99] := $22;
    B.CommitAppend(100);
    CheckEqual(SizeUInt(100), B.Available, 'commit len');
    CheckEqual(Byte($11), B.Data[0]);
    CheckEqual(Byte($22), B.Data[99]);
    CheckEqual(B.Capacity - 100, B.TailSpace, 'tail after append');
    // zero additional should not grow
    P := B.ReserveAppend(0);
    Check(P <> nil, 'reserve 0 non-nil when cap>0');
    B.CommitAppend(0);
    CheckEqual(SizeUInt(100), B.Available, 'unchanged after 0');
  finally
    B.Free;
  end;
end;

procedure TestClearRetainsCapacity;
var
  B: TByteStreamBuf;
  LCap: SizeUInt;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 0);
  try
    B.EnsureCapacity(8192);
    LCap := B.Capacity;
    Check(LCap >= 8192, 'cap after ensure');
    B.AppendByte(1);
    B.AppendByte(2);
    B.Clear;
    CheckEqual(SizeUInt(0), B.Available, 'clear len 0');
    CheckEqual(LCap, B.Capacity, 'cap retained after clear');
    CheckEqual(LCap, B.TailSpace, 'tail = cap after clear');
    // reuse after clear
    B.AppendByte($FF);
    CheckEqual(SizeUInt(1), B.Available, 'reuse after clear');
    CheckEqual(Byte($FF), B.Data[0]);
  finally
    B.Free;
  end;
end;

procedure TestCompactOnAppend;
var
  B: TByteStreamBuf;
  LI: Integer;
  LCap: SizeUInt;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 4096);
  try
    LCap := B.Capacity;
    // fill 3000 bytes
    for LI := 0 to 2999 do
      B.AppendByte(Byte(LI and $FF));
    CheckEqual(SizeUInt(3000), B.Available);
    // consume 2000 -> FOff=2000, FLen=1000, tail= LCap-3000
    B.Consume(2000);
    CheckEqual(SizeUInt(1000), B.Available, 'after consume');
    // tail currently LCap-3000. Request 2500 -> FLen(1000)+2500=3500 <= LCap(=4096) so should Compact not Grow
    B.AppendByte($AA); // first reserve via Append path to trigger logic
    // Instead do explicit ReserveAppend that needs compact
    // We already appended 1, so FLen=1001, now request big chunk
    // reset for precise test: recreate
  finally
    B.Free;
  end;
  B := TByteStreamBuf.Create(DefaultAllocator, 4096);
  try
    for LI := 0 to 2999 do
      B.AppendByte(Byte(LI and $FF));
    B.Consume(2000);
    CheckEqual(SizeUInt(1000), B.Available);
    LCap := B.Capacity;
    // Tail = 4096-3000=1096. Need 2500 -> not enough tail, but total 1000+2500=3500 <=4096 => Compact
    B.Append(nil, 0); // no-op
    // Reserve 2500 triggers Compact
    B.ReserveAppend(2500);
    // After compact, off should be 0, FLen still 1000, tail should be LCap-1000
    CheckEqual(LCap, B.Capacity, 'cap unchanged after compact-triggered reserve');
    CheckEqual(LCap - 1000, B.TailSpace, 'tail after compact');
    // Data integrity after compact: first byte originally at index 2000
    CheckEqual(Byte(2000 and $FF), B.Data[0], 'compact preserved head');
    CheckEqual(Byte(2999 and $FF), B.Data[999], 'compact preserved tail');
    // Now actually commit
    FillChar(B.ReserveAppend(2500)^, 2500, $5A);
    B.CommitAppend(2500);
    CheckEqual(SizeUInt(3500), B.Available, 'len after big append with compact');
  finally
    B.Free;
  end;
end;

procedure TestEnsureCapacityIdempotent;
var
  B: TByteStreamBuf;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 0);
  try
    B.EnsureCapacity(4096);
    Check(B.Capacity >= 4096, 'cap 4096');
    B.AppendByte($01);
    B.AppendByte($02);
    B.EnsureCapacity(100); // smaller -> no-op, content preserved
    Check(B.Capacity >= 4096, 'cap unchanged on smaller ensure');
    CheckEqual(SizeUInt(2), B.Available, 'len preserved');
    CheckEqual(Byte($01), B.Data[0], 'data0 preserved');
    CheckEqual(Byte($02), B.Data[1], 'data1 preserved');
    B.EnsureCapacity(4096); // equal -> no-op
    CheckEqual(SizeUInt(2), B.Available, 'len preserved equal ensure');
    B.EnsureCapacity(16384);
    Check(B.Capacity >= 16384, 'grow to 16384');
    CheckEqual(SizeUInt(2), B.Available, 'len after grow');
    CheckEqual(Byte($01), B.Data[0], 'data after grow');
  finally
    B.Free;
  end;
end;

procedure TestConsumeAllResetsOffset;
var
  B: TByteStreamBuf;
  LI: Integer;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 4096);
  try
    for LI := 0 to 99 do
      B.AppendByte(Byte(LI));
    B.Consume(50);
    CheckEqual(SizeUInt(50), B.Available);
    B.Consume(50); // consume all
    CheckEqual(SizeUInt(0), B.Available, 'empty');
    CheckEqual(B.Capacity, B.TailSpace, 'tail=cap after full consume');
    // Next append should start at offset 0 without compact
    B.AppendByte($FF);
    CheckEqual(Byte($FF), B.Data[0], 'append after full consume at head');
    CheckEqual(SizeUInt(1), B.Available);
  finally
    B.Free;
  end;
end;

procedure TestGrowPreservesData;
var
  B: TByteStreamBuf;
  LI: Integer;
  LCapBefore: SizeUInt;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 4096);
  try
    for LI := 0 to 4095 do
      B.AppendByte(Byte(LI and $FF));
    CheckEqual(SizeUInt(4096), B.Available, 'full');
    LCapBefore := B.Capacity;
    // consume half to create offset
    B.Consume(2048);
    CheckEqual(SizeUInt(2048), B.Available, 'after half consume');
    // now need to grow beyond cap: request more than tail
    // Fill to exceed: append 5000 bytes -> will grow
    for LI := 0 to 4999 do
      B.AppendByte($AA);
    Check(B.Capacity > LCapBefore, 'grew');
    CheckEqual(SizeUInt(2048 + 5000), B.Available, 'len after grow with offset');
    // Verify first bytes are still the second half of original
    CheckEqual(Byte(2048 and $FF), B.Data[0], 'preserved after grow offset');
  finally
    B.Free;
  end;
end;

procedure TestPointerStabilityAcrossCompact;
var
  B: TByteStreamBuf;
  LI: Integer;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 8192);
  try
    for LI := 0 to 4095 do
      B.AppendByte(Byte(LI and $FF));
    B.Consume(3000);
    // Data[0] should be byte 3000 %256
    CheckEqual(Byte(3000 and $FF), B.Data[0], 'before compact');
    // Trigger compact via ReserveAppend that fits within cap
    B.ReserveAppend(1000); // FLen=1096, FLen+1000=2096 <=8192 -> compact path
    CheckEqual(Byte(3000 and $FF), B.Data[0], 'after compact via reserve');
    CheckEqual(SizeUInt(1096), B.Available, 'len unchanged after reserve w/o commit');
    // Data pointer after compact should differ (moved to head) but content stable
    // fill and commit to verify
    FillChar(B.ReserveAppend(1000)^, 1000, $77);
    B.CommitAppend(1000);
    CheckEqual(SizeUInt(2096), B.Available);
    CheckEqual(Byte($77), B.Data[1096], 'appended after compact');
  finally
    B.Free;
  end;
end;

procedure TestAppendEmptyAndConsumeZero;
var
  B: TByteStreamBuf;
begin
  B := TByteStreamBuf.Create(DefaultAllocator, 0);
  try
    B.Append(nil, 0);
    CheckEqual(SizeUInt(0), B.Available, 'append nil zero');
    B.AppendByte($01);
    CheckEqual(SizeUInt(0), B.Consume(0), 'consume 0 returns 0');
    CheckEqual(SizeUInt(1), B.Available, 'unchanged after consume 0');
    B.Clear;
    CheckEqual(SizeUInt(0), B.Consume(0), 'consume 0 on empty');
  finally
    B.Free;
  end;
end;

procedure TestViaFacadeAlias;
var
  B: TByteStreamBuf; // via nextpas.core.bytes re-export
  LCap: SizeUInt;
begin
  // Ensures the type alias in bytes.pas compiles when used via facade
  B := TByteStreamBuf.Create(DefaultAllocator, 1024);
  try
    LCap := B.Capacity;
    Check(LCap >= 1024, 'facade alias cap');
    B.AppendByte($42);
    CheckEqual(Byte($42), B.Data[0]);
  finally
    B.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.bytes.stream');
  T.Test('Append/Consume basic', @TestAppendConsumeBasic);
  T.Test('TailSpace/ReserveAppend', @TestTailSpaceAndReserveAppend);
  T.Test('Clear retains capacity', @TestClearRetainsCapacity);
  T.Test('Compact on append', @TestCompactOnAppend);
  T.Test('EnsureCapacity idempotent', @TestEnsureCapacityIdempotent);
  T.Test('Consume all resets offset', @TestConsumeAllResetsOffset);
  T.Test('Grow preserves data', @TestGrowPreservesData);
  T.Test('Pointer stability across compact', @TestPointerStabilityAcrossCompact);
  T.Test('Append empty / consume zero', @TestAppendEmptyAndConsumeZero);
  T.Test('Facade alias', @TestViaFacadeAlias);
  if not T.Run then Halt(1);
end.
