program test_arena_class;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.mem,
  nextpas.core.mem.blockpool;

var
  T: TTestRunner;

procedure TestBasicAlloc;
var A: TFixedArena; P: Pointer;
begin
  A := TFixedArena.Create(1024);
  try
    P := A.Alloc(64);
    Check(P <> nil, 'alloc 64 ok');
    Check(A.UsedSize >= 64, 'used >= 64');
    Check(A.RemainingSize <= 1024 - 64, 'remaining <= 960');
  finally
    A.Free;
  end;
end;

procedure TestMultipleAllocs;
var A: TFixedArena; P1, P2, P3: Pointer;
begin
  A := TFixedArena.Create(256);
  try
    P1 := A.Alloc(32);
    P2 := A.Alloc(32);
    P3 := A.Alloc(32);
    Check((P1 <> nil) and (P2 <> nil) and (P3 <> nil), 'all allocs ok');
    Check(P1 <> P2, 'different ptrs 1-2');
    Check(P2 <> P3, 'different ptrs 2-3');
    Check(PtrUInt(P2) > PtrUInt(P1), 'monotonic');
  finally
    A.Free;
  end;
end;

procedure TestExhaust;
var A: TFixedArena; P: Pointer;
begin
  A := TFixedArena.Create(100);
  try
    P := A.Alloc(80);
    Check(P <> nil, 'first alloc ok');
    P := A.Alloc(80);
    Check(P = nil, 'second alloc fails (OOM)');
  finally
    A.Free;
  end;
end;

procedure TestReset;
var A: TFixedArena; P: Pointer;
begin
  A := TFixedArena.Create(128);
  try
    A.Alloc(100);
    Check(A.UsedSize >= 100, 'used after alloc');
    A.Reset;
    Check(A.UsedSize = 0, 'used=0 after reset');
    Check(A.RemainingSize = 128, 'remaining=total after reset');
    P := A.Alloc(100);
    Check(P <> nil, 'can alloc after reset');
  finally
    A.Free;
  end;
end;

procedure TestMarkRestore;
var A: TFixedArena; M: TArenaMarker; P: Pointer;
begin
  A := TFixedArena.Create(512);
  try
    A.Alloc(64);
    M := A.SaveMark;
    A.Alloc(128);
    Check(A.UsedSize >= 192, 'used after 2 allocs');
    A.RestoreToMark(M);
    Check(A.UsedSize <= 64 + 16, 'restored to mark');
    P := A.Alloc(128);
    Check(P <> nil, 'can alloc after restore');
  finally
    A.Free;
  end;
end;

procedure TestAllocAligned;
var
  A: TFixedArena;
  P: Pointer;
begin
  A := TFixedArena.Create(256);
  try
    P := A.AllocAligned(32, 64);
    Check(P <> nil, 'alloc aligned ok');
    CheckEqual(Int64(0), Int64(PtrUInt(P) mod 64), 'alloc aligned should honor requested alignment');
    P := A.AllocAligned(16, 3);
    Check(P = nil, 'invalid non-power-of-two alignment should fail');
  finally
    A.Free;
  end;
end;

procedure TestAllocZeroed;
var A: TFixedArena; P: PByte; I: Integer; AllZero: Boolean;
begin
  A := TFixedArena.Create(256);
  try
    P := A.Alloc(32);
    if P <> nil then FillChar(P^, 32, $FF);
    A.Reset;
    P := A.AllocZeroed(32);
    Check(P <> nil, 'alloc zeroed ok');
    AllZero := True;
    for I := 0 to 31 do
      if P[I] <> 0 then begin AllZero := False; Break; end;
    Check(AllZero, 'memory is zeroed');
  finally
    A.Free;
  end;
end;

procedure TestAllocFast;
var A: TFixedArena; P1, P2: Pointer;
begin
  A := TFixedArena.Create(256);
  try
    P1 := A.AllocFast(32);
    P2 := A.AllocFast(64);
    Check(P1 <> nil, 'fast alloc 1');
    Check(P2 <> nil, 'fast alloc 2');
    Check(PtrUInt(P2) >= PtrUInt(P1) + 32, 'sequential');
  finally
    A.Free;
  end;
end;

procedure TestZeroSizeAlloc;
var A: TFixedArena; P: Pointer;
begin
  A := TFixedArena.Create(64);
  try
    P := A.Alloc(0);
    Check(P = nil, 'zero size returns nil');
  finally
    A.Free;
  end;
end;

procedure TestStats;
var A: TFixedArena;
begin
  A := TFixedArena.Create(256);
  try
    A.Alloc(32);
    A.Alloc(64);
    Check(A.TotalAllocCount = 2, 'total allocs=2');
    Check(A.PeakUsed >= 96, 'peak >= 96');
    A.Reset;
    A.Alloc(16);
    Check(A.TotalAllocCount = 3, 'total allocs=3 after reset');
    Check(A.PeakUsed >= 96, 'peak unchanged after reset');
  finally
    A.Free;
  end;
end;

procedure TestArenaClassLegacyAlias;
var
  A: TArena;
  P: Pointer;
begin
  A := TArena.Create(128);
  try
    P := A.Alloc(16);
    Check(P <> nil, 'legacy blockpool.TArena alias remains usable');
  finally
    A.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena_class');
  T.Run('basic alloc', @TestBasicAlloc);
  T.Run('multiple allocs', @TestMultipleAllocs);
  T.Run('exhaust', @TestExhaust);
  T.Run('reset', @TestReset);
  T.Run('mark/restore', @TestMarkRestore);
  T.Run('alloc aligned', @TestAllocAligned);
  T.Run('alloc zeroed', @TestAllocZeroed);
  T.Run('alloc fast', @TestAllocFast);
  T.Run('zero size alloc', @TestZeroSizeAlloc);
  T.Run('statistics', @TestStats);
  T.Run('legacy TArena alias', @TestArenaClassLegacyAlias);
  T.Summary;
end.
