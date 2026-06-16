program test_arena;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.arena,
  nextpas.core.mem.base;

var
  T: TTestRunner;

procedure TestArenaCreate;
var
  LA: TLocalArena;
begin
  LA := TLocalArena.Create(1024);
  try
    CheckEqual(Int64(1024), Int64(LA.TotalSize), 'total size');
    CheckEqual(Int64(0), Int64(LA.UsedSize), 'used size');
    CheckEqual(Int64(1024), Int64(LA.RemainingSize), 'remaining size');
  finally
    LA.Free;
  end;
end;

procedure TestArenaAlloc;
var
  LA: TLocalArena;
  LP1, LP2: Pointer;
begin
  LA := TLocalArena.Create(256);
  try
    LP1 := LA.Alloc(64);
    Check(LP1 <> nil, 'first alloc');
    CheckEqual(Int64(64), Int64(LA.UsedSize));

    LP2 := LA.Alloc(64);
    Check(LP2 <> nil, 'second alloc');
    Check(LP2 <> LP1, 'different pointers');
    CheckEqual(Int64(128), Int64(LA.UsedSize));
  finally
    LA.Free;
  end;
end;

procedure TestArenaAllocZeroSize;
var
  LA: TLocalArena;
begin
  LA := TLocalArena.Create(64);
  try
    Check(LA.Alloc(0) = nil, 'zero-size alloc should return nil');
    CheckEqual(Int64(0), Int64(LA.UsedSize), 'zero-size alloc should not advance offset');
  finally
    LA.Free;
  end;
end;

procedure TestArenaAllocExhaust;
var
  LA: TLocalArena;
  LP: Pointer;
begin
  LA := TLocalArena.Create(100);
  try
    LP := LA.Alloc(100);
    Check(LP <> nil, 'exact fit');
    LP := LA.Alloc(1);
    Check(LP = nil, 'should return nil when exhausted');
  finally
    LA.Free;
  end;
end;

procedure TestArenaAllocInsufficientCapacity;
var
  LA: TLocalArena;
begin
  LA := TLocalArena.Create(64);
  try
    Check(LA.Alloc(48) <> nil, 'initial alloc should succeed');
    Check(LA.Alloc(17) = nil, 'alloc larger than remaining capacity should fail closed');
    CheckEqual(Int64(48), Int64(LA.UsedSize), 'failed alloc should not advance offset');
  finally
    LA.Free;
  end;
end;

procedure TestArenaAllocAligned;
var
  LA: TLocalArena;
  LP: Pointer;
begin
  LA := TLocalArena.Create(1024);
  try
    LA.Alloc(1);
    LP := LA.AllocAligned(64, 16);
    Check(LP <> nil, 'aligned alloc');
    Check(SizeUInt(LP) mod 16 = 0, 'should be 16-byte aligned');

    LP := LA.AllocAligned(32, 64);
    Check(LP <> nil, 'aligned alloc 64');
    Check(SizeUInt(LP) mod 64 = 0, 'should be 64-byte aligned');
  finally
    LA.Free;
  end;
end;

procedure TestArenaAllocAlignedRejectsInvalidAlignment;
var
  LA: TLocalArena;
begin
  LA := TLocalArena.Create(256);
  try
    Check(LA.AllocAligned(16, 0) = nil, 'zero alignment should return nil');
    Check(LA.AllocAligned(16, 3) = nil, 'alignment 3 should return nil');
    Check(LA.AllocAligned(16, 5) = nil, 'alignment 5 should return nil');
    CheckEqual(Int64(0), Int64(LA.UsedSize), 'invalid alignment should not advance offset');
  finally
    LA.Free;
  end;
end;

procedure TestArenaAllocAlignedAcceptsPowerOfTwoAlignment;
const
  VALID_ALIGNMENTS: array[0..5] of SizeUInt = (1, 2, 4, 8, 16, 32);
var
  LA: TLocalArena;
  LP: Pointer;
  I: Integer;
begin
  LA := TLocalArena.Create(512);
  try
    for I := Low(VALID_ALIGNMENTS) to High(VALID_ALIGNMENTS) do
    begin
      LP := LA.AllocAligned(8, VALID_ALIGNMENTS[I]);
      Check(LP <> nil, 'valid alignment should allocate');
      Check(SizeUInt(LP) mod VALID_ALIGNMENTS[I] = 0, 'pointer should honor requested alignment');
    end;
  finally
    LA.Free;
  end;
end;

procedure TestArenaReset;
var
  LA: TLocalArena;
begin
  LA := TLocalArena.Create(256);
  try
    LA.Alloc(100);
    LA.Alloc(50);
    CheckEqual(Int64(150), Int64(LA.UsedSize));

    LA.Reset;
    CheckEqual(Int64(0), Int64(LA.UsedSize), 'reset clears');
    CheckEqual(Int64(256), Int64(LA.RemainingSize));

    Check(LA.Alloc(256) <> nil, 'can reuse after reset');
  finally
    LA.Free;
  end;
end;

procedure TestArenaMark;
var
  LA: TLocalArena;
  LMark: TArenaMarker;
  LP: Pointer;
begin
  LA := TLocalArena.Create(256);
  try
    LA.Alloc(32);
    LMark := LA.SaveMark;
    CheckEqual(Int64(32), Int64(LMark));

    LA.Alloc(64);
    CheckEqual(Int64(96), Int64(LA.UsedSize));

    LA.RestoreToMark(LMark);
    CheckEqual(Int64(32), Int64(LA.UsedSize), 'restored to mark');

    LP := LA.Alloc(64);
    Check(LP <> nil, 'can alloc after restore');
  finally
    LA.Free;
  end;
end;

procedure TestArenaMarkNested;
var
  LA: TLocalArena;
  LMark1, LMark2: TArenaMarker;
begin
  LA := TLocalArena.Create(256);
  try
    LA.Alloc(10);
    LMark1 := LA.SaveMark;

    LA.Alloc(20);
    LMark2 := LA.SaveMark;

    LA.Alloc(30);
    CheckEqual(Int64(60), Int64(LA.UsedSize));

    LA.RestoreToMark(LMark2);
    CheckEqual(Int64(30), Int64(LA.UsedSize));

    LA.RestoreToMark(LMark1);
    CheckEqual(Int64(10), Int64(LA.UsedSize));
  finally
    LA.Free;
  end;
end;

procedure TestArenaWriteRead;
var
  LA: TLocalArena;
  LP: PInteger;
begin
  LA := TLocalArena.Create(256);
  try
    LP := PInteger(LA.Alloc(SizeOf(Integer)));
    Check(LP <> nil);
    LP^ := 12345;
    Check(LP^ = 12345, 'write/read through arena pointer');
  finally
    LA.Free;
  end;
end;

procedure TestArenaZeroed;
var
  LA: TLocalArena;
  LP: PByte;
  I: Integer;
begin
  LA := TLocalArena.Create(256);
  try
    LP := PByte(LA.AllocZeroed(64));
    Check(LP <> nil, 'zeroed alloc should succeed');
    for I := 0 to 63 do
      Check(LP[I] = 0, 'zeroed memory at byte ' + IntToStr(I));
  finally
    LA.Free;
  end;
end;

procedure TestArenaLegacyAlias;
var
  LA: TArena;
begin
  LA := TArena.Create(64);
  try
    Check(LA.Alloc(8) <> nil, 'legacy TArena alias remains usable');
  finally
    LA.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena');
  T.Run('Create', @TestArenaCreate);
  T.Run('Alloc', @TestArenaAlloc);
  T.Run('Alloc zero size', @TestArenaAllocZeroSize);
  T.Run('Alloc exhaust', @TestArenaAllocExhaust);
  T.Run('Alloc insufficient capacity', @TestArenaAllocInsufficientCapacity);
  T.Run('AllocAligned', @TestArenaAllocAligned);
  T.Run('AllocAligned rejects invalid alignment', @TestArenaAllocAlignedRejectsInvalidAlignment);
  T.Run('AllocAligned accepts power-of-two alignment', @TestArenaAllocAlignedAcceptsPowerOfTwoAlignment);
  T.Run('Reset', @TestArenaReset);
  T.Run('Mark/Restore', @TestArenaMark);
  T.Run('Mark nested', @TestArenaMarkNested);
  T.Run('Write/Read', @TestArenaWriteRead);
  T.Run('AllocZeroed', @TestArenaZeroed);
  T.Run('legacy TArena alias', @TestArenaLegacyAlias);
  T.Summary;
end.
